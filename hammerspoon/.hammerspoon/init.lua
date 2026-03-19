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
