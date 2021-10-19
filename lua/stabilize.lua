local M = {}
local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local schedule = vim.schedule
local npcall = vim.F.npcall
local cfg = { force = true, ignore = { filetype = { "help", "list", "Trouble" }, buftype = { "terminal", "quickfix", "loclist" } } }
local windows = {}
windows[api.nvim_get_current_win()] = { topline = 1, cursor = api.nvim_win_get_cursor(0) }

local function filter_window(win)
	local ft = api.nvim_buf_get_option(0, "filetype")
	local bt = api.nvim_buf_get_option(0, "buftype")
	return npcall(api.nvim_win_get_var, win, "previewwindow") or
		vim.tbl_contains(cfg.ignore.filetype, ft) or
		vim.tbl_contains(cfg.ignore.buftype, bt)
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
		local select = api.nvim_get_mode().mode == "s"
		local curwin = api.nvim_get_current_win()
		for win, winstate in pairs(windows) do
			api.nvim_set_current_win(win)
			fn.winrestview({ topline = winstate.topline })
			local lastline = tonumber(fn.line('w$'))
			if winstate.forcecursor then
				api.nvim_win_set_cursor(0, { winstate.forcecursor[1], winstate.forcecursor[2] + (select and 1 or 0) })
				winstate.forcecursor = nil
			elseif lastline and winstate.cursor[1] > lastline and cfg.force then
				api.nvim_win_set_cursor(0, { lastline, winstate.cursor[2] + (select and 1 or 0) })
				winstate.forcecursor = winstate.cursor
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
		local win = api.nvim_get_current_win()
		if not filter_window(0) then
			if not windows[win] then windows[win] = { topline = 1, cursor = api.nvim_win_get_cursor(0) } end
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
