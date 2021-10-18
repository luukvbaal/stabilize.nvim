M = {}
local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local schedule = vim.schedule
local cfg = { force = true, ft_ignore = { "help", "list", "Trouble" } }
local windows = {}
windows[api.nvim_get_current_win()] = { topline = 1, cursor = api.nvim_win_get_cursor(0) }

local function filter_window(win, wininfo)
	local ft = api.nvim_buf_get_option(0, "filetype")
	if fn.getwinvar(win, "&previewwindow") == "1" or vim.tbl_contains(cfg.ft_ignore, ft) then return true end
	if wininfo.quickfix == 1 or wininfo.loclist == 1 or wininfo.terminal == 1 then return true end
	return false
end

function M.save_window()
	schedule(function()
		local win = api.nvim_get_current_win()
		local wininfo = fn.getwininfo(win)[1]
		if filter_window(win, wininfo) then return end
		if windows[win] then
			windows[win].topline = wininfo.topline
			windows[win].cursor = api.nvim_win_get_cursor(0)
			if windows[win].forcecursor then
				windows[win].cursor = windows[win].forcecursor
				windows[win].forcecursor = nil
			end
		end
	end)
end

local function restore_windows()
	for win, winstate in pairs(windows) do
		fn.win_execute(win, "call cursor(" .. winstate.topline .. "," .. 0 .. [[)
												 normal! zt]])
		local lastline = tonumber(fn.win_execute(win,"echo line('w$')"))
		if winstate.forcecursor then
			fn.win_execute(win, "call cursor(" .. winstate.forcecursor[1] .. "," .. winstate.forcecursor[2] + 1 .. ")")
			winstate.forcecursor = nil
		elseif lastline and winstate.cursor[1] > lastline and cfg.force then
			fn.win_execute(win, "call cursor(" .. lastline .. "," .. winstate.cursor[2] + 1 .. ")")
			winstate.forcecursor = winstate.cursor
		else
			fn.win_execute(win, "call cursor(" .. winstate.cursor[1] .. "," .. winstate.cursor[2] + 1 .. ")")
		end
	end
	cmd("doautocmd BufEnter")
end

function M.handle_new()
	schedule(function()
		local win = api.nvim_get_current_win()
		local wininfo = fn.getwininfo(win)[1]
		if not filter_window(win, wininfo) then
			if not windows[win] then windows[win] = { topline = 1, cursor = api.nvim_win_get_cursor(0) } end
		end
		restore_windows()
	end)
	schedule(function() restore_windows() end)
end

function M.handle_closed()
	schedule(function()
		local winlist = api.nvim_list_wins()
		for win, _ in pairs(windows) do
			if not vim.tbl_contains(winlist, win) then
				windows[win] = nil
				return
			end
		end
	end)
	schedule(function() restore_windows() end)
end

function M.setup(setup_cfg)
	if setup_cfg then cfg = vim.tbl_deep_extend("force", cfg, setup_cfg) end
	cmd [[
	augroup Stable
  	autocmd!
  	autocmd CursorMoved,CursorMovedI * :lua require('stabilize').save_window()
  	autocmd WinNew * :lua require('stabilize').handle_new()
		autocmd WinClosed * :lua require('stabilize').handle_closed()
	augroup END
	]]
end

return M
