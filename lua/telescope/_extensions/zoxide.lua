local pickers = require("telescope.pickers")
local sorters = require("telescope.sorters")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local zoxide = require("zoxide")

local telescope_opts = {}

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

local function pick(context)
  pickers
    .new(telescope_opts, {
      prompt_title = string.format("Zoxide[%s]", context.scope or "global"),
      finder = live_finder,
      sorter = sorter,
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          context.query = action_state.get_current_line()
          actions.close(prompt_bufnr)
          local entry = action_state.get_selected_entry()
          zoxide.cd(context, entry.ordinal)
        end)
        return true
      end,
    })
    :find()
end

local function make_ctx(scope)
  return { scope = scope, mode = "single", query = "" }
end

return require("telescope").register_extension({
  setup = function(opts)
    telescope_opts = opts
  end,
  exports = {
    zoxide = function()
      pick(make_ctx("global"))
    end,
    tab = function()
      pick(make_ctx("tab"))
    end,
    window = function()
      pick(make_ctx("window"))
    end,
  },
})
