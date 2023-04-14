# ❗ https://github.com/neovim/neovim/pull/19243 deprecates this plugin
A new option is now available in both vim(9.0.0667) and neovim(0.9) that should replace this plugin.
The new `'splitkeep'` option offers two new available behaviors.
* `set splitkeep=screen` keeps the same screen screen lines in all split windows and is the most "stable" to me.
* `set splitkeep=topline` keeps the same topline as an alternative.

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
	forcemark = nil -- set context mark to register on force event which can be jumped to with '<forcemark>
	ignore = {  -- do not manage windows matching these file/buftypes
		filetype = { "help", "list", "Trouble" },
		buftype = { "terminal", "quickfix", "loclist" }
	}
	nested = nil -- comma-separated list of autocmds that wil trigger the plugins window restore function
}
```

### Note

Because `autocmd`s are by default not nested (`:h autocmd-nested`), windows spawned by autocommands won't trigger the
plugins window restore function. To stabilize these window events, a config option `nested` is exposed which can be
used to trigger `doautocmd User StabilizeRestore`.

For example, to stabilize window events such as opening the quickfix list
(or [trouble.nvim](https://github.com/folke/trouble.nvim)) on `QuickFixCmdPost` or `DiagnosticChanged` events.
For neovim >= 0.7, set the nested cfg to(mind the wildcard):

    nested = "QuickFixCmdPost,DiagnosticChanged *"

The plugin keeps track of the number of windows on the current tabpage and will skip restoring the windows if the
number of windows hasn't changed since before firing these nested events(performance consideration).
