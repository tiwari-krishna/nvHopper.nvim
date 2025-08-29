# nvHopper.nvim

A **fast, lightweight buffer switcher** for Neovim, with a floating-window interface and jump-based navigation.

---

## Installation

Install via your favorite plugin manager (example using [lazy.nvim](https://github.com/folke/lazy.nvim)):

```lua
{
  "tiwari-krishna/nvHopper.nvim",
  config = function()
    require("hopper").setup({
      open_mapping = "<leader>m",
      goto_file = "gl",
      delete_buffer = "dd",
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
    -- Open the buffer under the cursor in last focused window or split
    goto_file = "gl",
    -- Close buffer under the cursor (does not work if the buffer is open in a window)
    delete_buffer = "dd",
    -- Keys for jumping directly to marked buffers
    jump_mappings = { "<leader>i", "<leader>o", "<leader>p", "<leader>[" },
})
```

**Notes:**

- Buffers currently open in one of the windows can't be closed using `delete_buffer`.
- `jump_mappings` are shortcuts to instantly switch to a marked buffer.
- You can define **as many jump mappings** as you want. Default leader+<num> is shown in the list of floating window

**Defaults:**

- `Leader + m` → Open buffer manager
- `Leader + 1` `Leader + 2 .....` → Switch to buffers in sequence. (number shown in marked marker)

---

## Usage

### Inside the Floating Window

- **`Leader + m`** → Open the floating buffer manager with all the open neovim buffers
- **`Enter`** → Toggle mark/unmark a buffer as _switchable_
- **`J`**\*\* / \*\***`K`** → Move selection down/up
- **Jump Mapping** → Instantly switch to the marked buffer
- **dd** closed the buffer under the cursor. If modified asks to save or not.
- **gl** Opens the buffer in last focused/selected window.

---
