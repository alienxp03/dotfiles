package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type kittyState []struct {
	Tabs []struct {
		ID       int           `json:"id"`
		Title    string        `json:"title"`
		IsActive bool          `json:"is_active"`
		Windows  []kittyWindow `json:"windows"`
	} `json:"tabs"`
}

type kittyWindow struct {
	ID                  int               `json:"id"`
	Cmdline             []string          `json:"cmdline"`
	Title               string            `json:"title"`
	CWD                 string            `json:"cwd"`
	SessionName         string            `json:"session_name"`
	LastFocusedAt       float64           `json:"last_focused_at"`
	Env                 map[string]string `json:"env"`
	ForegroundProcesses []struct {
		Cmdline []string `json:"cmdline"`
		CWD     string   `json:"cwd"`
	} `json:"foreground_processes"`
}

type windowItem struct {
	id          int
	title       string
	detail      string
	command     string
	agent       string
	lastFocused float64
}

type tabItem struct {
	id       int
	title    string
	detail   string
	agent    string
	expanded bool
	windows  []windowItem
}

type entry struct {
	key          string
	name         string
	originalName string
	detail       string
	kind         string
	session      string
	open         bool
	lastFocused  float64
	nameTaken    bool
	agent        string
	expanded     bool
	tabs         []tabItem
	order        int
	pin          string
}

type row struct {
	entryIndex  int
	tabIndex    int
	windowIndex int
}

type actionMsg struct{ err error }

type previewMsg struct {
	windowID int
	content  string
	err      error
}

type commandResult struct {
	output []byte
	err    error
}

type pinTarget struct {
	Key         string `json:"key"`
	Name        string `json:"name"`
	Kind        string `json:"kind,omitempty"`
	SessionFile string `json:"session_file,omitempty"`
}

type pinStore map[string]pinTarget

type nameStore map[string]string

type renameMsg struct {
	selected row
	title    string
	names    nameStore
	err      error
}

type model struct {
	entries     []entry
	rows        []row
	cursor      int
	query       string
	searching   bool
	renaming    bool
	renameValue string
	pinning     bool
	pinEntry    int
	confirmSlot string
	pins        pinStore
	names       nameStore
	filter      int
	width       int
	height      int
	err         error
	kitty       string
	zoxide      string
	preview     string
	previewErr  error
	previewID   int
	previewBusy bool
	showPreview bool
}

const (
	filterAll = iota
	filterOpen
	filterProjects
	filterSSH
	filterAgents
)

var (
	accentStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("205")).Bold(true)
	dimStyle      = lipgloss.NewStyle().Foreground(lipgloss.Color("241"))
	openStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("42"))
	selectedStyle = lipgloss.NewStyle().Background(lipgloss.Color("236")).Foreground(lipgloss.Color("230")).Bold(true)
	projectStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("75"))
	sshStyle      = lipgloss.NewStyle().Foreground(lipgloss.Color("214"))
	piStyle       = lipgloss.NewStyle().Foreground(lipgloss.Color("81")).Bold(true)
	codexStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("42")).Bold(true)
	errorStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("196"))
	ansiPattern   = regexp.MustCompile(`\x1b\[[0-?]*[ -/]*[@-~]`)
	backgroundSGR = regexp.MustCompile(`\x1b\[(48(:[0-9]*)+|48(;[0-9]*)+|49)m`)
)

func main() {
	kitty, zoxide := commands()
	filter, switchSlot, err := parseArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	if switchSlot != "" {
		if err := switchPin(kitty, zoxide, switchSlot); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}

	fmt.Print("\033]2;kesh\007")
	entries, loadErr := loadEntries(kitty, zoxide)
	pins, pinErr := loadPins()
	names, nameErr := loadNames()
	if loadErr == nil && pinErr != nil {
		loadErr = pinErr
	}
	if loadErr == nil && nameErr != nil {
		loadErr = nameErr
	}
	applyNames(entries, names)
	applyPins(entries, pins)
	m := model{
		entries: entries, err: loadErr, kitty: kitty, zoxide: zoxide, pins: pins, names: names,
		filter: filter, showPreview: true,
	}
	m.rebuildRows()
	m.queuePreview()
	if _, err := tea.NewProgram(m, tea.WithAltScreen()).Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func parseArgs(args []string) (filter int, switchSlot string, err error) {
	switch {
	case len(args) == 0:
		return filterAll, "", nil
	case len(args) == 1 && args[0] == "agents":
		return filterAgents, "", nil
	case len(args) == 2 && args[0] == "switch" && validSlot(args[1]):
		return filterAll, args[1], nil
	default:
		return 0, "", fmt.Errorf("usage: kesh [agents | switch SLOT] (SLOT must be 0-9)")
	}
}

func commands() (string, string) {
	kitty := findCommand("kitty", "/Applications/kitty.app/Contents/MacOS/kitty")
	zoxide := findCommand("zoxide",
		filepath.Join(os.Getenv("HOME"), ".local", "bin", "zoxide"),
		filepath.Join(os.Getenv("HOME"), ".local", "share", "mise", "shims", "zoxide"),
		"/opt/homebrew/bin/zoxide",
	)
	return kitty, zoxide
}

func findCommand(name string, fallbacks ...string) string {
	if path, err := exec.LookPath(name); err == nil {
		return path
	}
	for _, path := range fallbacks {
		if info, err := os.Stat(path); err == nil && !info.IsDir() {
			return path
		}
	}
	return ""
}

func validSlot(slot string) bool {
	return len(slot) == 1 && slot[0] >= '0' && slot[0] <= '9'
}

func pinsPath() string {
	stateHome := os.Getenv("XDG_STATE_HOME")
	if stateHome == "" {
		stateHome = filepath.Join(os.Getenv("HOME"), ".local", "state")
	}
	return filepath.Join(stateHome, "kesh", "pins.json")
}

func namesPath() string {
	return filepath.Join(os.Getenv("HOME"), "config", "kesh", "names.json")
}

func loadNames() (nameStore, error) {
	names := nameStore{}
	content, err := os.ReadFile(namesPath())
	if os.IsNotExist(err) {
		return names, nil
	}
	if err != nil {
		return names, fmt.Errorf("read workspace names: %w", err)
	}
	if err := json.Unmarshal(content, &names); err != nil {
		return nameStore{}, fmt.Errorf("invalid workspace names: %w", err)
	}
	for key, name := range names {
		if key == "" || strings.TrimSpace(name) == "" {
			return nameStore{}, fmt.Errorf("invalid workspace name for %q", key)
		}
	}
	return names, nil
}

func saveNames(names nameStore) error {
	path := namesPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return fmt.Errorf("create workspace name directory: %w", err)
	}
	content, err := json.MarshalIndent(names, "", "  ")
	if err != nil {
		return fmt.Errorf("encode workspace names: %w", err)
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), ".names-*.json")
	if err != nil {
		return fmt.Errorf("create workspace name state: %w", err)
	}
	temporaryName := temporary.Name()
	defer os.Remove(temporaryName)
	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return err
	}
	if _, err := temporary.Write(append(content, '\n')); err != nil {
		temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	if err := os.Rename(temporaryName, path); err != nil {
		return fmt.Errorf("save workspace names: %w", err)
	}
	return nil
}

func applyNames(entries []entry, names nameStore) {
	for index := range entries {
		if entries[index].originalName == "" {
			entries[index].originalName = entries[index].name
		}
		entries[index].name = entries[index].originalName
		if alias := names[entries[index].key]; alias != "" {
			entries[index].name = alias
		}
	}
}

func loadPins() (pinStore, error) {
	pins := pinStore{}
	content, err := os.ReadFile(pinsPath())
	if os.IsNotExist(err) {
		return pins, nil
	}
	if err != nil {
		return pins, fmt.Errorf("read pins: %w", err)
	}
	if err := json.Unmarshal(content, &pins); err != nil {
		return pinStore{}, fmt.Errorf("invalid pin state: %w", err)
	}
	seenTargets := map[string]string{}
	sessionsDirectory := filepath.Clean(filepath.Join(filepath.Dir(pinsPath()), "sessions")) + string(os.PathSeparator)
	for slot, target := range pins {
		if !validSlot(slot) || target.Key == "" {
			return pinStore{}, fmt.Errorf("invalid pin entry for slot %q", slot)
		}
		if target.Kind != "" && target.Kind != "project" && target.Kind != "ssh" {
			return pinStore{}, fmt.Errorf("invalid pin kind for slot %s", slot)
		}
		if target.SessionFile != "" && !strings.HasPrefix(filepath.Clean(target.SessionFile), sessionsDirectory) {
			return pinStore{}, fmt.Errorf("invalid session file for slot %s", slot)
		}
		if previous, exists := seenTargets[target.Key]; exists {
			return pinStore{}, fmt.Errorf("session is pinned more than once: slots %s and %s", previous, slot)
		}
		seenTargets[target.Key] = slot
	}
	return pins, nil
}

func savePins(pins pinStore) error {
	path := pinsPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return fmt.Errorf("create pin directory: %w", err)
	}
	content, err := json.MarshalIndent(pins, "", "  ")
	if err != nil {
		return fmt.Errorf("encode pins: %w", err)
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), ".pins-*.json")
	if err != nil {
		return fmt.Errorf("create pin state: %w", err)
	}
	temporaryName := temporary.Name()
	defer os.Remove(temporaryName)
	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return err
	}
	if _, err := temporary.Write(append(content, '\n')); err != nil {
		temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	if err := os.Rename(temporaryName, path); err != nil {
		return fmt.Errorf("save pins: %w", err)
	}
	return nil
}

func pinTargetForEntry(e entry) (pinTarget, error) {
	directory := filepath.Join(filepath.Dir(pinsPath()), "sessions")
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return pinTarget{}, fmt.Errorf("create pinned session directory: %w", err)
	}
	name := e.session
	if name == "" {
		if e.kind == "ssh" {
			name = "ssh-" + safeName(strings.TrimPrefix(e.key, "ssh://"))
		} else {
			name = safeName(filepath.Base(e.key))
			if e.nameTaken {
				name += "-" + shortHash(e.key)
			}
		}
	}
	path := filepath.Join(directory, safeName(name)+".kitty-session")
	var content string
	if e.kind == "ssh" {
		host := strings.TrimPrefix(e.key, "ssh://")
		content = fmt.Sprintf("layout splits\ncd %s\nlaunch --title \"ssh: %s\" ssh \"%s\"\nfocus\nfocus_os_window\n", os.Getenv("HOME"), host, host)
	} else {
		content = fmt.Sprintf("layout splits\ncd %s\nlaunch --title \"%s\"\nfocus\nfocus_os_window\n", e.key, filepath.Base(e.key))
	}
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		return pinTarget{}, fmt.Errorf("write pinned session: %w", err)
	}
	return pinTarget{Key: e.key, Name: e.name, Kind: e.kind, SessionFile: path}, nil
}

func applyPins(entries []entry, pins pinStore) {
	for index := range entries {
		entries[index].pin = ""
	}
	for slot, target := range pins {
		for index := range entries {
			if entries[index].key == target.Key {
				entries[index].pin = slot
				break
			}
		}
	}
}

func switchPin(kitty, zoxide, slot string) error {
	pins, err := loadPins()
	if err != nil {
		return err
	}
	target, ok := pins[slot]
	if !ok {
		return fmt.Errorf("no session is pinned to slot %s", slot)
	}
	if target.Kind == "project" {
		if info, err := os.Stat(target.Key); err != nil || !info.IsDir() {
			return fmt.Errorf("pinned project is unavailable: %s", target.Key)
		}
	}
	if target.SessionFile != "" {
		if info, err := os.Stat(target.SessionFile); err != nil || info.IsDir() {
			return fmt.Errorf("pinned session file is unavailable: %s", target.SessionFile)
		}
		return run(kitty, "@", "action", "goto_session", target.SessionFile)
	}

	// Older pin entries are migrated on their first use.
	os.Unsetenv("KITTY_WINDOW_ID")
	entries, err := loadEntries(kitty, zoxide)
	if err != nil {
		return err
	}
	for _, candidate := range entries {
		if candidate.key != target.Key {
			continue
		}
		if candidate.kind == "project" && !candidate.open {
			if info, err := os.Stat(candidate.key); err != nil || !info.IsDir() {
				return fmt.Errorf("pinned project is unavailable: %s", candidate.key)
			}
		}
		migrated, err := pinTargetForEntry(candidate)
		if err != nil {
			return err
		}
		pins[slot] = migrated
		if err := savePins(pins); err != nil {
			return err
		}
		return run(kitty, "@", "action", "goto_session", migrated.SessionFile)
	}
	return fmt.Errorf("pinned session is no longer available: %s", target.Name)
}

func (m model) Init() tea.Cmd {
	if m.previewBusy && m.previewID != 0 {
		return fetchPreview(m.kitty, m.previewID)
	}
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case actionMsg:
		if msg.err != nil {
			m.err = msg.err
			return m, nil
		}
		return m, tea.Quit
	case previewMsg:
		if msg.windowID != m.previewID {
			return m, nil
		}
		m.previewBusy = false
		m.preview = msg.content
		m.previewErr = msg.err
	case renameMsg:
		if msg.err != nil {
			m.err = msg.err
			return m, nil
		}
		entry := &m.entries[msg.selected.entryIndex]
		if msg.selected.windowIndex >= 0 {
			entry.tabs[msg.selected.tabIndex].windows[msg.selected.windowIndex].title = msg.title
		} else if msg.selected.tabIndex >= 0 {
			entry.tabs[msg.selected.tabIndex].title = msg.title
		} else {
			m.names = msg.names
			entry.name = msg.title
			if entry.name == "" {
				entry.name = entry.originalName
			}
			m.rebuildRows()
		}
		m.renaming = false
		m.renameValue = ""
		m.err = nil
	case tea.KeyMsg:
		key := msg.String()
		if key == "ctrl+c" {
			return m, tea.Quit
		}
		if m.pinning {
			switch {
			case key == "esc":
				m.pinning = false
				m.confirmSlot = ""
				m.err = nil
			case key == "x":
				m.unpinSelected()
			case validSlot(key):
				m.assignPin(key)
			default:
				m.err = fmt.Errorf("pin slot must be a digit from 0 to 9")
			}
			return m, nil
		}
		if m.renaming {
			switch key {
			case "esc":
				m.renaming = false
				m.renameValue = ""
			case "enter":
				if len(m.rows) > 0 {
					selected := m.rows[m.cursor]
					return m, runRename(m.kitty, m.entries[selected.entryIndex], selected, m.renameValue, m.names)
				}
			case "backspace":
				runes := []rune(m.renameValue)
				if len(runes) > 0 {
					m.renameValue = string(runes[:len(runes)-1])
				}
			case "ctrl+u":
				m.renameValue = ""
			default:
				if len(msg.Runes) > 0 && !msg.Alt && !msg.Paste {
					m.renameValue += string(msg.Runes)
				}
			}
			return m, nil
		}
		if m.searching {
			switch key {
			case "esc", "enter":
				m.searching = false
			case "backspace":
				runes := []rune(m.query)
				if len(runes) > 0 {
					m.query = string(runes[:len(runes)-1])
					m.rebuildRows()
				}
			case "ctrl+u":
				m.query = ""
				m.rebuildRows()
			default:
				if len(msg.Runes) > 0 && !msg.Alt && !msg.Paste {
					m.query += string(msg.Runes)
					m.rebuildRows()
				}
			}
			return m, m.queuePreview()
		}
		switch key {
		case "ctrl+c", "esc", "q":
			return m, tea.Quit
		case "/":
			m.searching = true
		case "up", "ctrl+k", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "ctrl+j", "j":
			if m.cursor+1 < len(m.rows) {
				m.cursor++
			}
		case "right", "l":
			m.expandOrDescend()
		case "left", "h":
			m.ascendOrCollapse()
		case "enter":
			if len(m.rows) == 0 {
				return m, nil
			}
			r := m.rows[m.cursor]
			return m, runAction(m.kitty, m.zoxide, m.entries[r.entryIndex], r)
		case "r":
			m.beginRename()
		case "p":
			if m.filter == filterAgents {
				m.showPreview = !m.showPreview
				if m.showPreview {
					m.previewID = 0
				}
			} else {
				m.beginPin()
			}
		case "tab":
			m.filter = (m.filter + 1) % 5
			m.rebuildRows()
		case "shift+tab":
			m.filter = (m.filter + 4) % 5
			m.rebuildRows()
		}
		return m, m.queuePreview()
	}
	return m, nil
}

func (m *model) beginPin() {
	if len(m.rows) == 0 {
		return
	}
	selected := m.rows[m.cursor]
	m.pinEntry = selected.entryIndex
	m.pinning = true
	m.confirmSlot = ""
	m.err = nil
}

func (m *model) assignPin(slot string) {
	selected := m.entries[m.pinEntry]
	if occupied, ok := m.pins[slot]; ok && occupied.Key != selected.key && m.confirmSlot != slot {
		m.confirmSlot = slot
		m.err = fmt.Errorf("slot %s is pinned to %s; press %s again to replace it", slot, occupied.Name, slot)
		return
	}
	updated := make(pinStore, len(m.pins)+1)
	for existingSlot, target := range m.pins {
		if target.Key != selected.key && existingSlot != slot {
			updated[existingSlot] = target
		}
	}
	target, err := pinTargetForEntry(selected)
	if err != nil {
		m.err = err
		return
	}
	updated[slot] = target
	if err := savePins(updated); err != nil {
		m.err = err
		return
	}
	m.pins = updated
	applyPins(m.entries, m.pins)
	m.pinning = false
	m.confirmSlot = ""
	m.err = nil
}

func (m *model) unpinSelected() {
	selected := m.entries[m.pinEntry]
	updated := make(pinStore, len(m.pins))
	for slot, target := range m.pins {
		if target.Key != selected.key {
			updated[slot] = target
		}
	}
	if len(updated) == len(m.pins) {
		m.err = fmt.Errorf("%s is not pinned", selected.name)
		return
	}
	if err := savePins(updated); err != nil {
		m.err = err
		return
	}
	m.pins = updated
	applyPins(m.entries, m.pins)
	m.pinning = false
	m.confirmSlot = ""
	m.err = nil
}

func (m *model) beginRename() {
	if len(m.rows) == 0 {
		return
	}
	selected := m.rows[m.cursor]
	entry := &m.entries[selected.entryIndex]
	if selected.windowIndex >= 0 {
		m.renameValue = entry.tabs[selected.tabIndex].windows[selected.windowIndex].title
		m.renaming = true
		m.err = nil
		return
	}
	if selected.tabIndex >= 0 {
		m.renameValue = entry.tabs[selected.tabIndex].title
		m.renaming = true
		m.err = nil
		return
	}
	m.renameValue = entry.name
	m.renaming = true
	m.err = nil
}

func (m *model) expandOrDescend() {
	if len(m.rows) == 0 {
		return
	}
	r := m.rows[m.cursor]
	e := &m.entries[r.entryIndex]
	if r.windowIndex >= 0 {
		return
	}
	if r.tabIndex >= 0 {
		tab := &e.tabs[r.tabIndex]
		if len(tab.windows) == 0 {
			return
		}
		if !tab.expanded {
			tab.expanded = true
			m.rebuildRows()
			return
		}
		if m.cursor+1 < len(m.rows) && m.rows[m.cursor+1].tabIndex == r.tabIndex {
			m.cursor++
		}
		return
	}
	if len(e.tabs) == 0 {
		return
	}
	if !e.expanded {
		e.expanded = true
		m.rebuildRows()
		return
	}
	if m.cursor+1 < len(m.rows) && m.rows[m.cursor+1].entryIndex == r.entryIndex {
		m.cursor++
	}
}

func (m *model) ascendOrCollapse() {
	if len(m.rows) == 0 {
		return
	}
	r := m.rows[m.cursor]
	e := &m.entries[r.entryIndex]
	if r.windowIndex >= 0 {
		for m.cursor > 0 {
			m.cursor--
			if m.rows[m.cursor].tabIndex == r.tabIndex && m.rows[m.cursor].windowIndex < 0 {
				break
			}
		}
		return
	}
	if r.tabIndex >= 0 {
		if e.tabs[r.tabIndex].expanded {
			e.tabs[r.tabIndex].expanded = false
			m.rebuildRows()
			return
		}
		for m.cursor > 0 {
			m.cursor--
			if m.rows[m.cursor].tabIndex < 0 {
				break
			}
		}
		return
	}
	if e.expanded {
		e.expanded = false
		m.rebuildRows()
	}
}

func (m *model) rebuildRows() {
	if m.filter == filterAgents {
		m.rebuildAgentRows()
		return
	}
	var rows []row
	for i := range m.entries {
		e := &m.entries[i]
		if !m.matchesFilter(*e) || !fuzzyMatch(m.query, e.name+" "+e.originalName+" "+e.detail) {
			continue
		}
		rows = append(rows, row{entryIndex: i, tabIndex: -1, windowIndex: -1})
		if e.expanded && m.query == "" {
			for tabIndex := range e.tabs {
				rows = append(rows, row{entryIndex: i, tabIndex: tabIndex, windowIndex: -1})
				if e.tabs[tabIndex].expanded {
					for windowIndex := range e.tabs[tabIndex].windows {
						rows = append(rows, row{entryIndex: i, tabIndex: tabIndex, windowIndex: windowIndex})
					}
				}
			}
		}
	}
	m.rows = rows
	if m.cursor >= len(rows) {
		m.cursor = max(0, len(rows)-1)
	}
}

func (m *model) queuePreview() tea.Cmd {
	if m.filter != filterAgents || !m.showPreview || len(m.rows) == 0 {
		if m.filter == filterAgents && len(m.rows) == 0 {
			m.previewID = 0
			m.preview = ""
			m.previewErr = nil
			m.previewBusy = false
		}
		return nil
	}
	r := m.rows[m.cursor]
	if r.windowIndex < 0 {
		return nil
	}
	windowID := m.entries[r.entryIndex].tabs[r.tabIndex].windows[r.windowIndex].id
	if windowID == m.previewID {
		return nil
	}
	m.previewID = windowID
	m.preview = ""
	m.previewErr = nil
	m.previewBusy = true
	return fetchPreview(m.kitty, windowID)
}

func fetchPreview(kitty string, windowID int) tea.Cmd {
	return func() tea.Msg {
		if kitty == "" {
			return previewMsg{windowID: windowID, err: fmt.Errorf("kitty was not found")}
		}
		output, err := exec.Command(
			kitty, "@", "get-text", "--match", "id:"+strconv.Itoa(windowID), "--extent", "screen", "--ansi",
		).CombinedOutput()
		content := cleanPreview(string(output))
		if err != nil {
			message := strings.TrimSpace(ansiPattern.ReplaceAllString(content, ""))
			if message != "" {
				err = fmt.Errorf("%s: %s", err, message)
			}
		}
		return previewMsg{windowID: windowID, content: content, err: err}
	}
}

func cleanPreview(content string) string {
	content = backgroundSGR.ReplaceAllString(content, "")
	lines := strings.Split(content, "\n")
	for len(lines) > 0 && strings.TrimSpace(ansiPattern.ReplaceAllString(lines[len(lines)-1], "")) == "" {
		lines = lines[:len(lines)-1]
	}
	return strings.Join(lines, "\n")
}

func (m *model) rebuildAgentRows() {
	rows := make([]row, 0)
	seen := map[int]bool{}
	for entryIndex := range m.entries {
		e := m.entries[entryIndex]
		for tabIndex := range e.tabs {
			tab := e.tabs[tabIndex]
			for windowIndex := range tab.windows {
				window := tab.windows[windowIndex]
				if window.agent == "" || seen[window.id] {
					continue
				}
				searchValue := strings.Join([]string{
					window.agent, e.name, e.originalName, e.detail, tab.title, window.title, window.command, window.detail,
				}, " ")
				if !fuzzyMatch(m.query, searchValue) {
					continue
				}
				seen[window.id] = true
				rows = append(rows, row{entryIndex: entryIndex, tabIndex: tabIndex, windowIndex: windowIndex})
			}
		}
	}
	sort.SliceStable(rows, func(i, j int) bool {
		a := m.entries[rows[i].entryIndex].tabs[rows[i].tabIndex].windows[rows[i].windowIndex]
		b := m.entries[rows[j].entryIndex].tabs[rows[j].tabIndex].windows[rows[j].windowIndex]
		return a.lastFocused > b.lastFocused
	})
	m.rows = rows
	if m.cursor >= len(rows) {
		m.cursor = max(0, len(rows)-1)
	}
}

func (m model) matchesFilter(e entry) bool {
	switch m.filter {
	case filterOpen:
		return e.open
	case filterProjects:
		return e.kind == "project"
	case filterSSH:
		return e.kind == "ssh"
	default:
		return true
	}
}

func fuzzyMatch(query, value string) bool {
	queryRunes := []rune(strings.ToLower(query))
	valueRunes := []rune(strings.ToLower(value))
	position := 0
	for _, wanted := range queryRunes {
		found := false
		for position < len(valueRunes) {
			got := valueRunes[position]
			position++
			if got == wanted {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	return true
}

func (m model) View() string {
	outerWidth := max(40, m.width-4)
	showSidePreview := m.filter == filterAgents && m.showPreview && outerWidth >= 88
	showBottomPreview := m.filter == filterAgents && m.showPreview && !showSidePreview
	width := outerWidth
	if showSidePreview {
		width = max(40, outerWidth*43/100)
	}
	tabs := []string{"All", "Open", "Projects", "SSH", "Agents"}
	for i := range tabs {
		if i == m.filter {
			tabs[i] = accentStyle.Render("[" + tabs[i] + "]")
		} else {
			tabs[i] = dimStyle.Render(" " + tabs[i] + " ")
		}
	}
	promptLabel := "Search"
	promptValue := dimStyle.Render("press / to search")
	if m.query != "" {
		promptValue = "/" + m.query
	}
	if m.searching {
		promptValue = accentStyle.Render("/"+m.query+"█") + "  " + dimStyle.Render("SEARCH")
	}
	lines := []string{
		accentStyle.Render("Kitty sessions") + "  " + strings.Join(tabs, " "),
		fmt.Sprintf("%-6s  %s", promptLabel, promptValue),
		strings.Repeat("─", width),
	}

	available := max(3, m.height-7)
	if showBottomPreview {
		available = max(3, m.height/2-7)
	}
	start := 0
	if m.cursor >= available {
		start = m.cursor - available + 1
	}
	end := min(len(m.rows), start+available)
	for i := start; i < end; i++ {
		line := m.renderRow(m.rows[i], width-2)
		if i == m.cursor {
			line = accentStyle.Render("❯") + " " + selectedStyle.Width(width-2).Render(line)
		} else {
			line = "  " + line
		}
		lines = append(lines, line)
	}
	if len(m.rows) == 0 {
		lines = append(lines, dimStyle.Render("  No matching sessions"))
	}
	if m.err != nil && !m.renaming && !m.pinning {
		lines = append(lines, errorStyle.Render("Error: "+m.err.Error()))
	}
	footer := "j/k move  h/l collapse/expand  enter open  p pin  r rename  / search  tab filter  q quit"
	if m.filter == filterAgents {
		footer = "j/k move  enter focus  p preview  r rename  / search  tab filter  q quit"
	}
	if m.searching {
		footer = "type to filter  backspace delete  ctrl+u clear  enter/esc normal mode"
	}
	lines = append(lines, dimStyle.Render(footer))
	if popup := m.popupView(width); popup != "" {
		lines = overlayPopup(lines, popup, width)
	}
	list := strings.Join(lines, "\n")
	if showSidePreview {
		previewWidth := max(30, outerWidth-width-3)
		divider := dimStyle.Render(" │ ")
		list = lipgloss.JoinHorizontal(lipgloss.Top, list, divider, m.previewView(previewWidth, max(5, m.height-4)))
	} else if showBottomPreview {
		list += "\n\n" + m.previewView(width, max(5, m.height/2-1))
	}
	return lipgloss.NewStyle().Padding(1, 2).Render(list)
}

func (m model) previewView(width, height int) string {
	content := m.preview
	switch {
	case m.previewBusy:
		content = dimStyle.Render("Loading preview…")
	case m.previewErr != nil:
		content = errorStyle.Render("Preview unavailable: " + m.previewErr.Error())
	case content == "":
		content = dimStyle.Render("No terminal content")
	}
	header := accentStyle.Render("Agent screen")
	body := lipgloss.NewStyle().Width(width).MaxWidth(width).MaxHeight(height - 2).Render(content)
	return lipgloss.NewStyle().Width(width).Height(height).Render(header + "\n" + strings.Repeat("─", width) + "\n" + body)
}

func (m model) popupView(width int) string {
	if !m.renaming && !m.pinning {
		return ""
	}
	popupWidth := min(50, max(28, width-10))
	var title, field, help string
	if m.renaming {
		title = "Rename"
		field = selectedStyle.Width(popupWidth - 6).Render(m.renameValue + "█")
		help = "Enter save  •  Esc cancel"
	} else {
		title = "Pin " + m.entries[m.pinEntry].name
		slot := "█"
		if m.confirmSlot != "" {
			slot = m.confirmSlot
		}
		field = selectedStyle.Width(popupWidth - 6).Render("Slot: " + slot)
		if m.confirmSlot != "" {
			help = "Press " + m.confirmSlot + " again to replace  •  Esc cancel"
		} else {
			help = "0–9 assign  •  x unpin  •  Esc cancel"
		}
	}
	body := accentStyle.Render(title) + "\n\n" + field + "\n\n" + dimStyle.Render(help)
	if m.err != nil {
		body += "\n" + errorStyle.Render(m.err.Error())
	}
	return lipgloss.NewStyle().
		Width(popupWidth).
		Padding(1, 2).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("205")).
		Render(body)
}

func overlayPopup(lines []string, popup string, width int) []string {
	popupLines := strings.Split(popup, "\n")
	start := max(3, (len(lines)-len(popupLines))/2)
	if start+len(popupLines) > len(lines) {
		start = max(3, len(lines)-len(popupLines))
	}
	for index, popupLine := range popupLines {
		lineIndex := start + index
		if lineIndex >= len(lines) {
			break
		}
		lines[lineIndex] = lipgloss.PlaceHorizontal(width, lipgloss.Center, popupLine)
	}
	return lines
}

func (m model) renderRow(r row, width int) string {
	e := m.entries[r.entryIndex]
	if r.windowIndex >= 0 {
		window := e.tabs[r.tabIndex].windows[r.windowIndex]
		if m.filter == filterAgents {
			return m.renderAgentRow(e, e.tabs[r.tabIndex], window, width)
		}
		branch := "├─"
		if r.windowIndex == len(e.tabs[r.tabIndex].windows)-1 {
			branch = "└─"
		}
		detail := window.detail
		if window.command != "" && window.command != window.title {
			detail = window.command + "  " + detail
		}
		nameWidth := max(8, width*4/10-13)
		left := "        " + branch + " " + agentIcon(window.agent) + " " + truncate(window.title, nameWidth)
		return padColumns(left, dimStyle.Render(truncate(detail, max(10, width-44))), width)
	}
	if r.tabIndex >= 0 {
		tab := e.tabs[r.tabIndex]
		branch := "├─"
		if r.tabIndex == len(e.tabs)-1 {
			branch = "└─"
		}
		arrow := " "
		if len(tab.windows) > 0 {
			arrow = "▸"
			if tab.expanded {
				arrow = "▾"
			}
		}
		nameWidth := max(8, width*4/10-14)
		left := fmt.Sprintf("    %s %s %s %s %s", branch, arrow, projectStyle.Render("󱂬"), agentIcon(tab.agent), truncate(tab.title, nameWidth))
		return padColumns(left, dimStyle.Render(tab.detail), width)
	}
	marker := dimStyle.Render("○")
	if e.open {
		marker = openStyle.Render("●")
	}
	arrow := " "
	if len(e.tabs) > 0 {
		arrow = "▸"
		if e.expanded {
			arrow = "▾"
		}
	}
	icon := projectStyle.Render("󰈹")
	if e.kind == "ssh" {
		icon = sshStyle.Render("⚡")
	}
	pin := "   "
	if e.pin != "" {
		pin = accentStyle.Render("[" + e.pin + "]")
	}
	nameWidth := max(8, width*4/10-13)
	left := fmt.Sprintf("%s %s %s %s %s %-*s", marker, pin, arrow, icon, agentIcon(e.agent), nameWidth, truncate(e.name, nameWidth))
	return padColumns(left, dimStyle.Render(truncate(e.detail, max(10, width-38))), width)
}

func (m model) renderAgentRow(e entry, tab tabItem, window windowItem, width int) string {
	agent := agentLabel(window.agent)
	context := e.name
	if tab.title != "" && tab.title != e.name {
		context += " / " + tab.title
	}
	leftWidth := max(12, width*4/10)
	left := agentIcon(window.agent) + " " + agent + "  " + truncate(context, max(8, leftWidth-len(agent)-3))
	detail := window.detail
	if window.command != "" && window.command != window.title {
		detail = window.command + "  " + detail
	}
	return padColumns(left, dimStyle.Render(truncate(detail, max(10, width-leftWidth-2))), width)
}

func agentLabel(agent string) string {
	switch agent {
	case "pi":
		return "Pi"
	case "codex":
		return "Codex"
	case "pi,codex":
		return "Pi+Codex"
	default:
		return agent
	}
}

func agentIcon(agent string) string {
	switch agent {
	case "pi":
		return piStyle.Render("π")
	case "codex":
		return codexStyle.Render("󰚩")
	case "pi,codex":
		return piStyle.Render("π") + codexStyle.Render("󰚩")
	default:
		return " "
	}
}

func padColumns(left, right string, width int) string {
	// Use 40% for the name/tree column and 60% for details.
	space := width*4/10 - lipgloss.Width(left)
	if space < 2 {
		space = 2
	}
	return left + strings.Repeat(" ", space) + right
}

func truncate(value string, width int) string {
	if width <= 1 {
		return ""
	}
	runes := []rune(value)
	if len(runes) <= width {
		return value
	}
	return string(runes[:width-1]) + "…"
}

func commandOutput(name string, args ...string) <-chan commandResult {
	result := make(chan commandResult, 1)
	go func() {
		output, err := exec.Command(name, args...).Output()
		result <- commandResult{output: output, err: err}
	}()
	return result
}

func loadEntries(kitty, zoxide string) ([]entry, error) {
	if kitty == "" {
		return nil, fmt.Errorf("kitty was not found")
	}
	if zoxide == "" {
		return nil, fmt.Errorf("zoxide was not found")
	}
	kittyResult := commandOutput(kitty, "@", "ls")
	zoxideResult := commandOutput(zoxide, "query", "-l")
	kittyOutput := <-kittyResult
	zoxideOutput := <-zoxideResult
	if kittyOutput.err != nil {
		return nil, fmt.Errorf("kitty @ ls: %w", kittyOutput.err)
	}
	if zoxideOutput.err != nil {
		return nil, fmt.Errorf("zoxide query: %w", zoxideOutput.err)
	}
	var state kittyState
	if err := json.Unmarshal(kittyOutput.output, &state); err != nil {
		return nil, fmt.Errorf("decode kitty state: %w", err)
	}
	selfID, _ := strconv.Atoi(os.Getenv("KITTY_WINDOW_ID"))
	type openSession struct {
		path    string
		focused float64
		tabs    []tabItem
	}
	sessions := map[string]*openSession{}
	sessionNames := map[string]bool{}
	aliasPaths := map[string]bool{}
	unscopedTabs := map[string][]tabItem{}
	unscopedFocus := map[string]float64{}
	openSSH := map[string]float64{}

	for _, osWindow := range state {
		for _, tab := range osWindow.Tabs {
			if isKeshTab(tab.Windows) {
				continue
			}
			sessionName := ""
			canonicalPath := ""
			var windows []windowItem
			focused := float64(0)
			for _, window := range tab.Windows {
				if window.ID == selfID {
					continue
				}
				path := windowPath(window)
				if canonicalPath == "" {
					canonicalPath = path
				}
				if sessionName == "" && window.SessionName != "" {
					sessionName = window.SessionName
					canonicalPath = path
				}
				focused = max(focused, window.LastFocusedAt)
				windows = append(windows, windowItemFromKitty(window))
			}
			if len(windows) > 0 {
				title := tab.Title
				if title == "" {
					title = "tab " + strconv.Itoa(tab.ID)
				}
				item := tabItem{
					id: tab.ID, title: title,
					detail:  fmt.Sprintf("%d window%s", len(windows), plural(len(windows))),
					agent:   mergedAgents(windows),
					windows: windows,
				}
				if sessionName == "" && canonicalPath != "" {
					unscopedTabs[canonicalPath] = append(unscopedTabs[canonicalPath], item)
					unscopedFocus[canonicalPath] = max(unscopedFocus[canonicalPath], focused)
				} else if sessionName != "" {
					sessionNames[sessionName] = true
					s := sessions[sessionName]
					if s == nil {
						s = &openSession{path: canonicalPath}
						sessions[sessionName] = s
					}
					for _, window := range tab.Windows {
						if window.ID == selfID {
							continue
						}
						path := windowPath(window)
						if path != "" && path != s.path {
							aliasPaths[path] = true
						}
					}
					s.focused = max(s.focused, focused)
					s.tabs = append(s.tabs, item)
				}
			}
			for _, window := range tab.Windows {
				if window.ID == selfID {
					continue
				}
				if host := sshHost(window); host != "" {
					openSSH[host] = max(openSSH[host], window.LastFocusedAt)
				}
			}
		}
	}

	byPath := map[string]string{}
	openPaths := map[string]float64{}
	tabsByPath := map[string][]tabItem{}
	for name, session := range sessions {
		if session.path != "" && !strings.HasPrefix(name, "ssh-") {
			byPath[session.path] = name
			openPaths[session.path] = session.focused
			tabsByPath[session.path] = session.tabs
		}
	}
	for path, tabs := range unscopedTabs {
		openPaths[path] = max(openPaths[path], unscopedFocus[path])
		tabsByPath[path] = append(tabsByPath[path], tabs...)
	}

	paths := strings.FieldsFunc(string(zoxideOutput.output), func(r rune) bool { return r == '\n' || r == '\r' })
	known := map[string]bool{}
	for _, path := range paths {
		known[path] = true
	}
	for path := range openPaths {
		if !known[path] {
			paths = append(paths, path)
		}
	}

	var entries []entry
	order := 0
	home := os.Getenv("HOME")
	for _, path := range paths {
		if path == "" || path == "/" || (aliasPaths[path] && openPaths[path] == 0) {
			continue
		}
		name := filepath.Base(path)
		session := byPath[path]
		tabs := tabsByPath[path]
		entries = append(entries, entry{
			key: path, name: name, originalName: name, detail: displayPath(path, home), kind: "project",
			session: session, open: len(tabs) > 0, lastFocused: openPaths[path],
			nameTaken: sessionNames[safeName(name)], agent: mergedTabAgents(tabs), tabs: tabs, order: order,
		})
		order++
	}
	for _, host := range readSSHHosts(filepath.Join(home, ".ssh", "config")) {
		var tabs []tabItem
		session := ""
		if _, ok := openSSH[host.name]; ok {
			session = "ssh-" + safeName(host.name)
			if s := sessions[session]; s != nil {
				tabs = s.tabs
			}
		}
		entries = append(entries, entry{
			key: "ssh://" + host.name, name: host.name, originalName: host.name, detail: host.target, kind: "ssh",
			session: session, open: session != "", lastFocused: openSSH[host.name],
			agent: mergedTabAgents(tabs), tabs: tabs, order: order,
		})
		order++
	}
	sort.SliceStable(entries, func(i, j int) bool {
		a, b := entries[i], entries[j]
		if a.open != b.open {
			return a.open
		}
		if a.open && a.lastFocused != b.lastFocused {
			return a.lastFocused > b.lastFocused
		}
		if !a.open && a.kind != b.kind {
			return a.kind == "ssh"
		}
		return a.order < b.order
	})
	return entries, nil
}

func isKeshTab(windows []kittyWindow) bool {
	if len(windows) == 0 {
		return false
	}
	for _, window := range windows {
		commands := append([][]string{window.Cmdline}, foregroundCmdlines(window)...)
		found := false
		for _, command := range commands {
			if len(command) > 0 && strings.Contains(command[0], "/kitty/scripts/kesh/kesh") {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	return true
}

func foregroundCmdlines(window kittyWindow) [][]string {
	commands := make([][]string, 0, len(window.ForegroundProcesses))
	for _, process := range window.ForegroundProcesses {
		commands = append(commands, process.Cmdline)
	}
	return commands
}

func windowPath(window kittyWindow) string {
	if path := window.Env["PWD"]; path != "" {
		return path
	}
	return window.CWD
}

func windowItemFromKitty(window kittyWindow) windowItem {
	command := ""
	detail := windowPath(window)
	if len(window.ForegroundProcesses) > 0 {
		process := window.ForegroundProcesses[len(window.ForegroundProcesses)-1]
		if len(process.Cmdline) > 0 {
			command = filepath.Base(process.Cmdline[0])
		}
		if process.CWD != "" {
			detail = process.CWD
		}
	}
	title := window.Title
	if title == "" {
		title = command
	}
	if title == "" {
		title = "window " + strconv.Itoa(window.ID)
	}
	return windowItem{
		id: window.ID, title: title, detail: displayPath(detail, os.Getenv("HOME")), command: command,
		agent: agentFromWindow(window), lastFocused: window.LastFocusedAt,
	}
}

func agentFromWindow(window kittyWindow) string {
	pi, codex := false, false
	for _, process := range window.ForegroundProcesses {
		command := " " + strings.ToLower(strings.Join(process.Cmdline, " ")) + " "
		pi = pi || strings.Contains(command, " pi ") || strings.Contains(command, "/pi ")
		codex = codex || strings.Contains(command, " codex ") || strings.Contains(command, "/codex ")
	}
	if pi && codex {
		return "pi,codex"
	}
	if pi {
		return "pi"
	}
	if codex {
		return "codex"
	}
	return ""
}

func mergedAgents(windows []windowItem) string {
	pi, codex := false, false
	for _, window := range windows {
		pi = pi || strings.Contains(window.agent, "pi")
		codex = codex || strings.Contains(window.agent, "codex")
	}
	if pi && codex {
		return "pi,codex"
	}
	if pi {
		return "pi"
	}
	if codex {
		return "codex"
	}
	return ""
}

func mergedTabAgents(tabs []tabItem) string {
	pi, codex := false, false
	for _, tab := range tabs {
		pi = pi || strings.Contains(tab.agent, "pi")
		codex = codex || strings.Contains(tab.agent, "codex")
	}
	if pi && codex {
		return "pi,codex"
	}
	if pi {
		return "pi"
	}
	if codex {
		return "codex"
	}
	return ""
}

func plural(count int) string {
	if count == 1 {
		return ""
	}
	return "s"
}

func sshHost(window kittyWindow) string {
	for _, process := range window.ForegroundProcesses {
		if len(process.Cmdline) > 1 && filepath.Base(process.Cmdline[0]) == "ssh" {
			return process.Cmdline[1]
		}
	}
	return ""
}

type sshConfigHost struct{ name, target string }

func readSSHHosts(path string) []sshConfigHost {
	content, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	wildcard := regexp.MustCompile(`[*?!]`)
	options := map[string]map[string]string{}
	var current []string
	for _, raw := range strings.Split(string(content), "\n") {
		line := strings.TrimSpace(strings.SplitN(raw, "#", 2)[0])
		parts := strings.Fields(line)
		if len(parts) == 0 {
			continue
		}
		switch strings.ToLower(parts[0]) {
		case "host":
			current = nil
			for _, host := range parts[1:] {
				if !wildcard.MatchString(host) {
					current = append(current, host)
					if options[host] == nil {
						options[host] = map[string]string{}
					}
				}
			}
		case "user", "hostname", "port":
			if len(parts) < 2 {
				continue
			}
			key := strings.ToLower(parts[0])
			for _, host := range current {
				if options[host][key] == "" {
					options[host][key] = parts[1]
				}
			}
		}
	}
	names := make([]string, 0, len(options))
	for name := range options {
		names = append(names, name)
	}
	sort.Strings(names)
	result := make([]sshConfigHost, 0, len(names))
	for _, name := range names {
		hostname := strings.ReplaceAll(options[name]["hostname"], "%h", name)
		if hostname == "" {
			hostname = name
		}
		user := options[name]["user"]
		if user == "" {
			user = os.Getenv("USER")
		}
		port := options[name]["port"]
		if port == "" {
			port = "22"
		}
		target := hostname + ":" + port
		if user != "" {
			target = user + "@" + target
		}
		result = append(result, sshConfigHost{name: name, target: target})
	}
	return result
}

func runRename(kitty string, e entry, selected row, title string, names nameStore) tea.Cmd {
	return func() tea.Msg {
		var err error
		if selected.windowIndex >= 0 {
			window := e.tabs[selected.tabIndex].windows[selected.windowIndex]
			err = run(kitty, "@", "set-window-title", "--match", "id:"+strconv.Itoa(window.id), title)
		} else if selected.tabIndex >= 0 {
			tab := e.tabs[selected.tabIndex]
			err = run(kitty, "@", "set-tab-title", "--match", "id:"+strconv.Itoa(tab.id), title)
		} else {
			title = strings.TrimSpace(title)
			updated := make(nameStore, len(names)+1)
			for key, name := range names {
				updated[key] = name
			}
			if title == "" {
				delete(updated, e.key)
			} else {
				updated[e.key] = title
			}
			err = saveNames(updated)
			names = updated
		}
		return renameMsg{selected: selected, title: title, names: names, err: err}
	}
}

func runAction(kitty, zoxide string, e entry, selected row) tea.Cmd {
	return func() tea.Msg {
		if selected.windowIndex >= 0 {
			window := e.tabs[selected.tabIndex].windows[selected.windowIndex]
			return actionMsg{err: run(kitty, "@", "focus-window", "--match", "id:"+strconv.Itoa(window.id))}
		}
		if selected.tabIndex >= 0 {
			return actionMsg{err: run(kitty, "@", "focus-tab", "--match", "id:"+strconv.Itoa(e.tabs[selected.tabIndex].id))}
		}
		if e.session != "" {
			return actionMsg{err: run(kitty, "@", "action", "goto_session", e.session)}
		}
		if len(e.tabs) > 0 {
			return actionMsg{err: run(kitty, "@", "focus-tab", "--match", "id:"+strconv.Itoa(e.tabs[0].id))}
		}
		sessionDir := filepath.Join(os.TempDir(), "kitty-zoxide-sessions")
		if err := os.MkdirAll(sessionDir, 0o755); err != nil {
			return actionMsg{err: err}
		}
		if e.kind == "ssh" {
			host := strings.TrimPrefix(e.key, "ssh://")
			file := filepath.Join(sessionDir, "ssh-"+safeName(host)+".kitty-session")
			content := fmt.Sprintf("layout splits\ncd %s\nlaunch --title \"ssh: %s\" ssh \"%s\"\nfocus\nfocus_os_window\n", os.Getenv("HOME"), host, host)
			if err := os.WriteFile(file, []byte(content), 0o600); err != nil {
				return actionMsg{err: err}
			}
			return actionMsg{err: run(kitty, "@", "action", "goto_session", file)}
		}
		name := safeName(filepath.Base(e.key))
		if e.nameTaken {
			name += "-" + shortHash(e.key)
		}
		file := filepath.Join(sessionDir, name+".kitty-session")
		content := fmt.Sprintf("layout splits\ncd %s\nlaunch --title \"%s\"\nfocus\nfocus_os_window\n", e.key, filepath.Base(e.key))
		if err := os.WriteFile(file, []byte(content), 0o600); err != nil {
			return actionMsg{err: err}
		}
		if err := run(kitty, "@", "action", "goto_session", file); err != nil {
			return actionMsg{err: err}
		}
		_ = run(zoxide, "add", "--", e.key)
		return actionMsg{}
	}
}

func run(name string, args ...string) error {
	if name == "" {
		return fmt.Errorf("required command was not found")
	}
	output, err := exec.Command(name, args...).CombinedOutput()
	if err != nil {
		message := strings.TrimSpace(string(output))
		if message != "" {
			return fmt.Errorf("%s: %s", err, message)
		}
	}
	return err
}

func safeName(value string) string {
	return regexp.MustCompile(`[^A-Za-z0-9._-]+`).ReplaceAllString(value, "_")
}

func shortHash(value string) string {
	// FNV-1a is sufficient here; the hash only disambiguates equal basenames.
	var hash uint32 = 2166136261
	for i := 0; i < len(value); i++ {
		hash ^= uint32(value[i])
		hash *= 16777619
	}
	return fmt.Sprintf("%06x", hash)[:6]
}

func displayPath(path, home string) string {
	if path == home {
		return "~"
	}
	if strings.HasPrefix(path, home+string(os.PathSeparator)) {
		return "~" + strings.TrimPrefix(path, home)
	}
	return path
}
