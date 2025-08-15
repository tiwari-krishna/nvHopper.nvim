# nvHopper.nvim

A **fast, lightweight buffer switcher** for Neovim, with a smooth floating-window interface and jump-based navigation.

---

## Installation

Install via your favorite plugin manager (example using [lazy.nvim](https://github.com/folke/lazy.nvim)):

```lua
{
  "username/nvHopper.nvim",
  config = function()
    require("hopper").setup({
      open_mapping = "<leader>m",
      jump_mappings = { "<leader>i", "<leader>o", "<leader>p", "<leader>[" },
    })
  end
}
```

---

## Configuration

Place the following in your `init.lua` (or relevant config file):

```lua
require("hopper").setup({
  -- Key mapping to open the floating buffer manager
  open_mapping = "<leader>m",

  -- Keys for jumping directly to marked buffers
  jump_mappings = { "<leader>i", "<leader>o", "<leader>p", "<leader>[" },
})
```

**Notes:**

- `open_mapping` opens the **floating buffer manager** window.
- `jump_mappings` are shortcuts to instantly switch to a marked buffer.
- You can define **as many jump mappings** as you want.

**Defaults:**

- `Leader + m` → Open buffer manager
- `Leader + n` `Leader + o` → Switch to buffers (example sequence: `<leader>1`, `<leader>2`, `<leader>3`)

---

## Usage

### Inside the Floating Window

- **`Enter`** → Toggle mark/unmark a buffer as _switchable_
- **`J`**\*\* / \*\***`K`** → Move selection down/up
- **Jump Mapping** → Instantly switch to the marked buffer

---
