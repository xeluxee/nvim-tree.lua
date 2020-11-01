local a = vim.api

local M = {}

M.config = {
  name = "NvimTree",
}

M.windows = {}

local function is_open()
  local tabpage = a.nvim_get_current_tabpage()
  local window = M.windows[tabpage]

  local success, b = pcall(a.nvim_win_get_buf, window)
  if not success then
    M.windows[tabpage] = nil
  end

  if not a.nvim_buf_get_name(b):match(M.config.name..'$') then
    M.windows[tabpage] = nil
  end

  return M.windows[tabpage] ~= nil
end

local function bind(buf, left, right, opts)
  a.nvim_buf_set_keymap(buf, "n", left, right, opts or { silent = true })
end

function M.open()
  if is_open() then return end

  local side = M.config.side == 'left' and 'topleft' or 'botright'
  vim.cmd(string.format("%s vsplit | vert resize %s", side, M.config.width))

  local win = a.nvim_get_current_win()
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].wrap = false

  local bufnr
  local ret = ''
  if vim.fn.bufexists(M.config.name) ~= 0 then
    bufnr = vim.fn.bufnr(M.config.name)
  else
    bufnr = a.nvim_create_buf(false, true)
    a.nvim_buf_set_name(bufnr, M.config.name)
    vim.bo[bufnr].filetype = M.config.name
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].swapfile = false

    for left, right in pairs(M.config.keybindings) do
      bind(bufnr, left, right)
    end

    ret = 'norestore'
  end

  a.nvim_win_set_buf(win, bufnr)
  M.windows[a.nvim_get_current_tabpage()] = win
  return ret
end

function M.close()
  if not is_open() then return end
  if #a.nvim_list_wins() == 1 then
    vim.cmd "q!"
  else
    local tabpage = a.nvim_get_current_tabpage()
    a.nvim_win_close(M.windows[tabpage], true)
    M.windows[tabpage] = nil
  end
end

function M.resize(with_replace)
  if not is_open() then return end

  local tabpage = a.nvim_get_current_tabpage()
  local treewin = M.windows[tabpage]

  if with_replace then
    local wincmd = M.config.side == 'left' and 'wincmd H' or 'wincmd L'
    local curwin = a.nvim_get_current_win()
    a.nvim_set_current_win(treewin)
    vim.cmd(wincmd)
    a.nvim_set_current_win(curwin)
  end

  a.nvim_win_set_width(treewin, M.config.width)
end

local ns_id = a.nvim_create_namespace(M.config.name)

function M.render(lines, highlights)
  if not is_open() then return end

  local cursor = a.nvim_win_get_cursor(0)
  local bufnr = vim.fn.bufnr(M.config.name)
  vim.bo[bufnr].modifiable = true

  a.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  a.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  for _, hl in ipairs(highlights) do
    a.nvim_buf_set_extmark(bufnr, ns_id, hl.line, hl.start_col, {
      end_line = hl.line,
      end_col = hl.end_col,
      hl_group = hl.group
    })
  end

  vim.bo[bufnr].modifiable = false
  if cursor[1] <= #a.nvim_buf_get_lines(bufnr, 0, -1, true) then
    a.nvim_win_set_cursor(0, cursor)
  end
end

function M.auto_close()
  if not is_open() then return end
  local wins = a.nvim_list_wins()
  if #wins == 1 then
    vim.cmd":q!"
  end
end

function M.configure(opts)
  M.config = vim.tbl_extend("keep", opts, M.config)

  if opts.auto_close then
    vim.cmd "au! WinClosed * lua vim.defer_fn(require'nvim-tree.buffers.tree'.auto_close, 1)"
  end
end

M.is_open = is_open
return M