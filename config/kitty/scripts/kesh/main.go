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
	id      int
	title   string
	detail  string
	command string
}

type tabItem struct {
	id       int
	title    string
	detail   string
	expanded bool
	windows  []windowItem
}

type entry struct {
	key         string
	name        string
	detail      string
	kind        string
	session     string
	open        bool
	lastFocused float64
	nameTaken   bool
	expanded    bool
	tabs        []tabItem
	order       int
}

type row struct {
	entryIndex  int
	tabIndex    int
	windowIndex int
}

type actionMsg struct{ err error }

type renameMsg struct {
	selected row
	title    string
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
	filter      int
	width       int
	height      int
	err         error
	kitty       string
	zoxide      string
}

var (
	accentStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("205")).Bold(true)
	dimStyle      = lipgloss.NewStyle().Foreground(lipgloss.Color("241"))
	openStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("42"))
	selectedStyle = lipgloss.NewStyle().Background(lipgloss.Color("236")).Foreground(lipgloss.Color("230")).Bold(true)
	projectStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("75"))
	sshStyle      = lipgloss.NewStyle().Foreground(lipgloss.Color("214"))
	errorStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("196"))
)

func main() {
	fmt.Print("\033]2;kesh\007")
	kitty := findCommand("kitty", "/Applications/kitty.app/Contents/MacOS/kitty")
	zoxide := findCommand("zoxide",
		filepath.Join(os.Getenv("HOME"), ".local", "bin", "zoxide"),
		filepath.Join(os.Getenv("HOME"), ".local", "share", "mise", "shims", "zoxide"),
		"/opt/homebrew/bin/zoxide",
	)
	entries, loadErr := loadEntries(kitty, zoxide)
	m := model{entries: entries, err: loadErr, kitty: kitty, zoxide: zoxide}
	m.rebuildRows()
	if _, err := tea.NewProgram(m, tea.WithAltScreen()).Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
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

func (m model) Init() tea.Cmd {
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
	case renameMsg:
		if msg.err != nil {
			m.err = msg.err
			return m, nil
		}
		entry := &m.entries[msg.selected.entryIndex]
		if msg.selected.windowIndex >= 0 {
			entry.tabs[msg.selected.tabIndex].windows[msg.selected.windowIndex].title = msg.title
		} else {
			entry.tabs[msg.selected.tabIndex].title = msg.title
		}
		m.renaming = false
		m.renameValue = ""
		m.err = nil
	case tea.KeyMsg:
		key := msg.String()
		if key == "ctrl+c" {
			return m, tea.Quit
		}
		if m.renaming {
			switch key {
			case "esc":
				m.renaming = false
				m.renameValue = ""
			case "enter":
				if len(m.rows) > 0 {
					selected := m.rows[m.cursor]
					return m, runRename(m.kitty, m.entries[selected.entryIndex], selected, m.renameValue)
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
			return m, nil
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
		case "tab":
			m.filter = (m.filter + 1) % 4
			m.rebuildRows()
		case "shift+tab":
			m.filter = (m.filter + 3) % 4
			m.rebuildRows()
		}
	}
	return m, nil
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
	m.err = fmt.Errorf("Kitty session names cannot be changed; select a tab or window")
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
	var rows []row
	for i := range m.entries {
		e := &m.entries[i]
		if !m.matchesFilter(*e) || !fuzzyMatch(m.query, e.name+" "+e.detail) {
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

func (m model) matchesFilter(e entry) bool {
	switch m.filter {
	case 1:
		return e.open
	case 2:
		return e.kind == "project"
	case 3:
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
	width := max(40, m.width-4)
	tabs := []string{"All", "Open", "Projects", "SSH"}
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
	if m.renaming {
		promptLabel = "Rename"
		promptValue = accentStyle.Render(m.renameValue + "█")
	}
	lines := []string{
		accentStyle.Render("Kitty sessions") + "  " + strings.Join(tabs, " "),
		fmt.Sprintf("%-6s  %s", promptLabel, promptValue),
		strings.Repeat("─", width),
	}

	available := max(3, m.height-7)
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
	if m.err != nil {
		lines = append(lines, errorStyle.Render("Error: "+m.err.Error()))
	}
	footer := "j/k move  h/l collapse/expand  enter open  r rename  / search  tab filter  q quit"
	if m.searching {
		footer = "type to filter  backspace delete  ctrl+u clear  enter/esc normal mode"
	}
	if m.renaming {
		footer = "type a title  backspace delete  ctrl+u clear  enter save  esc cancel"
	}
	lines = append(lines, dimStyle.Render(footer))
	return lipgloss.NewStyle().Padding(1, 2).Render(strings.Join(lines, "\n"))
}

func (m model) renderRow(r row, width int) string {
	e := m.entries[r.entryIndex]
	if r.windowIndex >= 0 {
		window := e.tabs[r.tabIndex].windows[r.windowIndex]
		branch := "├─"
		if r.windowIndex == len(e.tabs[r.tabIndex].windows)-1 {
			branch = "└─"
		}
		detail := window.detail
		if window.command != "" && window.command != window.title {
			detail = window.command + "  " + detail
		}
		nameWidth := max(8, width*4/10-16)
		left := "        " + branch + " " + projectStyle.Render("󱂬") + "  " + truncate(window.title, nameWidth)
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
		left := fmt.Sprintf("    %s %s ▣  %s", branch, arrow, truncate(tab.title, nameWidth))
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
	nameWidth := max(8, width*4/10-9)
	left := fmt.Sprintf("%s %s %s  %-*s", marker, arrow, icon, nameWidth, truncate(e.name, nameWidth))
	return padColumns(left, dimStyle.Render(truncate(e.detail, max(10, width-38))), width)
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

func loadEntries(kitty, zoxide string) ([]entry, error) {
	if kitty == "" {
		return nil, fmt.Errorf("kitty was not found")
	}
	if zoxide == "" {
		return nil, fmt.Errorf("zoxide was not found")
	}
	output, err := exec.Command(kitty, "@", "ls").Output()
	if err != nil {
		return nil, fmt.Errorf("kitty @ ls: %w", err)
	}
	var state kittyState
	if err := json.Unmarshal(output, &state); err != nil {
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
	openSSH := map[string]float64{}

	for _, osWindow := range state {
		for _, tab := range osWindow.Tabs {
			sessionName := ""
			canonicalPath := ""
			for _, window := range tab.Windows {
				if window.ID != selfID && window.SessionName != "" {
					sessionName = window.SessionName
					canonicalPath = windowPath(window)
					break
				}
			}
			if sessionName != "" {
				sessionNames[sessionName] = true
				s := sessions[sessionName]
				if s == nil {
					s = &openSession{path: canonicalPath}
					sessions[sessionName] = s
				}
				var windows []windowItem
				for _, window := range tab.Windows {
					if window.ID == selfID {
						continue
					}
					path := windowPath(window)
					if path != "" && path != s.path {
						aliasPaths[path] = true
					}
					s.focused = max(s.focused, window.LastFocusedAt)
					windows = append(windows, windowItemFromKitty(window))
				}
				if len(windows) > 0 {
					title := tab.Title
					if title == "" {
						title = "tab " + strconv.Itoa(tab.ID)
					}
					s.tabs = append(s.tabs, tabItem{
						id: tab.ID, title: title,
						detail:  fmt.Sprintf("%d window%s", len(windows), plural(len(windows))),
						windows: windows,
					})
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

	zoxideOutput, err := exec.Command(zoxide, "query", "-l").Output()
	if err != nil {
		return nil, fmt.Errorf("zoxide query: %w", err)
	}
	paths := strings.FieldsFunc(string(zoxideOutput), func(r rune) bool { return r == '\n' || r == '\r' })
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
		entries = append(entries, entry{
			key: path, name: name, detail: displayPath(path, home), kind: "project",
			session: session, open: session != "", lastFocused: openPaths[path],
			nameTaken: sessionNames[safeName(name)], tabs: tabsByPath[path], order: order,
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
			key: "ssh://" + host.name, name: host.name, detail: host.target, kind: "ssh",
			session: session, open: session != "", lastFocused: openSSH[host.name],
			tabs: tabs, order: order,
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
	return windowItem{id: window.ID, title: title, detail: displayPath(detail, os.Getenv("HOME")), command: command}
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

func runRename(kitty string, e entry, selected row, title string) tea.Cmd {
	return func() tea.Msg {
		var err error
		if selected.windowIndex >= 0 {
			window := e.tabs[selected.tabIndex].windows[selected.windowIndex]
			err = run(kitty, "@", "set-window-title", "--match", "id:"+strconv.Itoa(window.id), title)
		} else {
			tab := e.tabs[selected.tabIndex]
			err = run(kitty, "@", "set-tab-title", "--match", "id:"+strconv.Itoa(tab.id), title)
		}
		return renameMsg{selected: selected, title: title, err: err}
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
