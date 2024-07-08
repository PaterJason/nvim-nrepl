local state = require("nrepl.state")
local config = require("nrepl.config")
local M = {}

---@alias Nrepl.TSCapture
---| "ns"
---| "sym"
---| "elem"

---@class Nrepl.TSCaptureOpts
---@field start? [integer, integer]
---@field end_? [integer, integer]
---@field last? boolean

---@param capture Nrepl.TSCapture
---@param opts? Nrepl.TSCaptureOpts
---@return TSNode?
function M.get_ts_node(capture, opts)
  opts = opts or {}
  local start
  local end_
  if opts.start then
    start = opts.start
    end_ = opts.end_ or start
  end

  local filetype = state.data.filetype or ""
  local lang = vim.treesitter.language.get_lang(filetype)
  if lang == nil then return end
  local query = vim.treesitter.query.get(lang, "nrepl")
  if query == nil then return end
  local parser = vim.treesitter.get_parser(0, lang, {})
  local tree = parser:trees()[1]

  local return_node
  for id, node in query:iter_captures(tree:root(), 0, start and start[1], end_ and end_[1] + 1) do
    local name = query.captures[id]
    if name == capture then
      if
        (not start or vim.treesitter.is_in_node_range(node, start[1], start[2]))
        and (not end_ or vim.treesitter.is_in_node_range(node, end_[1], end_[2]))
      then
        if opts.last then
          return_node = node
        else
          return node
        end
      end
    end
  end
  return return_node
end

---@param capture Nrepl.TSCapture
---@param opts? Nrepl.TSCaptureOpts
---@return string?
function M.get_ts_text(capture, opts)
  local node = M.get_ts_node(capture, opts)
  if node then return vim.treesitter.get_node_text(node, 0) end
end

---@return string?
---@return string?
function M.get_cursor_ns_sym()
  local pos = vim.api.nvim_win_get_cursor(0)
  pos[1] = pos[1] - 1
  local ns = M.get_ts_text("ns")
  local sym = M.get_ts_text("sym", { start = pos })

  return ns, sym
end

---@param status string[]
---@return { is_done: boolean, is_error: boolean, status_strs: string[] }
function M.status(status)
  return vim.iter(status):fold({
    is_done = false,
    is_error = false,
    status_strs = {},
  }, function(acc, s)
    if s == "done" then
      acc.is_done = true
    elseif s == "error" then
      acc.is_error = true
    else
      table.insert(acc.status_strs, s)
    end
    return acc
  end)
end

---@param file string
---@return string
function M.file_str(file)
  file = file:gsub("^file:", "", 1):gsub("^jar:file:(.*)(!/)", "zipfile://%1::", 1)
  return file
end

---@param info any
---@return string[]
function M.doc_clj(info)
  if not info or vim.tbl_isempty(info) then return { "No doc info" } end
  local content = {}
  -- Look at clojure.repl/print-doc
  table.insert(content, "```clojure")
  table.insert(content, (info.ns and info.ns .. "/" .. info.name) or info.name)
  table.insert(content, info.arglists or info["arglists-str"])
  table.insert(content, info["forms-str"])
  table.insert(content, "```")

  table.insert(content, (info["special-form"] and "Special Form") or (info.macro and "Macro"))
  table.insert(content, info.added and "Available since " .. info.added)
  table.insert(content, info.doc and " " .. info.doc)

  if info["see-also"] then
    vim.list_extend(content, { "", "__See also:__" })
    vim.list_extend(content, info["see-also"])
  end
  if info.file then
    vim.list_extend(content, { "", "__File:__", string.format("[%s]", M.file_str(info.file)) })
  end
  return content
end

---@param info any
---@return string[]
function M.doc_java(info)
  if not info or vim.tbl_isempty(info) then return { "No doc info" } end
  local content = {}
  table.insert(content, "```clojure")
  table.insert(
    content,
    (info.modifiers and (info.modifiers .. " ") or "")
      .. (info.class and (info.class .. "/") or "")
      .. info.member
  )
  if info["annotated-arglists"] then vim.list_extend(content, info["annotated-arglists"]) end
  if info.throws and not (vim.tbl_isempty(info.throws)) then
    table.insert(content, "throw " .. table.concat(info.throws, " "))
  end
  table.insert(content, "```")

  if info.javadoc then
    vim.list_extend(content, { "__Javadoc:__", string.format("[%s]", info.javadoc) })
  end
  return content
end

---@param contents string[]
---@param filetype? string
---@param opts? vim.lsp.util.open_floating_preview.Opts
function M.open_floating_preview(contents, filetype, opts)
  filetype = filetype or ""
  opts = opts or {}
  local bufnr, _ = vim.lsp.util.open_floating_preview(
    contents,
    filetype,
    vim.tbl_extend("keep", opts, config.floating_preview)
  )

  local lang = vim.treesitter.language.get_lang(filetype)
  if lang then vim.treesitter.start(bufnr, lang) end
end

---@param callback fun(item: string?, idx: integer?)
function M.select_session(callback)
  vim.ui.select(state.data.server.sessions, {
    prompt = "Select session",
    format_item = function(item)
      local current_session = state.data.session
      if item == current_session then
        return item .. " (current)"
      else
        return item
      end
    end,
  }, function(item)
    if item then callback(item) end
  end)
end

---@param msg string
---@param level? integer
function M.notify(msg, level) vim.notify("nREPL: " .. msg, level) end

---@param title string
---@param data any
function M.echo(title, data)
  vim.api.nvim_echo({
    { title .. "\n", "Underlined" },
    { (type(data) == "string" and data) or vim.inspect(data), "Normal" },
  }, true, {})
end

local function set_virt_text(s, hl_name, request)
  if not request.line then return end

  if vim.fn.expand("%:p") ~= request.file then return end

  local ns_id = vim.api.nvim_create_namespace("nrepl_eval")
  -- hacky
  local request_id = tonumber(string.sub(request.id, 6))
  ---@cast request_id integer
  local extmark = vim.api.nvim_buf_get_extmark_by_id(0, ns_id, request_id, {})

  if vim.tbl_isempty(extmark) then
    vim.api.nvim_buf_clear_namespace(0, ns_id, request.line - 1, request.line)
    vim.api.nvim_buf_set_extmark(0, ns_id, request.line - 1, request.column - 1, {
      id = request_id,
      virt_text = {
        { "=> " .. string.gsub(s, "%s+", " "), vim.api.nvim_get_hl_id_by_name(hl_name) },
      },
      priority = 175,
      invalidate = true,
      undo_restore = false,
    })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      callback = function() vim.api.nvim_buf_del_extmark(0, ns_id, request_id) end,
      buffer = 0,
      once = true,
    })
  end
end

M.callback = {}

---@type Nrepl.Message.Callback
function M.callback.status(response, request)
  local status = response.status and M.status(response.status) or {}

  if status.is_done then
    if vim.tbl_isempty(status.status_strs) then
      require("nrepl.prompt").append("", {
        new_line = true,
      })
    else
      local s = request.op
        .. (status.is_error and " error: " or ": ")
        .. table.concat(status.status_strs, ", ")
      require("nrepl.prompt").append(s, {
        new_line = true,
        prefix = "done",
      })
    end
  end
end

---@type Nrepl.Message.Callback
function M.callback.eval(response, request)
  local prompt = require("nrepl.prompt")

  if response.status then
    M.callback.status(response, request)
  elseif response.out then
    prompt.append(response.out, { prefix = "out" })
  elseif response.err then
    prompt.append(response.err, { prefix = "err" })
  -- set_virt_text(response.err, "DiagnosticVirtualTextError", request)
  elseif response.value then
    prompt.append(response.value, {})
    -- set_virt_text(response.value, "DiagnosticVirtualTextOk", request)
  end
end

return M
