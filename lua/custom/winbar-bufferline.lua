-- [J] Per-window bufferline rendered in the winbar
-- require('custom.winbar-bufferline').enable() to activate.

local M = {}

local win_bufs = {}
local last_winbar = {}
local redraw_scheduled = false

local excluded_ft = { ['neo-tree'] = true, TelescopePrompt = true, qf = true }

local function list_index(tbl, val)
  for i, v in ipairs(tbl) do
    if v == val then return i end
  end
end

local function is_real_buf(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr)
    and vim.bo[bufnr].buflisted
    and vim.bo[bufnr].buftype == ''
    and vim.api.nvim_buf_get_name(bufnr) ~= ''
end

local function is_real_win(win)
  if not vim.api.nvim_win_is_valid(win) then return false end
  local buf = vim.api.nvim_win_get_buf(win)
  return not excluded_ft[vim.bo[buf].filetype]
end

local function sorted_real_wins()
  local wins = vim.tbl_filter(is_real_win, vim.api.nvim_list_wins())
  table.sort(wins, function(a, b)
    return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
  end)
  return wins
end

local function add_buf_to_win(win, bufnr)
  if not is_real_buf(bufnr) or not is_real_win(win) then return end
  win_bufs[win] = win_bufs[win] or {}
  if list_index(win_bufs[win], bufnr) then return end
  table.insert(win_bufs[win], bufnr)
end

local function remove_buf_from_all_wins(bufnr)
  for _, bufs in pairs(win_bufs) do
    local i = list_index(bufs, bufnr)
    if i then table.remove(bufs, i) end
  end
end

local function cleanup_closed_wins()
  for win, _ in pairs(win_bufs) do
    if not vim.api.nvim_win_is_valid(win) then
      win_bufs[win] = nil
      last_winbar[win] = nil
    end
  end
end

local function get_unique_names(bufs)
  local names = {}
  local full_paths = {}
  local count = {}
  for _, bufnr in ipairs(bufs) do
    local full = vim.api.nvim_buf_get_name(bufnr)
    full_paths[bufnr] = full
    local short = full ~= '' and vim.fn.fnamemodify(full, ':t') or '[No Name]'
    names[bufnr] = short
    count[short] = (count[short] or 0) + 1
  end
  for _, bufnr in ipairs(bufs) do
    if count[names[bufnr]] > 1 then
      names[bufnr] = vim.fn.fnamemodify(full_paths[bufnr], ':p:h:t') .. '/' .. names[bufnr]
    end
  end
  return names
end

local function render_winbar(win, focused_win)
  if not is_real_win(win) then return '' end
  local bufs = vim.tbl_filter(is_real_buf, win_bufs[win] or {})
  win_bufs[win] = bufs

  if #bufs == 0 then return '' end

  local current_buf = vim.api.nvim_win_get_buf(win)
  local is_focused = (win == focused_win)
  local names = get_unique_names(bufs)
  local parts = {}

  for _, bufnr in ipairs(bufs) do
    local hl
    if bufnr == current_buf then
      hl = is_focused and 'WinBarBufActiveFocused' or 'WinBarBufActive'
    else
      hl = 'WinBarBufInactive'
    end
    local modified = vim.bo[bufnr].modified and ' ●' or ''
    table.insert(parts, '%#' .. hl .. '# ' .. names[bufnr] .. modified .. ' %*')
  end

  return table.concat(parts, '%#WinBarBufSep#│%*')
end

local function schedule_redraw()
  if redraw_scheduled then return end
  redraw_scheduled = true
  vim.schedule(function()
    redraw_scheduled = false
    local focused_win = vim.api.nvim_get_current_win()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if is_real_win(win) then
        local ok, bar = pcall(render_winbar, win, focused_win)
        if ok and bar ~= last_winbar[win] then
          vim.wo[win].winbar = bar
          last_winbar[win] = bar
        end
      else
        if last_winbar[win] ~= '' then
          vim.wo[win].winbar = ''
          last_winbar[win] = ''
        end
      end
    end
  end)
end

-- Global jumplist: tracks {win, buf, row, col} across all windows
local jump_stack = {}
local jump_idx = 0
local max_jumps = 100
local tracking_jumps = true

local function record_jump()
  if not tracking_jumps then return end
  local win = vim.api.nvim_get_current_win()
  if not is_real_win(win) then return end
  local buf = vim.api.nvim_get_current_buf()
  if not is_real_buf(buf) then return end
  local pos = vim.api.nvim_win_get_cursor(win)

  if jump_idx > 0 then
    local prev = jump_stack[jump_idx]
    if prev and prev.buf == buf and prev.row == pos[1] and prev.win == win then
      return
    end
  end

  jump_idx = jump_idx + 1
  for i = jump_idx + 1, #jump_stack do
    jump_stack[i] = nil
  end
  jump_stack[jump_idx] = { win = win, buf = buf, row = pos[1], col = pos[2] }

  if #jump_stack > max_jumps then
    table.remove(jump_stack, 1)
    jump_idx = jump_idx - 1
  end
end

local function set_highlights()
  local normal = vim.api.nvim_get_hl(0, { name = 'Normal' })
  local bg = normal.bg and string.format('#%06x', normal.bg) or '#1a1b26'

  vim.api.nvim_set_hl(0, 'WinBarBufActiveFocused', { fg = '#c0caf5', bg = '#7aa2f7', bold = true })
  vim.api.nvim_set_hl(0, 'WinBarBufActive', { fg = '#c0caf5', bg = '#3b4261', bold = true })
  vim.api.nvim_set_hl(0, 'WinBarBufInactive', { fg = '#565f89', bg = bg })
  vim.api.nvim_set_hl(0, 'WinBarBufSep', { fg = '#3b4261', bg = bg })
end

function M.enable()
  set_highlights()

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('j-winbar-colors', { clear = true }),
    callback = set_highlights,
  })

  local group = vim.api.nvim_create_augroup('j-winbar-bufferline', { clear = true })

  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = group,
    callback = function(args)
      local win = vim.api.nvim_get_current_win()
      add_buf_to_win(win, args.buf)
    end,
  })

  vim.api.nvim_create_autocmd('WinNew', {
    group = group,
    callback = function()
      vim.schedule(function()
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_win_get_buf(win)
        add_buf_to_win(win, buf)
      end)
    end,
  })

  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    callback = function(args)
      remove_buf_from_all_wins(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    callback = function()
      vim.schedule(cleanup_closed_wins)
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'BufModifiedSet', 'WinEnter', 'BufDelete' }, {
    group = group,
    callback = schedule_redraw,
  })

  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter' }, {
    group = group,
    callback = record_jump,
  })
end

function M.get_bufs(win)
  win = win or vim.api.nvim_get_current_win()
  return vim.tbl_filter(is_real_buf, win_bufs[win] or {})
end

function M.cycle(direction)
  local win = vim.api.nvim_get_current_win()
  local bufs = M.get_bufs(win)
  if #bufs <= 1 then return end

  local current = vim.api.nvim_get_current_buf()
  local idx = list_index(bufs, current)
  if not idx then return end

  local next_idx = ((idx - 1 + direction) % #bufs) + 1
  vim.api.nvim_set_current_buf(bufs[next_idx])
end

function M.close_buf()
  local win = vim.api.nvim_get_current_win()
  local bufs = M.get_bufs(win)
  local current = vim.api.nvim_get_current_buf()

  if #bufs <= 1 then
    local wins = vim.tbl_filter(is_real_win, vim.api.nvim_list_wins())
    if #wins > 1 then
      vim.api.nvim_win_close(win, false)
    end
    return
  end

  local idx = list_index(bufs, current)
  local next_idx = idx and (idx < #bufs and idx + 1 or idx - 1) or 1
  vim.api.nvim_win_set_buf(win, bufs[next_idx])

  local wbufs = win_bufs[win]
  if wbufs then
    local i = list_index(wbufs, current)
    if i then table.remove(wbufs, i) end
  end

  local in_other_win = false
  for w, wbs in pairs(win_bufs) do
    if w ~= win and list_index(wbs, current) then
      in_other_win = true
      break
    end
  end
  if not in_other_win then
    require('mini.bufremove').delete(current)
  end
end

local function jump_to(target_idx)
  local entry = jump_stack[target_idx]
  if not entry then return false end
  if not vim.api.nvim_buf_is_valid(entry.buf) then return false end

  local win = entry.win
  if not vim.api.nvim_win_is_valid(win) or not is_real_win(win) then
    win = vim.api.nvim_get_current_win()
  end

  tracking_jumps = false
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_buf(win, entry.buf)
  add_buf_to_win(win, entry.buf)
  pcall(vim.api.nvim_win_set_cursor, win, { entry.row, entry.col })
  tracking_jumps = true
  return true
end

local function jump(step)
  local target = jump_idx + step
  local bound = step > 0 and #jump_stack or 1
  while (step > 0 and target <= bound) or (step < 0 and target >= bound) do
    if jump_to(target) then
      jump_idx = target
      return
    end
    target = target + step
  end
end

function M.jump_back() jump(-1) end
function M.jump_forward() jump(1) end

-- Session persistence keyed by window column position (left=1, right=2)

function M.save()
  local data = {}
  for i, win in ipairs(sorted_real_wins()) do
    local bufs = vim.tbl_filter(is_real_buf, win_bufs[win] or {})
    local paths = {}
    for _, bufnr in ipairs(bufs) do
      table.insert(paths, vim.api.nvim_buf_get_name(bufnr))
    end
    data[i] = paths
  end
  vim.g.WinbarBufData = vim.fn.json_encode(data)
end

function M.restore()
  local raw = vim.g.WinbarBufData
  if not raw then return end
  local ok, data = pcall(vim.fn.json_decode, raw)
  if not ok or type(data) ~= 'table' then return end

  for i, win in ipairs(sorted_real_wins()) do
    local paths = data[tostring(i)] or data[i] or {}
    win_bufs[win] = {}
    for _, path in ipairs(paths) do
      local bufnr = vim.fn.bufnr(path)
      if bufnr == -1 then
        bufnr = vim.fn.bufadd(path)
        vim.bo[bufnr].buflisted = true
      end
      if is_real_buf(bufnr) then
        table.insert(win_bufs[win], bufnr)
      end
    end
  end
end

return M
