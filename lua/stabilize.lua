local M = {}
local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local schedule = vim.schedule
local npcall = vim.F.npcall
local cfg = { force = true, forcemark = nil, ignore = { filetype = { "help", "list", "Trouble" }, buftype = { "terminal", "quickfix", "loclist" } } }
local windows = {}
windows[api.nvim_get_current_win()] = { topline = 1, cursor = api.nvim_win_get_cursor(0) }

function M.save_window()
	local win = windows[api.nvim_get_current_win()]
	if win then
		win.topline = tonumber(fn.line("w0"))
		if win.forcecursor and win.force then
			win.cursor = win.forcecursor
			win.force = false
		else
			win.cursor = api.nvim_win_get_cursor(0)
			win.forcecursor = nil
		end
	end
end

function M.restore_windows()
	local ignored = api.nvim_get_option("eventignore")
	api.nvim_set_option("eventignore", "CursorMoved,CursorMovedI,WinClosed,WinNew")
	schedule(function()
		local select = api.nvim_get_mode().mode == "s"
		local curwin = api.nvim_get_current_win()
		for win, winstate in pairs(windows) do
			api.nvim_set_current_win(win)
			fn.winrestview({ topline = winstate.topline })
			local lastline = tonumber(fn.line('w$'))
			if winstate.forcecursor then
				api.nvim_win_set_cursor(0, { winstate.forcecursor[1], winstate.forcecursor[2] + (select and 1 or 0) })
				winstate.forcecursor = nil
			elseif cfg.force and lastline and winstate.cursor[1] > lastline then
				if cfg.forcemark then vim.fn.setpos("'" .. cfg.forcemark, vim.fn.getcurpos()) end
				api.nvim_win_set_cursor(0, { lastline, winstate.cursor[2] + (select and 1 or 0) })
				winstate.forcecursor = winstate.cursor
				winstate.force = true
			else
				api.nvim_win_set_cursor(0, { winstate.cursor[1], winstate.cursor[2] + (select and 1 or 0) })
			end
		end
		api.nvim_set_current_win(curwin)
		api.nvim_set_option("eventignore", ignored)
	end)
end

function M.handle_new()
	schedule(function()
		local ft = api.nvim_buf_get_option(0, "filetype")
		local bt = api.nvim_buf_get_option(0, "buftype")
		if not (npcall(api.nvim_win_get_var, 0, "previewwindow") or vim.tbl_contains(cfg.ignore.filetype, ft) or
				vim.tbl_contains(cfg.ignore.buftype, bt)) then
			local win = api.nvim_get_current_win()
			if not windows[win] then windows[win] = { topline = tonumber(fn.line("w0")), cursor = api.nvim_win_get_cursor(0) } end
		end
	end)
	if api.nvim_win_get_config(0).relative == "" then M.restore_windows() end
end

function M.handle_closed(win)
	windows[win] = nil
	if api.nvim_win_get_config(win).relative == "" then M.restore_windows() end
end

function M.setup(setup_cfg)
	if setup_cfg then cfg = vim.tbl_deep_extend("force", cfg, setup_cfg) end
	cmd [[
	augroup Stabilize
		autocmd!
		autocmd WinNew * :lua require('stabilize').handle_new()
		autocmd WinClosed * :lua require('stabilize').handle_closed(tonumber(vim.fn.expand("<afile>")))
		autocmd CursorMoved,CursorMovedI * :lua require('stabilize').save_window()
		autocmd User StabilizeRestore :lua require('stabilize').restore_windows()
	augroup END
	]]
end

return M
