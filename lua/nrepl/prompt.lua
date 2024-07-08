local state = require("nrepl.state")

local M = {}

local augroup = vim.api.nvim_create_augroup("nrepl_prompt", { clear = true })

---@return integer
function M.get_buf()
  local buf = vim.uri_to_bufnr("nrepl://prompt")
  if not vim.api.nvim_buf_is_loaded(buf) then
    vim.bo[buf].buftype = "prompt"

    vim.fn.prompt_setprompt(buf, "=> ")
    vim.fn.prompt_setcallback(buf, "v:lua.require'nrepl.tcp'.message.eval_text")
    vim.fn.prompt_setinterrupt(buf, "v:lua.require'nrepl.tcp'.message.interrupt")
    vim.bo[buf].filetype = state.data.filetype

    vim.api.nvim_create_autocmd({ "BufEnter" }, {
      group = augroup,
      buffer = buf,
      callback = function()
        vim.bo[buf].filetype = state.data.filetype
        vim.bo[buf].omnifunc = "v:lua.require'nrepl'.completefunc"
      end,
    })
  end
  return buf
end

---@return integer[]
function M.get_wins()
  local buf = vim.uri_to_bufnr("nrepl://prompt")
  return vim.fn.win_findbuf(buf)
end

---@param enter boolean
---@param config vim.api.keyset.win_config
---@return integer
function M.open_win(enter, config)
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
  }
  win_config = vim.tbl_extend("force", win_config, config)
  local win = vim.api.nvim_open_win(M.get_buf(), enter, win_config)
  vim.wo[win].wrap = false
  return win
end

---@return integer?
function M.open_float()
  local wins = M.get_wins()
  local tabpage = vim.api.nvim_get_current_tabpage()
  if vim.iter(wins):find(function(win) return vim.api.nvim_win_get_tabpage(win) == tabpage end) then
    return
  end

  ---@type vim.api.keyset.win_config
  local screencol = vim.fn.screencol()
  local columns = vim.go.columns
  local lines = vim.go.lines
  local win_config = {
    relative = "editor",
    row = 0,
    col = (screencol <= columns / 2) and columns or 0,
    width = math.min(columns / 2, 80),
    height = math.min(lines - 4, 24),
    style = "minimal",
    focusable = false,
    border = "single",
    title = "nREPL",
    title_pos = "center",
  }
  local win = M.open_win(false, win_config)
  vim.api.nvim_create_autocmd("CursorMoved", {
    callback = function() vim.api.nvim_win_close(win, false) end,
    once = true,
  })
  return win
end

---@param s string
---@param opts { new_line?: boolean, prefix?: string }
function M.append(s, opts)
  local buf = M.get_buf()
  local pre_line_count = vim.api.nvim_buf_line_count(buf)

  local text = vim.split(s, "\n", { plain = true })
  local prefix = opts.prefix and string.format("; (%s) ", opts.prefix)
  local prefixed_text = {}
  for index, value in ipairs(text) do
    if not prefix or value == "" then
      prefixed_text[index] = value
    else
      prefixed_text[index] = prefix .. value
    end
  end

  -- Append buffer
  local linenr = -1
  if vim.api.nvim_win_get_buf(0) == buf and vim.startswith(vim.api.nvim_get_mode().mode, "i") then
    linenr = -2
  end
  local line = vim.api.nvim_buf_get_lines(buf, linenr - 1, linenr, false)[1]
  if opts.new_line and ((s == "" and line ~= "") or text[#text] ~= "") then
    table.insert(prefixed_text, "")
  end
  local prompt = vim.fn.prompt_getprompt(buf)

  if line == "" then
    vim.api.nvim_buf_set_text(buf, linenr, -1, linenr, -1, prefixed_text)
  elseif
    (not vim.startswith(line, prompt))
    and (
      (prefix and vim.startswith(line, prefix)) or (not prefix and not vim.startswith(line, "; "))
    )
  then
    prefixed_text[1] = text[1]
    vim.api.nvim_buf_set_text(buf, linenr, -1, linenr, -1, prefixed_text)
  else
    vim.api.nvim_buf_set_lines(buf, linenr, linenr, true, prefixed_text)
  end
  vim.bo[buf].modified = false

  -- Scroll window
  local line_count = vim.api.nvim_buf_line_count(buf)
  for _, winnr in ipairs(vim.fn.win_findbuf(buf)) do
    if
      vim.api.nvim_win_get_config(winnr).relative == ""
      and vim.api.nvim_win_get_cursor(winnr)[1] == pre_line_count
    then
      vim.api.nvim_win_set_cursor(winnr, { line_count, 0 })
    end
  end

  local float_winnr = M.open_float()
  if float_winnr then
    vim.api.nvim_win_call(float_winnr, function()
      vim.api.nvim_win_set_cursor(0, { pre_line_count, 0 })
      vim.cmd("normal! zt")
    end)
  end
end

return M
