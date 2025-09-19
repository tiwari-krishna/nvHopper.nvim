# nvHopper.nvim

A **fast, lightweight buffer switcher** for Neovim, with a floating-window interface, jump-based navigation and persistence session saving when explictly asked.

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
      persist = {
        save_session = "<leader>bs",
        load_session = "<leader>bl",
      },
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
    -- Save what buffers are open in current working directory and load them later
    persist = {
        save_session = "<leader>bs",
        load_session = "<leader>bl",
    },
})
```

**Notes:**

- Buffers currently open in one of the windows can't be closed using `delete_buffer`.
- `jump_mappings` are shortcuts to instantly switch to a marked buffer.
- You can define **as many jump mappings** as you want. Default leader+<num> is shown in the list of floating window
- Buffers are neither automatically saved nor loaded. You need to explictly call the keymaps to do so.
- You can't save scratch buffers or terminal buffers.

**Defaults:**

- `Leader + m` → Open buffer manager
- `Leader + 1` `Leader + 2 .....` → Switch to buffers in sequence. (number shown in marked marker)
- `Leader + bs` → Saves list of currently open buffers alognside their marked state for current working directory
- `Leader + bs` → Loads list of saved buffers under current working directory.
- In the floating window `gl` shows the buffer under cursor and `dd` removes buffer if it is not currently visible in any split or tab (if modified then asks to save).

---

## Usage

### Inside the Floating Window

- **`Leader + m`** → Open the floating buffer manager with all the open neovim buffers
- **`Enter`** → Toggle mark/unmark a buffer as _switchable_
- **`J`** / **`K`** → Move selection down/up
- **Jump Mapping** → Instantly switch to the marked buffer
- **dd** closed the buffer under the cursor. If modified asks to save or not.
- **gl** Opens the buffer in last focused/selected window.
- **`Leader + bs`** Saves the list of currently open buffers alongside the numbered mark for current working directory
- **`Leader + bl`** Loads the saved list of buffers alongside their numbered marks for currently working directory

---
