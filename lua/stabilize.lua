local M = {}
local api = vim.api
local fn = vim.fn
local schedule = vim.schedule
local cfg = { force = true, forcemark = nil, ignore = { filetype = { "help", "list", "Trouble" }, buftype = { "terminal", "quickfix", "loclist" } } }
local windows = {}
local numwins = #api.nvim_tabpage_list_wins(0)
local ignore = false

function M.save_window()
	if ignore then return end
	local win = windows[api.nvim_get_current_win()]
	if not win then return end
	win.topline = fn.line("w0")
	win.buffer = api.nvim_get_current_buf()
	if win.forcecursor and win.force then
		win.cursor = win.forcecursor
		win.force = false
	else
		win.cursor = api.nvim_win_get_cursor(0)
		win.forcecursor = nil
	end
end

local function restore_window(win, winstate)
if not api.nvim_win_is_valid(win) then
	windows[win] = nil
	return
end

if winstate.tab ~= api.nvim_get_current_tabpage() then return end

api.nvim_win_call(win, function()
	if winstate.buffer ~= api.nvim_get_current_buf() then return end
	fn.winrestview({ topline = winstate.topline })
	if api.nvim_get_mode().mode ~= "i" then
		local lastline = fn.line("w$")
		if winstate.forcecursor and winstate.forcecursor[1] < fn.line("$") then
			api.nvim_win_set_cursor(0, { winstate.forcecursor[1], winstate.forcecursor[2] })
			winstate.forcecursor = nil
		elseif cfg.force and winstate.cursor[1] > lastline then
			if cfg.forcemark then api.nvim_buf_set_mark(0, "'", winstate.cursor[1], winstate.cursor[2], {}) end
			api.nvim_win_set_cursor(0, { lastline, winstate.cursor[2] })
			winstate.forcecursor = winstate.cursor
			winstate.force = true
		else
			api.nvim_win_set_cursor(0, { winstate.cursor[1], winstate.cursor[2] })
		end
	end
end)
end

function M.restore_windows()
	ignore = true
	schedule(function()
		local curwins = #api.nvim_tabpage_list_wins(0)
		if curwins == numwins then
			ignore = false
			return
		end
		numwins = curwins
		for win, winstate in pairs(windows) do
			restore_window(win, winstate)
		end
		ignore = false
	end)
end

local function add_win(win)
	if windows[win] or vim.tbl_contains(cfg.ignore.filetype, api.nvim_buf_get_option(0, "filetype")) or
		vim.tbl_contains(cfg.ignore.buftype, api.nvim_buf_get_option(0, "buftype")) or
		vim.F.npcall(api.nvim_win_get_var, 0, "previewwindow") then return end
	windows[win] = {
		topline = fn.line("w0"),
		cursor = api.nvim_win_get_cursor(0),
		buffer = api.nvim_get_current_buf(),
		tab = api.nvim_get_current_tabpage()
	}
end

function M.handle_new()
	schedule(function() add_win(api.nvim_get_current_win()) end)
	M.restore_windows()
end

function M.handle_closed(win)
	windows[win] = nil
	if not api.nvim_win_get_config(win).zindex then M.restore_windows() end
end

function M.setup(setup_cfg)
	if setup_cfg then cfg = vim.tbl_deep_extend("force", cfg, setup_cfg) end
	for _, win in ipairs(api.nvim_list_wins()) do
		api.nvim_win_call(win, function() add_win(win) end)
	end
	local group = api.nvim_create_augroup("Stabilize", { clear = true })
	api.nvim_create_autocmd("WinNew", { group = group, callback = function()
		require("stabilize").handle_new()
	end})
	api.nvim_create_autocmd("WinClosed", { group = group, callback = function()
		require("stabilize").handle_closed(tonumber(vim.fn.expand("<afile>")))
	end})
	api.nvim_create_autocmd({ "BufWinEnter", "CursorMoved", "CursorMovedI" }, { group = group, callback = function()
		require("stabilize").save_window()
	end})
	api.nvim_create_autocmd("User", { group = group, pattern = "StabilizeRestore", callback = function()
		require("stabilize").restore_windows()
	end})

	if cfg.nested then
		api.nvim_create_autocmd(cfg.nested, { group = group, callback = function()
			api.nvim_exec_autocmds("User", { pattern = "StabilizeRestore" })
		end})
	end
end

return M
