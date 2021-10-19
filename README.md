# stabilize.nvim
Neovim plugin to stabilize buffer content on window open/close events.
## Demo
See example comparing default behavior and with stabilize.nvim active:
![img](https://i.imgur.com/Tvu4xVR.gif)
## Install
Install with [vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'luukvbaal/stabilize.nvim'
call plug#end()

lua << EOF
require("stabilize").setup()
EOF
```
Install with [packer](https://github.com/wbthomason/packer.nvim):
```lua
use {
	"luukvbaal/stabilize.nvim",
	config = function() require("stabilize").setup() end
}
```
## Usage
The plugin will stabilize your buffer content on window open/close events after calling `require("stabilize").setup()`.
## Configuration
### Default options
```lua
{
  force = true, -- stabilize window even when current cursor position will be hidden behind new window
	ignore = {  -- do not manage windows matching these file/buftypes
	filetype = { "help", "list", "Trouble" },
	buftype = { "terminal", "quickfix", "loclist" }
	}
}
```
## Note
Some window events triggered by autocommands seem to mess up the window stabilization. A user command `User StabilizeRestore` is provided to restore the windows after such events (requiring manual configuration). For example opening the quickfix list after running a QuickFixCmd(i.e. `vimgrep`) will not be stable without manually triggering `StabilizeRestore`:
```vim
autocmd QuickFixCmdPost [^l]* copen | doautocmd User StabilizeRestore
autocmd QuickFixCmdPost l* lopen | doautocmd User StabilizeRestore
```
The same same `QuickFixCmdPost` autocommand for [trouble.nvim](https://github.com/folke/trouble.nvim):
```vim
lua << EOF
function _G.TroubleQuickFixPost(mode)
	require("trouble.providers").get(vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf(), function(items)
		if #items > 0 then require("trouble").open({mode = mode}) end
	end, { mode = mode })
	vim.cmd("doautocmd User StabilizeRestore")
end
EOF
autocmd QuickFixCmdPost [^l]* lua TroubleQuickFixPost("quickfix")
autocmd QuickFixCmdPost l* lua TroubleQuickFixPost("loclist")
```
On the other hand, stabilizing the `auto_open` feature for trouble.nvim currently requires the following diff:
```diff
diff --git a/lua/trouble/init.lua b/lua/trouble/init.lua
index bfb2d92..527d1ed 100644
--- a/lua/trouble/init.lua
+++ b/lua/trouble/init.lua
@@ -134,6 +134,7 @@ function Trouble.refresh(opts)
     require("trouble.providers").get(vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf(), function(results)
       if #results > 0 then
         Trouble.open(opts)
+        vim.cmd("doautocmd User StabilizeRestore")
       end
     end, config.options)
   end
```
Not sure if these workarounds can be avoided.
