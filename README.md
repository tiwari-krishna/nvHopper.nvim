# nvHopper

`nvHopper` is a minimal, persistent buffer marking and navigation plugin for Neovim.

It provides a **stable, ordered working set** of buffers with fast indexed jumps, scoped to the directory where Neovim was started, with git branch awareness.

---

## ✨ Features

* Mark up to **9 buffers** for quick access
* Jump directly via indexed mappings (`<leader>1..9`)
* Persistent sessions (per project and git branch)
* Ordered buffer list with manual reordering
* Floating window interface
* Support for split navigation
* Last-buffer swap

---

## 🧠 Design Principles

* **Static root context**
  Sessions are tied to the directory where Neovim was initially launched, regardless of later `:cd` changes. This results in separate sessions per git branch.

* **Ordered workflow**
  Buffers are treated as an ordered working set rather than an unordered list.

---

## 📦 Installation

### lazy.nvim

```lua
{
  "tiwari-krishna/nvHopper.nvim",
  config = function()
    require("nvHopper").setup()
  end
}
```

### vim.pack

```lua
vim.pack.add({
  { src = "https://github.com/tiwari-krishna/nvHopper.nvim" }
})

require("nvHopper").setup()
```

---

## 🚀 Usage

### Opening the buffer list

```vim
<leader>m
```

This opens a floating window displaying all listed buffers.

---

### Window keybindings

| Key       | Action                     |
| --------- | -------------------------- |
| `<CR>`    | Toggle mark                |
| `J` / `K` | Move buffer down / up      |
| `gl`      | Open buffer                |
| `gs`      | Open in horizontal split   |
| `gv`      | Open in vertical split     |
| `<BS>`    | Swap to last buffer        |
| `dd`      | Delete buffer              |
| `C`       | Clear all marks            |
| `r`       | Refresh buffer list        |
| `q`       | Close window               |

---

### Jumping to marked buffers

```vim
<leader>1 ... <leader>9
```

Buffers are accessed in the order they were marked.

---

## 💾 Sessions

Sessions are automatically persisted and restored.

Session identity is derived from:

* Sessions are automatically loaded on startup and saved on exit (if enabled).
* the working directory where Neovim was started
* the current git branch (if inside a git repo)

---

### Manual session control

| Mapping / Command | Action       |
| ----------------- | ------------ |
| `<leader>bs`      | Save session |
| `<leader>bl`      | Load session |
| `:NvHopperSave`   | Save session |
| `:NvHopperLoad`   | Load session |

---

## ⚙️ Configuration

Default configuration:

```lua
require("nvhopper").setup({
  open_mapping = "<leader>m",

  jump_mappings = {
    "<leader>1", "<leader>2", "<leader>3",
    "<leader>4", "<leader>5", "<leader>6",
    "<leader>7", "<leader>8", "<leader>9",
  },

  goto_file = "gl",
  clear_mark = "C",
  split_h = "gs",
  split_v = "gv",
  swap_last = "<BS>",
  delete_buffer = "dd",

  persist = {
    auto = true,
    manual = true,
    save_session = "<leader>bs",
    load_session = "<leader>bl",
  },
})
```

---

### Disabling features

Any mapping or feature can be disabled by setting it to `nil` or `false`:

```lua
require("nvhopper").setup({
  swap_last = nil,
  persist = {
    auto = false,
  },
})
```

---

## 📌 Commands

```vim
:NvHopperOpen    " Open buffer list
:NvHopperSave    " Save session
:NvHopperLoad    " Load session
:NvHopperJump N  " Jump to mark N
```

---

## 📝 Notes

* A maximum of **9 buffers** can be marked
* Only file-backed buffers are persisted
* Sessions are not affected by directory changes (`:cd`)
* Git branch is detected at startup; switching branches during a session may lead to mismatched state
