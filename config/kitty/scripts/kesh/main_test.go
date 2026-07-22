package main

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func TestParseArgs(t *testing.T) {
	tests := []struct {
		args       []string
		wantFilter int
		wantSlot   string
		wantError  bool
	}{
		{wantFilter: filterAll},
		{args: []string{"agents"}, wantFilter: filterAgents},
		{args: []string{"switch", "4"}, wantFilter: filterAll, wantSlot: "4"},
		{args: []string{"switch", "10"}, wantError: true},
		{args: []string{"unknown"}, wantError: true},
	}
	for _, test := range tests {
		filter, slot, err := parseArgs(test.args)
		if (err != nil) != test.wantError {
			t.Fatalf("parseArgs(%q) error = %v, wantError %v", test.args, err, test.wantError)
		}
		if err == nil && (filter != test.wantFilter || slot != test.wantSlot) {
			t.Errorf("parseArgs(%q) = (%d, %q), want (%d, %q)", test.args, filter, slot, test.wantFilter, test.wantSlot)
		}
	}
}

func TestLoadEntriesIncludesUnscopedTabs(t *testing.T) {
	directory := t.TempDir()
	project := "/projects/homelab"
	kitty := filepath.Join(directory, "kitty")
	kittyState := `[{"tabs":[{"id":6,"title":"homelab-code","windows":[{"id":70,"cwd":"/projects/homelab","last_focused_at":12,"foreground_processes":[{"cmdline":["codex"],"cwd":"/projects/homelab"}]}]}]}]`
	if err := os.WriteFile(kitty, []byte("#!/bin/sh\nprintf '%s\\n' '"+kittyState+"'\n"), 0o700); err != nil {
		t.Fatal(err)
	}
	zoxide := filepath.Join(directory, "zoxide")
	if err := os.WriteFile(zoxide, []byte("#!/bin/sh\nprintf '%s\\n' '"+project+"'\n"), 0o700); err != nil {
		t.Fatal(err)
	}

	entries, err := loadEntries(kitty, zoxide)
	if err != nil {
		t.Fatal(err)
	}
	var homelab *entry
	for index := range entries {
		if entries[index].key == project {
			homelab = &entries[index]
			break
		}
	}
	if homelab == nil || !homelab.open || len(homelab.tabs) != 1 {
		t.Fatalf("unscoped tab was not included: %#v", homelab)
	}
	if got := homelab.tabs[0]; got.title != "homelab-code" || got.agent != "codex" {
		t.Errorf("tab = %#v, want homelab-code Codex tab", got)
	}
}

func TestLoadEntriesQueriesKittyAndZoxideConcurrently(t *testing.T) {
	directory := t.TempDir()
	t.Setenv("HOME", directory)
	t.Setenv("KESH_CONCURRENCY_DIR", directory)
	kitty := filepath.Join(directory, "kitty")
	kittyScript := `#!/bin/sh
touch "$KESH_CONCURRENCY_DIR/kitty.started"
attempt=0
while [ ! -e "$KESH_CONCURRENCY_DIR/zoxide.started" ] && [ "$attempt" -lt 100 ]; do
  sleep 0.01
  attempt=$((attempt + 1))
done
[ -e "$KESH_CONCURRENCY_DIR/zoxide.started" ] || exit 1
printf '%s\n' '[{"tabs":[]}]'
`
	if err := os.WriteFile(kitty, []byte(kittyScript), 0o700); err != nil {
		t.Fatal(err)
	}
	zoxide := filepath.Join(directory, "zoxide")
	zoxideScript := `#!/bin/sh
touch "$KESH_CONCURRENCY_DIR/zoxide.started"
attempt=0
while [ ! -e "$KESH_CONCURRENCY_DIR/kitty.started" ] && [ "$attempt" -lt 100 ]; do
  sleep 0.01
  attempt=$((attempt + 1))
done
[ -e "$KESH_CONCURRENCY_DIR/kitty.started" ] || exit 1
printf '%s\n' '/projects/parallel'
`
	if err := os.WriteFile(zoxide, []byte(zoxideScript), 0o700); err != nil {
		t.Fatal(err)
	}

	entries, err := loadEntries(kitty, zoxide)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 || entries[0].key != "/projects/parallel" {
		t.Fatalf("entries = %#v, want concurrent zoxide project", entries)
	}
}

func TestIsKeshTab(t *testing.T) {
	kesh := kittyWindow{Cmdline: []string{"/Users/stan/.config/kitty/scripts/kesh/kesh"}}
	if !isKeshTab([]kittyWindow{kesh}) {
		t.Fatal("expected dedicated Kesh tab to be excluded")
	}
	if isKeshTab([]kittyWindow{kesh, {Cmdline: []string{"zsh"}}}) {
		t.Fatal("expected a mixed tab to remain visible")
	}
}

func TestAgentFromWindow(t *testing.T) {
	tests := map[string]struct {
		processes [][]string
		want      string
	}{
		"pi":          {processes: [][]string{{"/Users/stan/.local/bin/pi"}}, want: "pi"},
		"codex":       {processes: [][]string{{"node", "/opt/homebrew/bin/codex"}}, want: "codex"},
		"both agents": {processes: [][]string{{"pi"}, {"codex"}}, want: "pi,codex"},
		"other shell": {processes: [][]string{{"zsh"}}, want: ""},
	}
	for name, test := range tests {
		t.Run(name, func(t *testing.T) {
			window := kittyWindow{}
			for _, cmdline := range test.processes {
				window.ForegroundProcesses = append(window.ForegroundProcesses, struct {
					Cmdline []string `json:"cmdline"`
					CWD     string   `json:"cwd"`
				}{Cmdline: cmdline})
			}
			if got := agentFromWindow(window); got != test.want {
				t.Errorf("agentFromWindow() = %q, want %q", got, test.want)
			}
		})
	}
}

func TestAgentRowsAreFlatSearchableAndMostRecentFirst(t *testing.T) {
	m := model{
		filter: filterAgents,
		entries: []entry{
			{
				name: "dotfiles",
				tabs: []tabItem{{
					title: "config",
					windows: []windowItem{
						{id: 10, title: "shell", lastFocused: 30},
						{id: 11, title: "kesh", agent: "codex", detail: "~/.dotfiles", lastFocused: 20},
					},
				}},
			},
			{
				name: "api",
				tabs: []tabItem{{
					title:   "review",
					windows: []windowItem{{id: 12, title: "pi review", agent: "pi", detail: "~/api", lastFocused: 40}},
				}},
			},
		},
	}
	m.rebuildRows()
	if len(m.rows) != 2 {
		t.Fatalf("agent rows = %d, want 2", len(m.rows))
	}
	first := m.entries[m.rows[0].entryIndex].tabs[m.rows[0].tabIndex].windows[m.rows[0].windowIndex]
	if first.id != 12 {
		t.Fatalf("first agent window = %d, want most recently focused window 12", first.id)
	}

	m.query = "dtfls"
	m.rebuildRows()
	if len(m.rows) != 1 {
		t.Fatalf("project search returned %d rows, want 1", len(m.rows))
	}
	got := m.entries[m.rows[0].entryIndex].tabs[m.rows[0].tabIndex].windows[m.rows[0].windowIndex]
	if got.id != 11 {
		t.Errorf("project search selected window %d, want 11", got.id)
	}
}

func TestPreviewIgnoresStaleResponse(t *testing.T) {
	m := model{previewID: 12, previewBusy: true}
	updated, _ := m.Update(previewMsg{windowID: 11, content: "old"})
	got := updated.(model)
	if got.preview != "" || !got.previewBusy {
		t.Fatalf("stale preview changed model: %#v", got)
	}
}

func TestAgentViewRendersFlatRowAndPreview(t *testing.T) {
	m := model{
		filter: filterAgents, showPreview: true, width: 120, height: 30,
		entries: []entry{{
			name: "dotfiles",
			tabs: []tabItem{{
				title:   "agents",
				windows: []windowItem{{id: 11, agent: "codex", detail: "~/.dotfiles", lastFocused: 20}},
			}},
		}},
	}
	m.rebuildRows()
	m.queuePreview()
	view := m.View()
	for _, expected := range []string{"Agents", "Codex", "dotfiles", "Agent screen", "Loading preview"} {
		if !strings.Contains(view, expected) {
			t.Errorf("agent view does not contain %q:\n%s", expected, view)
		}
	}
}

func TestFetchPreviewRemovesBackgroundAndTrailingBlankLines(t *testing.T) {
	directory := t.TempDir()
	kitty := filepath.Join(directory, "kitty")
	if err := os.WriteFile(kitty, []byte("#!/bin/sh\nprintf '\\033[38;5;42m\\033[48;5;22mready\\033[0m\\n\\n'\n"), 0o700); err != nil {
		t.Fatal(err)
	}
	msg := fetchPreview(kitty, 42)().(previewMsg)
	if msg.err != nil {
		t.Fatal(msg.err)
	}
	if strings.Contains(msg.content, "[48;") {
		t.Errorf("preview retained background colour: %q", msg.content)
	}
	if !strings.Contains(msg.content, "[38;5;42m") || !strings.HasSuffix(msg.content, "ready\x1b[0m") {
		t.Errorf("preview = %q, want foreground colour and no trailing blank lines", msg.content)
	}
}

func TestValidSlot(t *testing.T) {
	for _, slot := range []string{"0", "1", "9"} {
		if !validSlot(slot) {
			t.Fatalf("expected %q to be valid", slot)
		}
	}
	for _, slot := range []string{"", "10", "a", "-1"} {
		if validSlot(slot) {
			t.Fatalf("expected %q to be invalid", slot)
		}
	}
}

func TestPinsRoundTrip(t *testing.T) {
	stateHome := t.TempDir()
	t.Setenv("XDG_STATE_HOME", stateHome)
	want := pinStore{
		"0": {Key: "/projects/zero", Name: "zero"},
		"9": {Key: "ssh://production", Name: "production"},
	}
	if err := savePins(want); err != nil {
		t.Fatal(err)
	}
	got, err := loadPins()
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != len(want) || got["0"] != want["0"] || got["9"] != want["9"] {
		t.Fatalf("unexpected pins: %#v", got)
	}
	info, err := os.Stat(filepath.Join(stateHome, "kesh", "pins.json"))
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("pin state permissions are %o, want 600", info.Mode().Perm())
	}
}

func TestLoadPinsRejectsInvalidState(t *testing.T) {
	tests := map[string]string{
		"malformed JSON":      `{`,
		"invalid slot":        `{"10":{"key":"/projects/ten","name":"ten"}}`,
		"empty key":           `{"1":{"key":"","name":"empty"}}`,
		"duplicate pin":       `{"1":{"key":"/same","name":"same"},"2":{"key":"/same","name":"same"}}`,
		"invalid kind":        `{"1":{"key":"/project","name":"project","kind":"other"}}`,
		"unsafe session file": `{"1":{"key":"/project","name":"project","session_file":"/tmp/outside.kitty-session"}}`,
	}
	for name, content := range tests {
		t.Run(name, func(t *testing.T) {
			stateHome := t.TempDir()
			t.Setenv("XDG_STATE_HOME", stateHome)
			path := filepath.Join(stateHome, "kesh", "pins.json")
			if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
				t.Fatal(err)
			}
			if _, err := loadPins(); err == nil {
				t.Fatal("expected invalid pin state to fail")
			}
		})
	}
}

func TestWorkspaceNamesRoundTripInHomeConfig(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	want := nameStore{
		"/projects/payments": "Payments",
		"ssh://production":   "Production",
	}
	if err := saveNames(want); err != nil {
		t.Fatal(err)
	}
	got, err := loadNames()
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != len(want) || got["/projects/payments"] != "Payments" || got["ssh://production"] != "Production" {
		t.Fatalf("workspace names = %#v, want %#v", got, want)
	}
	info, err := os.Stat(filepath.Join(home, "config", "kesh", "names.json"))
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("workspace name permissions are %o, want 600", info.Mode().Perm())
	}
}

func TestSessionRenamePersistsAliasAndEmptyNameResetsIt(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	e := entry{key: "/projects/payments", name: "payments", originalName: "payments"}
	selected := row{entryIndex: 0, tabIndex: -1, windowIndex: -1}
	m := model{entries: []entry{e}, rows: []row{selected}, names: nameStore{}}

	msg := runRename("", e, selected, "  Payments  ", m.names)().(renameMsg)
	updated, _ := m.Update(msg)
	m = updated.(model)
	if m.entries[0].name != "Payments" || m.names[e.key] != "Payments" {
		t.Fatalf("renamed model = %#v, names = %#v", m.entries[0], m.names)
	}
	stored, err := loadNames()
	if err != nil || stored[e.key] != "Payments" {
		t.Fatalf("stored names = %#v, err = %v", stored, err)
	}

	msg = runRename("", m.entries[0], selected, "", m.names)().(renameMsg)
	updated, _ = m.Update(msg)
	m = updated.(model)
	if m.entries[0].name != "payments" {
		t.Fatalf("reset name = %q, want payments", m.entries[0].name)
	}
	stored, err = loadNames()
	if err != nil || len(stored) != 0 {
		t.Fatalf("stored names after reset = %#v, err = %v", stored, err)
	}
}

func TestWorkspaceSearchMatchesOriginalNameAfterRename(t *testing.T) {
	m := model{
		query: "pymnts",
		entries: []entry{{
			key: "/projects/payments", name: "Billing", originalName: "payments", detail: "/projects/payments",
		}},
	}
	m.rebuildRows()
	if len(m.rows) != 1 {
		t.Fatalf("original workspace name search returned %d rows, want 1", len(m.rows))
	}
}

func TestCloseArgsTargetsSelectedHierarchyLevel(t *testing.T) {
	e := entry{
		name: "Payments",
		tabs: []tabItem{
			{id: 12, windows: []windowItem{{id: 120}, {id: 121}}},
			{id: 14, windows: []windowItem{{id: 140}}},
		},
	}
	tests := []struct {
		name     string
		selected row
		want     []string
	}{
		{
			name:     "workspace",
			selected: row{entryIndex: 0, tabIndex: -1, windowIndex: -1},
			want:     []string{"@", "close-tab", "--match", "id:12 or id:14"},
		},
		{
			name:     "tab",
			selected: row{entryIndex: 0, tabIndex: 1, windowIndex: -1},
			want:     []string{"@", "close-tab", "--match", "id:14"},
		},
		{
			name:     "window",
			selected: row{entryIndex: 0, tabIndex: 0, windowIndex: 1},
			want:     []string{"@", "close-window", "--match", "id:121"},
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, err := closeArgs(e, test.selected)
			if err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(got, test.want) {
				t.Fatalf("closeArgs() = %#v, want %#v", got, test.want)
			}
		})
	}
}

func TestComposedSessionContentCreatesOneTabPerEntry(t *testing.T) {
	t.Setenv("HOME", "/Users/stan")
	content := composedSessionContent("release", []entry{
		{key: "/projects/api", name: "API", kind: "project"},
		{key: "ssh://production", name: "production", kind: "ssh"},
	})
	want := "os_window_title release\nlayout splits\n" +
		"new_tab API\ncd /projects/api\nlaunch --title \"API\"\n" +
		"new_tab production\ncd /Users/stan\nlaunch --title \"ssh: production\" ssh \"production\"\n" +
		"focus\nfocus_os_window\n"
	if content != want {
		t.Fatalf("composedSessionContent() = %q, want %q", content, want)
	}
}

func TestComposedSessionName(t *testing.T) {
	if name, ok := composedSessionName("kesh-release"); !ok || name != "release" {
		t.Fatalf("composedSessionName() = (%q, %v), want (release, true)", name, ok)
	}
	if _, ok := composedSessionName("dotfiles"); ok {
		t.Fatal("ordinary session was identified as composed")
	}
}

func TestSpaceTogglesTopLevelSelection(t *testing.T) {
	m := model{entries: []entry{{key: "/projects/api", name: "API"}}, rows: []row{{entryIndex: 0, tabIndex: -1, windowIndex: -1}}}
	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeySpace})
	m = updated.(model)
	if !m.selected["/projects/api"] {
		t.Fatalf("space did not select the project: %#v", m.selected)
	}
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'n'}})
	m = updated.(model)
	if !m.creating {
		t.Fatal("n did not open the create-session prompt")
	}
	m.creating = false
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeySpace})
	m = updated.(model)
	if len(m.selected) != 0 {
		t.Fatalf("space did not clear the project selection: %#v", m.selected)
	}
}

func TestCloseRequiresConfirmationAndRejectsInactiveWorkspace(t *testing.T) {
	selected := row{entryIndex: 0, tabIndex: -1, windowIndex: -1}
	m := model{
		entries: []entry{{name: "Payments", tabs: []tabItem{{id: 12}}}},
		rows:    []row{selected},
	}
	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'x'}})
	m = updated.(model)
	if !m.closing || m.closeBusy || cmd != nil {
		t.Fatalf("first x should open confirmation: closing=%v busy=%v cmd=%v", m.closing, m.closeBusy, cmd)
	}
	if popup := m.popupView(80); !strings.Contains(popup, `Close workspace "Payments"`) || !strings.Contains(popup, "Press y to confirm") {
		t.Fatalf("close popup is missing confirmation details:\n%s", popup)
	}
	updated, cmd = m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'y'}})
	m = updated.(model)
	if !m.closing || !m.closeBusy || cmd == nil {
		t.Fatalf("y should start closing: closing=%v busy=%v cmd=%v", m.closing, m.closeBusy, cmd)
	}

	inactive := model{entries: []entry{{name: "Payments"}}, rows: []row{selected}}
	updated, _ = inactive.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'x'}})
	inactive = updated.(model)
	if inactive.closing || inactive.err == nil || !strings.Contains(inactive.err.Error(), "not open") {
		t.Fatalf("inactive close state: closing=%v err=%v", inactive.closing, inactive.err)
	}
}
