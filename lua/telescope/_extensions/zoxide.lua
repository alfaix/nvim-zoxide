local pickers = require("telescope.pickers")
local sorters = require("telescope.sorters")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local zoxide = require("zoxide")

local telescope_opts = {}

local default_mappings = {
  ["<CR>"] = "global_cd",
  ["<C-y>"] = "tab_cd",
  ["<C-t>"] = "tab_new",
  ["<C-v>"] = "vsplit_cd",
  ["<C-s>"] = "split_cd",
}

local active_mappings = default_mappings

local function merge_mappings(defaults, overrides)
  local result = vim.tbl_extend("force", {}, defaults)
  if overrides then
    for key, action in pairs(overrides) do
      if action == false then
        result[key] = nil
      else
        result[key] = action
      end
    end
  end
  return result
end

local function make_handler(prompt_bufnr, pre_cmd, cd_cmd)
  actions.close(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  if entry then
    local dir = vim.fn.fnameescape(entry.ordinal)
    zoxide.increment(entry.ordinal)
    if pre_cmd then
      vim.cmd(pre_cmd)
    end
    vim.cmd(cd_cmd .. " " .. dir)
  end
end

local action_handlers = {
  global_cd = function(prompt_bufnr)
    make_handler(prompt_bufnr, nil, "cd")
  end,
  tab_cd = function(prompt_bufnr)
    make_handler(prompt_bufnr, nil, "tcd")
  end,
  window_cd = function(prompt_bufnr)
    make_handler(prompt_bufnr, nil, "lcd")
  end,
  tab_new = function(prompt_bufnr)
    make_handler(prompt_bufnr, "tabnew", "tcd")
  end,
  vsplit_cd = function(prompt_bufnr)
    make_handler(prompt_bufnr, "vsplit", "lcd")
  end,
  split_cd = function(prompt_bufnr)
    make_handler(prompt_bufnr, "split", "lcd")
  end,
}

local live_finder = finders.new_job(function(prompt)
  if prompt == "" or not prompt then
    return nil
  end
  return { zoxide.get_config().path, "query", "--score", "--list", "--", prompt }
end, function(entry)
  local nonspace = string.find(entry, "%S")
  local space = string.find(entry, "%s", nonspace + 1, false)
  assert(space ~= -1, "no score given")
  local result = {
    value = entry,
    score = tonumber(string.sub(entry, 1, space - 1)),
    ordinal = string.sub(entry, space + 1),
    display = string.sub(entry, space + 1),
  }
  return result
end)

local sorter = sorters.Sorter:new({
  scoring_function = function(_, _, _, entry)
    return -entry.score
  end,
})

local function pick(cr_override)
  local mappings = active_mappings
  if cr_override then
    mappings = vim.tbl_extend("force", {}, mappings)
    mappings["<CR>"] = cr_override
  end

  pickers
    .new(telescope_opts, {
      prompt_title = "Zoxide",
      finder = live_finder,
      sorter = sorter,
      attach_mappings = function(prompt_bufnr, map)
        for key, action_name in pairs(mappings) do
          local handler = action_handlers[action_name]
          if handler then
            if key == "<CR>" then
              actions.select_default:replace(function()
                handler(prompt_bufnr)
              end)
            else
              map("i", key, function()
                handler(prompt_bufnr)
              end)
              map("n", key, function()
                handler(prompt_bufnr)
              end)
            end
          end
        end
        return true
      end,
    })
    :find()
end

return require("telescope").register_extension({
  setup = function(opts)
    local user_mappings = opts.mappings
    opts.mappings = nil
    telescope_opts = opts
    active_mappings = merge_mappings(default_mappings, user_mappings)
  end,
  exports = {
    zoxide = function()
      pick()
    end,
    tab = function()
      pick("tab_cd")
    end,
    window = function()
      pick("window_cd")
    end,
  },
})
