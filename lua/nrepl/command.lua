---@diagnostic disable-next-line: unused-local
local function filter_completion_pred(arg_lead, cmd_line, cursor_pos)
  return function(value) return string.sub(value, 1, string.len(arg_lead)) == arg_lead end
end

vim.api.nvim_create_user_command("NreplOp", function(info)
  local client = require("nrepl.state").data.client
  local util = require("nrepl.util")
  if client == nil then
    util.notify("No client connected", vim.log.levels.WARN)
    return
  end

  local fargs = info.fargs
  local op = fargs[1]

  local request = {
    op = op,
  }

  local args = vim.list_slice(fargs, 2)
  for _, arg in ipairs(args) do
    local n = string.find(arg, "=", 2, true)
    local key = string.sub(arg, 0, n - 1)
    local value = string.sub(arg, n + 1)
    if key ~= "" and value ~= "" then request[key] = value end
  end

  require("nrepl.tcp").write({
    make_request = function() return request end,
    callback = function(response) require("nrepl.util").echo("nREPL Response", response) end,
  })
end, {
  nargs = "+",
  complete = function(arg_lead, cmd_line, cursor_pos)
    local util = require("nrepl.util")
    local ops = require("nrepl.state").data.server.ops
    return vim
      .iter(ops)
      :map(function(key, value)
        if
          value.requires == nil
          or vim.tbl_isempty(value.requires)
          or (vim.tbl_count(value.requires) == 1 and value.requires.session)
        then
          return key
        end
      end)
      :filter(filter_completion_pred(arg_lead, cmd_line, cursor_pos))
      :totable()
  end,
})

vim.api.nvim_create_user_command("NreplWrite", function(info)
  local client = require("nrepl.state").data.client
  local util = require("nrepl.util")
  if client == nil then
    util.notify("No client connected", vim.log.levels.WARN)
    return
  end

  local args = info.args
  local request = vim.fn.eval(args)
  require("nrepl.tcp").write({
    make_request = function() return request end,
    callback = function(response) require("nrepl.util").echo("nREPL Response", response) end,
  })
end, {
  nargs = 1,
  complete = "expression",
})

local action = require("nrepl.action")
vim.api.nvim_create_user_command("Nrepl", function(info)
  local fargs = info.fargs
  local key = table.remove(fargs, 1)
  action[key](unpack(fargs))
end, {
  nargs = "+",
  complete = function(arg_lead, cmd_line, cursor_pos)
    local util = require("nrepl.util")
    local server = require("nrepl.state").data.server
    local _, arg_n = string.gsub(string.sub(cmd_line, 1, cursor_pos), " ", "")
    if arg_n == 1 then
      return vim
        .iter(action)
        :map(function(key, _) return key end)
        :filter(filter_completion_pred(arg_lead, cmd_line, cursor_pos))
        :totable()
    elseif arg_n == 2 and server then
      local act = vim.split(cmd_line, " ", { plain = true })[2]
      if vim.list_contains({ "session_select", "session_clone", "session_close" }, act) then
        return vim
          .iter(server.sessions)
          :map(function(key, _) return key end)
          :filter(filter_completion_pred(arg_lead, cmd_line, cursor_pos))
          :totable()
      end
    end
  end,
})
