local Job = require("plenary.job")
local M = {}

local COMMAND_BY_SCOPE = {
  global = "cd",
  tab = "tcd",
  window = "lcd",
}

---@class nvim-zoxide.QueryContext
---@field mode string list/single
---@field scope string global/tab/window
---@field query string the query string

---Default argument construction function
---@param context nvim-zoxide.QueryContext
---@return table args Arguments to run zoxide with
local function get_args(context)
  if context.mode == "list" then
    return { "query", "--list", context.query }
  else
    return { "query", context.query }
  end
end

local default_config = {
  path = "zoxide",
  define_commands = true,
}

local user_config = default_config

---@param context nvim-zoxide.QueryContext
---@param stdout string[]
local function process_result(context, stdout, cb)
  local cd_command_name = COMMAND_BY_SCOPE[context.scope]

  if context.mode == "list" and #stdout ~= 1 then
    vim.schedule(function()
      vim.ui.select(stdout, {
        prompt = string.format(":%s to...", cd_command_name),
      }, function(str, idx)
        cb(str)
      end)
    end)
  else
    assert(#stdout == 1, vim.inspect({ context, stdout }))
    cb(stdout[1])
  end
end

---Default callback to switch to directory and increment its score in zoxide.
---@param context nvim-zoxide.QueryContext Context as supplied by the user
---@param directory string Directory selected by the user
function M.cd(context, directory)
  if directory ~= nil then
    local cmd = COMMAND_BY_SCOPE[context.scope]
    M.increment(directory)
    vim.cmd(string.format("%s %s", cmd, directory))
  end
end

---Increments the directory through `zoxide increment`
---@param dir string
function M.increment(dir)
  ---@diagnostic disable-next-line(missing-fields)
  Job:new({
    command = user_config.path,
    args = { "add", dir },
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        vim.notify(
          "Zoxide failed to increment dir: " .. table.concat(j:stderr_result()),
          vim.log.levels.WARN
        )
      end
    end,
  }):start()
end

---Default argument construction function
---@param context nvim-zoxide.QueryContext
---@param callback fun(nvim-zoxide.QueryContext, string)|nil Callback to be
---       called with the selected directory. nvim-zoxide.cd is used if not
---       provided; second param will be nil if an error occured
function M.zoxide(context, callback)
  if callback == nil then
    callback = M.cd
  end
  ---@diagnostic disable-next-line(missing-fields)
  local job = Job:new({
    command = user_config.path,
    args = get_args(context),
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        vim.notify("Zoxide failed: stderr=" .. table.concat(j:stderr_result()), vim.log.levels.WARN)
        callback(context, nil)
        return
      end
      local stdout = j:result()
      if #stdout == 0 then
        vim.notify("Zoxide failed: no matches found", vim.log.levels.WARN)
        callback(context, nil)
      else
        process_result(context, j:result(), function(dir)
          vim.schedule(function()
            callback(context, dir)
          end)
        end)
      end
    end,
  })
  job:start()
end

function M.get_config()
  return user_config
end

local function define_commands()
  for scope, suffix in pairs({ global = "", tab = "t", window = "w" }) do
    vim.api.nvim_create_user_command("Z" .. suffix, function(cmd)
      local query = cmd.args
      local mode = cmd.bang and "single" or "list"
      M.zoxide({ query = query, mode = mode, scope = scope }, M.cd)
    end, {
      nargs = "+",
      bang = true,
    })
  end
end

function M.setup(config)
  user_config = vim.tbl_deep_extend("keep", config or {}, default_config)
  if user_config.define_commands then
    define_commands()
  end
end

return M
