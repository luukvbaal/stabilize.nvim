local M = {}
local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local schedule = vim.schedule
local cfg = { force = true, forcemark = nil, ignore = { filetype = { "help", "list", "Trouble" }, buftype = { "terminal", "quickfix", "loclist" } } }
local windows = {}
local numwins = #api.nvim_tabpage_list_wins(0)

function M.save_window()
	local win = windows[api.nvim_get_current_win()]
	if not win then return end
	win.topline = tonumber(fn.line("w0"))
	if win.forcecursor and win.force then
		win.cursor = win.forcecursor
		win.force = false
	else
		win.cursor = api.nvim_win_get_cursor(0)
		win.forcecursor = nil
	end
end

function M.restore_windows()
	local ignored = api.nvim_get_option("eventignore")
	api.nvim_set_option("eventignore", "CursorMoved,CursorMovedI,WinClosed,WinNew")
	schedule(function()
		if #api.nvim_tabpage_list_wins(0) == numwins then
			api.nvim_set_option("eventignore", ignored)
			return
		end
		numwins = #api.nvim_tabpage_list_wins(0)
		local curwin = api.nvim_get_current_win()
		for win, winstate in pairs(windows) do
			if not api.nvim_win_is_valid(win) then
				windows[win] = nil
			else
				api.nvim_set_current_win(win)
				fn.winrestview({ topline = winstate.topline })
				if api.nvim_get_mode().mode ~= "i" then
					local lastline = tonumber(fn.line('w$'))
					if winstate.forcecursor then
						api.nvim_win_set_cursor(0, { winstate.forcecursor[1], winstate.forcecursor[2] })
						winstate.forcecursor = nil
					elseif cfg.force and lastline and winstate.cursor[1] > lastline then
						if cfg.forcemark then vim.fn.setpos("'" .. cfg.forcemark, vim.fn.getcurpos()) end
						api.nvim_win_set_cursor(0, { lastline, winstate.cursor[2] })
						winstate.forcecursor = winstate.cursor
						winstate.force = true
					else
						api.nvim_win_set_cursor(0, { winstate.cursor[1], winstate.cursor[2] })
					end
				end
			end
		end
		api.nvim_set_current_win(curwin)
		api.nvim_set_option("eventignore", ignored)
	end)
end

local function add_win()
	if vim.tbl_contains(cfg.ignore.filetype, api.nvim_buf_get_option(0, "filetype")) or
		vim.tbl_contains(cfg.ignore.buftype, api.nvim_buf_get_option(0, "buftype")) or
		vim.F.npcall(api.nvim_win_get_var, 0, "previewwindow") then return end
    local win = api.nvim_get_current_win()
    if not windows[win] then windows[win] = { topline = tonumber(fn.line("w0")), cursor = api.nvim_win_get_cursor(0) } end
end

function M.handle_new()
	schedule(function() add_win() end)
	if api.nvim_win_get_config(0).relative == "" then M.restore_windows() end
end

function M.handle_closed(win)
	windows[win] = nil
	if api.nvim_win_get_config(win).relative == "" then M.restore_windows() end
end

function M.setup(setup_cfg)
	if setup_cfg then cfg = vim.tbl_deep_extend("force", cfg, setup_cfg) end
	for _, win in ipairs(api.nvim_list_wins()) do
		api.nvim_set_current_win(win)
		add_win()
	end
	cmd[[
	augroup Stabilize
		autocmd!
		autocmd WinNew * lua require('stabilize').handle_new()
		autocmd WinClosed * lua require('stabilize').handle_closed(tonumber(vim.fn.expand("<afile>")))
		autocmd CursorMoved,CursorMovedI * lua require('stabilize').save_window()
		autocmd User StabilizeRestore lua require('stabilize').restore_windows()
	]]
	if cfg.nested then
		vim.cmd("autocmd "..cfg.nested.." doautocmd User StabilizeRestore")
	end
	vim.cmd("augroup END")
end

return M
