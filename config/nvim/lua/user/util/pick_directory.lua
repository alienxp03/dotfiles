local function get_directories()
  local directories = {}
  local handle = io.popen("fd . --type directory --hidden --exclude .git")
  if handle then
    for line in handle:lines() do
      table.insert(directories, line)
    end
    handle:close()
  end
  return directories
end

local titles = {
  files = "Select Folder to Search Files In",
  grep = "Select Folder to Grep In",
}

local labels = {
  files = "Files in: ",
  grep = "Grep in: ",
}

---@param mode "files"|"grep"
return function(mode)
  local dirs = get_directories()

  Snacks.picker({
    finder = function()
      local items = {}
      for i, item in ipairs(dirs) do
        table.insert(items, {
          idx = i,
          file = item,
          text = item,
        })
      end
      return items
    end,
    layout = {
      layout = {
        box = "horizontal",
        width = 0.5,
        height = 0.5,
        {
          box = "vertical",
          border = "rounded",
          title = titles[mode],
          { win = "input", height = 1, border = "bottom" },
          { win = "list", border = "none" },
        },
      },
    },
    format = function(item, _)
      local file = item.file
      local ret = {}
      local a = Snacks.picker.util.align
      local icon, icon_hl = Snacks.util.icon(file.ft, "directory")
      ret[#ret + 1] = { a(icon, 3), icon_hl }
      ret[#ret + 1] = { " " }
      ret[#ret + 1] = { a(file, 20) }
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      Snacks.picker[mode]({
        cwd = item.file,
        title = labels[mode] .. item.file,
      })
    end,
  })
end
