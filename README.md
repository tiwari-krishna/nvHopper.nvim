# nvHopper.nvim

Neovim buffer switcher

## Enable the follwing code inside of your init.lua

```lua
require("hopper").setup({
	open_mapping = "<leader>m",
	jump_mappings = { "<leader>i", "<leader>o", "<leader>p", "<leader>[" },
})
```

open_mapping opens the floating buffer manger window
feel free to add as many jump_mappings as possible and needed

default mappings are Leader+m to open floating window and Leader+no(eg 1 2 3) to switch windows

## On the floating window

press Enter to toggle mark the buffer as switchable. Then press the jump_mappings in order to go there.
Press J/K to move up and down
