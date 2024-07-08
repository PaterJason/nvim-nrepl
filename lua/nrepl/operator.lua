local prompt = require("nrepl.prompt")
local state = require("nrepl.state")
local tcp = require("nrepl.tcp")

local message = tcp.message

local M = {}

---Get range of the operator (zero-based, end col exclusive)
---@param motion_type "line"|"char"|"block"
---@return [integer, integer]
---@return [integer, integer]
local function get_operator_range(motion_type)
  local start = vim.api.nvim_buf_get_mark(0, "[")
  local end_ = vim.api.nvim_buf_get_mark(0, "]")
  start[1] = start[1] - 1
  end_[1] = end_[1] - 1
  end_[2] = end_[2] + 1

  if motion_type == "line" then
    start[2] = 0
    end_[2] = -1
  end

  return start, end_
end

function M.eval(motion_type)
  local start, end_ = get_operator_range(motion_type)
  message.eval_range(start, end_)
end

return M
