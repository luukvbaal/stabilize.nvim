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
  ft_ignore = { "help", "list", "Trouble" } -- do not manage windows matching these filetypes
}
```
