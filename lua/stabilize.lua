local M = {}
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
		if windows[win] then
			windows[win].topline = tonumber(fn.line("w0"))
			if windows[win].forcecursor then
				windows[win].cursor = windows[win].forcecursor
			else
				windows[win].cursor = api.nvim_win_get_cursor(0)
				windows[win].forcecursor = nil
			end
		end
	end)
end

function M.restore_windows()
	local ignored = api.nvim_get_option("eventignore")
	api.nvim_set_option("eventignore", "CursorMoved,CursorMovedI,WinClosed,WinNew")
	schedule(function()
		local curwin = api.nvim_get_current_win()
		for win, winstate in pairs(windows) do
			api.nvim_set_current_win(win)
			api.nvim_win_set_cursor(0, { winstate.topline, 0 })
			cmd("normal! zt")
			local lastline = tonumber(fn.line('w$'))
			if winstate.forcecursor then
				api.nvim_win_set_cursor(0, { winstate.forcecursor[1], winstate.forcecursor[2] })
				winstate.forcecursor = nil
			elseif lastline and winstate.cursor[1] > lastline and cfg.force then
				api.nvim_win_set_cursor(0, { lastline, winstate.cursor[2] })
				winstate.forcecursor = winstate.cursor
			else
				api.nvim_win_set_cursor(0, { winstate.cursor[1], winstate.cursor[2] })
			end
		end
		api.nvim_set_current_win(curwin)
		api.nvim_set_option("eventignore", ignored)
	end)
end

function M.handle_new()
	schedule(function()
		local win = api.nvim_get_current_win()
		local wininfo = fn.getwininfo(win)[1]
		if not filter_window(win, wininfo) then
			if not windows[win] then windows[win] = { topline = 1, cursor = api.nvim_win_get_cursor(0) } end
		end
	end)
	M.restore_windows()
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
	M.restore_windows()
end

function M.setup(setup_cfg)
	setup_cfg = vim.tbl_deep_extend("force", cfg, setup_cfg or {})
	cmd [[
	augroup Stabilize
		autocmd!
		autocmd WinNew * :lua require('stabilize').handle_new()
		autocmd WinClosed * :lua require('stabilize').handle_closed()
		autocmd CursorMoved,CursorMovedI * :lua require('stabilize').save_window()
		autocmd User StabilizeRestore :lua require('stabilize').restore_windows()
	augroup END
	]]
end

return M
