package main

import (
	"os"
	"path/filepath"
	"testing"
)

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
