local M = {}

function M.init()
  require("nrepl.command")
  require("nrepl.mappings")
  if vim.tbl_isempty(require("nrepl.state").data.server) then require("nrepl.action").connect() end
end

function M.setup() end

function M.completefunc(...) return require("nrepl.completion").completefunc(...) end

function M.command_completion_customlist(...)
  return require("nrepl.completion").command_customlist(...)
end

return M
