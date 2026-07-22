package main

import (
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/x/ansi"
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
	var workspace, source *entry
	for index := range entries {
		switch entries[index].kind {
		case "workspace":
			workspace = &entries[index]
		case "project":
			source = &entries[index]
		}
	}
	if workspace == nil || !workspace.open || workspace.path != project || len(workspace.tabs) != 1 {
		t.Fatalf("unscoped workspace was not included: %#v", workspace)
	}
	if got := workspace.tabs[0]; got.title != "homelab-code" || got.agent != "codex" {
		t.Errorf("tab = %#v, want homelab-code Codex tab", got)
	}
	if source == nil || source.key != project || source.open || len(source.tabs) != 0 {
		t.Fatalf("reusable project source was not retained: %#v", source)
	}
}

func TestLoadEntriesKeepsNamedWorkspaceSeparateFromItsProject(t *testing.T) {
	directory := t.TempDir()
	project := "/Users/stan/workspace/aurora"
	kitty := filepath.Join(directory, "kitty")
	kittyState := `[{"tabs":[{"id":6,"title":"frontier","windows":[{"id":70,"cwd":"/Users/stan/workspace/aurora","session_name":"aurora","last_focused_at":12}]}]}]`
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
	applyNames(entries, nameStore{project: "aurora | frontier"})
	var workspace, source *entry
	for index := range entries {
		switch entries[index].kind {
		case "workspace":
			workspace = &entries[index]
		case "project":
			source = &entries[index]
		}
	}
	if workspace == nil || workspace.name != "aurora | frontier" || workspace.key != "workspace:aurora" {
		t.Fatalf("workspace = %#v, want aliased live workspace", workspace)
	}
	if source == nil || source.name != "aurora" || source.key != project || source.open {
		t.Fatalf("source = %#v, want reusable aurora project", source)
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

func TestLoadCloneRoot(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))

	root, err := loadCloneRoot()
	if err != nil || root != filepath.Join(home, "workspace") {
		t.Fatalf("default clone root = (%q, %v)", root, err)
	}

	path := filepath.Join(home, ".config", "kesh", "config.toml")
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("[clone]\nroot = \"~/code\"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	root, err = loadCloneRoot()
	if err != nil || root != filepath.Join(home, "code") {
		t.Fatalf("configured clone root = (%q, %v)", root, err)
	}
}

func TestRepositoryNameAndCloneDestination(t *testing.T) {
	for repository, want := range map[string]string{
		"https://github.com/example/project.git": "project",
		"git@github.com:example/project.git":     "project",
		"example/project":                        "project",
		"/tmp/local-project/":                    "local-project",
	} {
		got, err := repositoryName(repository)
		if err != nil || got != want {
			t.Errorf("repositoryName(%q) = (%q, %v), want (%q, nil)", repository, got, err, want)
		}
	}
	for _, repository := range []string{"", "https://github.com/", "-option"} {
		if _, err := repositoryName(repository); err == nil {
			t.Errorf("repositoryName(%q) did not fail", repository)
		}
	}

	home := t.TempDir()
	t.Setenv("HOME", home)
	root := filepath.Join(home, "workspace")
	got, err := resolveCloneDestination("custom/project", root)
	if err != nil || got != filepath.Join(root, "custom", "project") {
		t.Fatalf("relative clone destination = (%q, %v)", got, err)
	}
	got, err = resolveCloneDestination("~/code/project", root)
	if err != nil || got != filepath.Join(home, "code", "project") {
		t.Fatalf("home clone destination = (%q, %v)", got, err)
	}
}

func TestCloneFormShowsAndUpdatesBothFields(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	root := filepath.Join(home, "workspace")
	m := model{
		cloning:          true,
		cloneRoot:        root,
		cloneDestination: "~/workspace",
	}

	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("git@github.com:example/project.git"), Paste: true})
	m = updated.(model)
	if cmd != nil || m.cloneDestination != "~/workspace/project" {
		t.Fatalf("clone form destination = %q, cmd = %v", m.cloneDestination, cmd)
	}
	popup := m.popupView(100)
	plainPopup := ansi.Strip(popup)
	if !strings.Contains(plainPopup, "Repository: git@github.com:example/project.git") || !strings.Contains(plainPopup, "Clone into: ~/workspace/project") {
		t.Fatalf("clone popup does not show both fields:\n%s", popup)
	}

	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyTab})
	m = updated.(model)
	if !m.cloneDestinationFocus {
		t.Fatal("tab did not focus the clone destination")
	}
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyCtrlU})
	m = updated.(model)
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("~/code/custom")})
	m = updated.(model)
	if m.cloneDestination != "~/code/custom" || !m.cloneDestinationEdited {
		t.Fatalf("edited clone destination = %q, edited = %t", m.cloneDestination, m.cloneDestinationEdited)
	}
}

func TestRunCloneOpensProjectAndAddsItToZoxide(t *testing.T) {
	directory := t.TempDir()
	logPath := filepath.Join(directory, "commands.log")
	writeCommand := func(name, body string) string {
		path := filepath.Join(directory, name)
		script := fmt.Sprintf("#!/bin/sh\nprintf '%s:%%s\\n' \"$*\" >> %q\n%s\n", name, logPath, body)
		if err := os.WriteFile(path, []byte(script), 0o700); err != nil {
			t.Fatal(err)
		}
		return path
	}
	writeCommand("git", `mkdir -p "$4"`)
	kitty := writeCommand("kitty", "")
	zoxide := writeCommand("zoxide", "")
	t.Setenv("PATH", directory+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("TMPDIR", directory)

	destination := filepath.Join(directory, "clones", "project")
	msg := runClone(kitty, zoxide, "git@github.com:example/project.git", destination)().(cloneMsg)
	if msg.err != nil {
		t.Fatal(msg.err)
	}
	if info, err := os.Stat(destination); err != nil || !info.IsDir() {
		t.Fatalf("clone destination was not created: %v", err)
	}
	sessionPath := filepath.Join(os.TempDir(), "kitty-zoxide-sessions", "project.kitty-session")
	session, err := os.ReadFile(sessionPath)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(session), "cd "+destination+"\n") || strings.Contains(string(session), "cd \"") {
		t.Fatalf("generated session has an invalid working directory:\n%s", session)
	}
	commands, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatal(err)
	}
	log := string(commands)
	for _, expected := range []string{
		"git:clone -- git@github.com:example/project.git " + destination,
		"kitty:@ action goto_session ",
		"zoxide:add -- " + destination,
	} {
		if !strings.Contains(log, expected) {
			t.Errorf("command log does not contain %q:\n%s", expected, log)
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

func TestPinShortcutsGenerateNativeKittyMappings(t *testing.T) {
	stateHome := t.TempDir()
	t.Setenv("XDG_STATE_HOME", stateHome)
	pins := pinStore{
		"1": {SessionFile: filepath.Join(stateHome, "kesh", "sessions", "project one.kitty-session")},
		"9": {SessionFile: filepath.Join(stateHome, "kesh", "sessions", "production.kitty-session")},
	}

	content := string(pinShortcutsContent(pins))
	for _, expected := range []string{
		"map cmd+0\n",
		"map cmd+1 goto_session \"" + pins["1"].SessionFile + "\"\n",
		"map cmd+9 goto_session \"" + pins["9"].SessionFile + "\"\n",
	} {
		if !strings.Contains(content, expected) {
			t.Errorf("shortcut config does not contain %q:\n%s", expected, content)
		}
	}

	changed, err := savePinShortcuts(pins)
	if err != nil || !changed {
		t.Fatalf("first shortcut save = (%t, %v), want (true, nil)", changed, err)
	}
	changed, err = savePinShortcuts(pins)
	if err != nil || changed {
		t.Fatalf("unchanged shortcut save = (%t, %v), want (false, nil)", changed, err)
	}
	info, err := os.Stat(filepath.Join(stateHome, "kesh", "kitty-pins.conf"))
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("shortcut config permissions are %o, want 600", info.Mode().Perm())
	}
}

func TestLoadPinsRejectsInvalidState(t *testing.T) {
	tests := map[string]string{
		"malformed JSON":      `{`,
		"invalid slot":        `{"10":{"key":"/projects/ten","name":"ten"}}`,
		"empty key":           `{"1":{"key":"","name":"empty"}}`,
		"duplicate pin":       `{"1":{"key":"/same","name":"same"},"2":{"key":"/same","name":"same"}}`,
		"invalid kind":        `{"1":{"key":"/project","name":"project","kind":"other"}}`,
		"invalid version":     `{"1":{"key":"/project","name":"project","kind":"project","version":99}}`,
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

func TestLegacyProjectPinMigratesToMatchingWorkspace(t *testing.T) {
	path := "/projects/aurora"
	pins := pinStore{
		"1": {Key: path, Name: "aurora | frontier", Kind: "project"},
		"2": {Key: "/projects/closed", Name: "closed", Kind: "project"},
	}
	workspaces := []entry{
		{key: "workspace:kesh-aurora", name: "aurora | frontier", kind: "workspace", path: path},
		{key: path, name: "aurora", kind: "project", path: path},
	}
	got, changed := migrateLegacyPins(workspaces, pins)
	if !changed {
		t.Fatal("legacy pins were not migrated")
	}
	if target := got["1"]; target.Key != "workspace:kesh-aurora" || target.Kind != "workspace" || target.Version != currentPinVersion {
		t.Fatalf("workspace pin = %#v", target)
	}
	if target := got["2"]; target.Key != "/projects/closed" || target.Kind != "project" || target.Version != currentPinVersion {
		t.Fatalf("closed project pin = %#v", target)
	}
}

func TestWorkspaceNamesRoundTripInConfigHome(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
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
	info, err := os.Stat(filepath.Join(home, ".config", "kesh", "names.json"))
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
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	e := entry{key: "workspace:payments", name: "payments", originalName: "payments", kind: "workspace", path: "/projects/payments"}
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
			key: "workspace:payments", name: "Billing", originalName: "payments", detail: "/projects/payments", kind: "workspace",
		}},
	}
	m.rebuildRows()
	if len(m.rows) != 1 {
		t.Fatalf("original workspace name search returned %d rows, want 1", len(m.rows))
	}
}

func TestSearchRanksOpenWorkspacesAboveUnopenedProjects(t *testing.T) {
	m := model{
		query: "flux",
		entries: []entry{
			{key: "/projects/flux", name: "flux", kind: "project"},
			{key: "workspace:flux", name: "flux service", kind: "workspace", open: true},
		},
	}
	m.rebuildRows()
	if len(m.rows) != 2 {
		t.Fatalf("search returned %d rows, want 2", len(m.rows))
	}
	first := m.entries[m.rows[0].entryIndex]
	if !first.open || first.kind != "workspace" {
		t.Fatalf("first search result = %#v, want open workspace", first)
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

func TestWorkspaceAndProjectFiltersUseSeparateEntries(t *testing.T) {
	entries := []entry{
		{key: "workspace:aurora", name: "aurora | frontier", kind: "workspace", open: true},
		{key: "/projects/aurora", name: "aurora", kind: "project"},
	}
	m := model{entries: entries, filter: filterOpen}
	m.rebuildRows()
	if len(m.rows) != 1 || m.entries[m.rows[0].entryIndex].kind != "workspace" {
		t.Fatalf("open rows = %#v, want workspace only", m.rows)
	}
	m.filter = filterProjects
	m.rebuildRows()
	if len(m.rows) != 1 || m.entries[m.rows[0].entryIndex].kind != "project" {
		t.Fatalf("project rows = %#v, want source project only", m.rows)
	}
}

func TestSearchRanksExactProjectNameFirst(t *testing.T) {
	m := model{
		query: "crm",
		entries: []entry{
			{key: "/workspace/customer-relations-manager", name: "customer-relations-manager", detail: "/workspace/customer-relations-manager"},
			{key: "/workspace/crm", name: "crm", detail: "/workspace/crm"},
		},
	}
	m.rebuildRows()
	if len(m.rows) != 2 || m.entries[m.rows[0].entryIndex].name != "crm" {
		t.Fatalf("ranked rows = %#v, want crm first", m.rows)
	}
}

func TestSlashSearchReturnsToCommandsForSelectionAndCreation(t *testing.T) {
	m := model{entries: []entry{
		{key: "/projects/java", name: "java", kind: "project"},
		{key: "/projects/javascript", name: "javascript", kind: "project"},
	}}
	m.rebuildRows()

	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'j'}})
	m = updated.(model)
	if m.searching || m.cursor != 1 {
		t.Fatalf("j should navigate in command mode: searching=%v cursor=%d", m.searching, m.cursor)
	}

	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'/'}})
	m = updated.(model)
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'j'}})
	m = updated.(model)
	if !m.searching || m.query != "j" || len(m.rows) != 2 {
		t.Fatalf("slash search state: searching=%v query=%q rows=%d", m.searching, m.query, len(m.rows))
	}

	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyCtrlK})
	m = updated.(model)
	if m.cursor != 0 {
		t.Fatalf("ctrl+k moved cursor to %d, want 0", m.cursor)
	}
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyEsc})
	m = updated.(model)
	if m.searching || m.query != "j" {
		t.Fatalf("esc did not retain the filter in command mode: searching=%v query=%q", m.searching, m.query)
	}
	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEsc})
	m = updated.(model)
	if cmd != nil {
		t.Fatal("esc in command mode should not close Kesh")
	}

	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeySpace})
	m = updated.(model)
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'n'}})
	m = updated.(model)
	if len(m.selected) != 1 || !m.creating {
		t.Fatalf("command mode actions failed after search: selected=%#v creating=%v", m.selected, m.creating)
	}
}

func TestWorkspaceCannotBeSelectedAsProjectSource(t *testing.T) {
	m := model{
		entries: []entry{{key: "workspace:aurora", name: "aurora | frontier", kind: "workspace", open: true}},
		rows:    []row{{entryIndex: 0, tabIndex: -1, windowIndex: -1}},
	}
	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeySpace})
	m = updated.(model)
	if len(m.selected) != 0 || m.err == nil || !strings.Contains(m.err.Error(), "source project") {
		t.Fatalf("workspace selection state: selected=%#v err=%v", m.selected, m.err)
	}
}

func TestSelectedHeaderIncludesCountAndProjectName(t *testing.T) {
	m := model{
		width: 140, height: 30,
		entries:  []entry{{key: "/projects/api", name: "API"}},
		selected: map[string]bool{"/projects/api": true},
	}
	m.rebuildRows()
	view := m.View()
	if !strings.Contains(view, "Selected (1): API") || strings.Contains(view, "Selected: 1") {
		t.Fatalf("selected header does not include count and name:\n%s", view)
	}
}

func TestSpaceTogglesTopLevelSelection(t *testing.T) {
	m := model{entries: []entry{{key: "/projects/api", name: "API", kind: "project"}}, rows: []row{{entryIndex: 0, tabIndex: -1, windowIndex: -1}}}
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
