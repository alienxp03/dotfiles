hs.ipc.cliInstall()

local super = { "ctrl", "shift", "alt", "cmd" }

hs.hotkey.bind(super, "r", function()
	hs.reload()
end)

local function axAttribute(element, attribute)
	local ok, value = pcall(function()
		return element:attributeValue(attribute)
	end)
	if ok then
		return value
	end
end

local function findChromeTabToggle(element)
	if element == nil then
		return nil
	end

	local role = axAttribute(element, "AXRole")
	local description = axAttribute(element, "AXDescription")
	if
		role == "AXButton"
		and (description == "Collapse tabs" or description == "Expand tabs")
	then
		return element
	end

	for _, child in ipairs(axAttribute(element, "AXChildren") or {}) do
		local toggle = findChromeTabToggle(child)
		if toggle ~= nil then
			return toggle
		end
	end
end

local function toggleChromeTabs()
	local app = hs.application.frontmostApplication()
	if app == nil or app:bundleID() ~= "com.google.Chrome" then
		return
	end

	local appElement = hs.axuielement.applicationElement(app)
	local window = axAttribute(appElement, "AXFocusedWindow") or axAttribute(appElement, "AXMainWindow")
	local toggle = findChromeTabToggle(window)
	if toggle ~= nil then
		toggle:performAction("AXPress")
	end
end

local chromeTabsHotkey = hs.hotkey.new({ "ctrl" }, "z", toggleChromeTabs)
local function updateChromeHotkey(app)
	if app == nil then
		app = hs.application.frontmostApplication()
	end

	if app ~= nil and app:bundleID() == "com.google.Chrome" then
		chromeTabsHotkey:enable()
	else
		chromeTabsHotkey:disable()
	end
end

local chromeWatcher = hs.application.watcher.new(function(_, event, app)
	if event == hs.application.watcher.activated then
		updateChromeHotkey(app)
	end
end)
chromeWatcher:start()
updateChromeHotkey()

local function frontmostAppMatches(patterns)
	local app = hs.application.frontmostApplication()
	if app == nil then
		return false
	end

	local window = hs.window.frontmostWindow()
	local name = string.lower(app:name() or "")
	local bundleID = string.lower(app:bundleID() or "")
	local path = string.lower(app:path() or "")
	local pid = app:pid()
	local process = ""
	if pid ~= nil then
		process = string.lower(hs.execute("/bin/ps -p " .. pid .. " -o comm= -o args=", true) or "")
	end
	local title = ""
	if window ~= nil then
		title = string.lower(window:title() or "")
	end

	for _, pattern in ipairs(patterns) do
		if
			string.find(name, pattern, 1, true) ~= nil
			or string.find(bundleID, pattern, 1, true) ~= nil
			or string.find(path, pattern, 1, true) ~= nil
			or string.find(process, pattern, 1, true) ~= nil
			or string.find(title, pattern, 1, true) ~= nil
		then
			return true
		end
	end

	return false
end

local function inspectIosSimulator()
	local wasRunning = hs.application.get("Safari") ~= nil
	if not wasRunning then
		hs.application.open("Safari")
	end
	hs.timer.waitUntil(function()
		local app = hs.application.get("Safari")
		return app ~= nil
	end, function()
		local safari = hs.application.get("Safari")
		if not wasRunning then
			-- Close the Start Page window before opening inspector
			hs.timer.doAfter(0.5, function()
				for _, w in ipairs(safari:allWindows()) do
					w:close()
				end
				hs.timer.doAfter(0.3, function()
					hs.osascript.applescript([[
              tell application "System Events"
                tell process "Safari"
                  set developMenu to menu bar item "Develop" of menu bar 1
                  set simItem to first menu item of menu 1 of developMenu whose name contains "Simulator"
                  set subMenu to menu 1 of simItem
                  set pageItems to every menu item of subMenu whose name contains "localhost" or name contains "127.0.0.1"
                  if (count of pageItems) > 0 then
                    perform action "AXPress" of item 1 of pageItems
                  end if
                end tell
              end tell
            ]])
				end)
			end)
		else
			hs.osascript.applescript([[
          tell application "System Events"
            tell process "Safari"
              set developMenu to menu bar item "Develop" of menu bar 1
              set simItem to first menu item of menu 1 of developMenu whose name contains "Simulator"
              set subMenu to menu 1 of simItem
              set pageItems to every menu item of subMenu whose name contains "localhost" or name contains "127.0.0.1"
              if (count of pageItems) > 0 then
                perform action "AXPress" of item 1 of pageItems
              end if
            end tell
          end tell
        ]])
		end
	end, 0.1)
end

local androidInspectTimer = nil

function inspectAndroidEmulator()
	hs.osascript.applescript([[
    tell application "Google Chrome"
      activate
      if (count of windows) = 0 then make new window
      set URL of active tab of front window to "chrome://inspect/#devices"
    end tell
  ]])

	androidInspectTimer = hs.timer.doAfter(1, function()
		hs.osascript.applescript([[
      tell application "Google Chrome"
        execute active tab of front window javascript "
          const browser = document.querySelector('#devices-list .browser[id^=\"emulator-\"]');
          const inspect = Array.from(browser?.querySelectorAll('.actions .action') || []).find(el => el.textContent.trim() === 'inspect');
          inspect?.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
        "
      end tell
    ]])
		androidInspectTimer = nil
	end)
end

-- hs.hotkey.bind({ "cmd", "shift" }, "xxxx", function()
-- 	if frontmostAppMatches({ "com.apple.iphonesimulator", "simulator" }) then
-- 		inspectIosSimulator()
-- 	elseif
-- 		frontmostAppMatches({
-- 			"android emulator",
-- 			"emulator",
-- 			"qemu-system",
-- 			"com.google.android.emulator",
-- 			"android studio",
-- 			"com.google.android.studio",
-- 		})
-- 	then
-- 		inspectAndroidEmulator()
-- 	end
-- end)
