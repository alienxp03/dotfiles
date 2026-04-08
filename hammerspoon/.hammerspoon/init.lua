local super = { "ctrl", "shift", "alt", "cmd" }

hs.hotkey.bind(super, "r", function()
  hs.reload()
end)

hs.hotkey.bind(super, "g", function()
  hs.application.launchOrFocus("Ghostty")
end)

hs.hotkey.bind(super, "c", function()
  hs.application.launchOrFocus("Google Chrome")
end)

hs.hotkey.bind({"cmd", "shift"}, "D", function()
  local wasRunning = hs.application.get("Safari") ~= nil
  if not wasRunning then
    hs.application.open("Safari")
  end
  hs.timer.waitUntil(
    function()
      local app = hs.application.get("Safari")
      return app ~= nil
    end,
    function()
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
    end,
    0.1
  )
end)

