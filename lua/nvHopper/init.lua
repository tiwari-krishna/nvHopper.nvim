local M = {}

M.marks, M.list, M.win, M.buf, M.prev_win = {}, {}, nil, nil, nil
M.last_buf = nil
M.start_root = (vim.uv or vim.loop).cwd() or vim.fn.getcwd(-1, -1)
M.git_root = nil
local session_loaded = false
M.display_root = M.start_root

local _git_branch = nil

local function init_roots()
    local git_dirs = vim.fs.find(".git", {
        upward = true,
        stop = (vim.uv or vim.loop).os_homedir(),
        path = M.start_root,
    })

    if #git_dirs > 0 then
        M.git_root = vim.fn.fnamemodify(git_dirs[1], ":h")
        M.display_root = M.git_root

        local cmd = string.format(
            "git -C %s rev-parse --abbrev-ref HEAD 2>/dev/null",
            vim.fn.shellescape(M.git_root)
        )
        local b = vim.fn.system(cmd):gsub("\n", "")
        _git_branch = b ~= "" and b or nil
    end
end
init_roots()

M.config = {
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
}

local ns = vim.api.nvim_create_namespace("nvhopper")

local function is_home()
    return M.start_root == (vim.uv or vim.loop).os_homedir()
end

local function buf_is_usable(bufnr)
    if not bufnr or bufnr <= 0 then return false end
    if not vim.api.nvim_buf_is_valid(bufnr) then return false end
    if not vim.bo[bufnr].buflisted then return false end
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" or vim.startswith(name, "term://") then return false end
    if not vim.api.nvim_buf_is_loaded(bufnr) and vim.fn.filereadable(name) == 0 then
        return false
    end
    return true
end

local function session_file()
    local base = vim.fn.stdpath("data") .. "/nvhopper"
    vim.fn.mkdir(base, "p")
    local key = M.start_root
    if _git_branch then
        key = M.start_root .. "::" .. _git_branch
    end
    local fname = vim.fn.sha256(key)
    return base .. "/" .. fname .. ".json"
end

local function rebuild_list(preserve_order)
    local infos = vim.fn.getbufinfo({ buflisted = 1 })
    local present = {}
    for _, info in ipairs(infos) do
        if buf_is_usable(info.bufnr) then
            present[info.bufnr] = true
        end
    end

    local new_list = {}

    if preserve_order and #M.list > 0 then
        for _, b in ipairs(M.list) do
            if present[b] then
                table.insert(new_list, b)
                present[b] = nil
            end
        end
        for _, info in ipairs(infos) do
            if present[info.bufnr] then
                table.insert(new_list, info.bufnr)
                present[info.bufnr] = nil
            end
        end
    else
        for _, info in ipairs(infos) do
            if buf_is_usable(info.bufnr) then
                table.insert(new_list, info.bufnr)
            end
        end
    end

    M.list = new_list
end

local function save_session()
    if is_home() then return end

    rebuild_list(true)

    local data = { list = {}, marks = {} }

    for _, b in ipairs(M.list) do
        local name = vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) or ""
        if name ~= "" and vim.fn.filereadable(name) == 1 then
            table.insert(data.list, name)
            if M.marks[b] then
                data.marks[name] = true
            end
        elseif M.marks[b] then
            M.marks[b] = nil
        end
    end
    vim.fn.writefile({ vim.json.encode(data) }, session_file())
    vim.notify("nvhopper: session saved", vim.log.levels.INFO)
end

local function filename(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then return "[Scratch]" end
    local cwd = M.display_root .. "/"
    return name:gsub("^" .. vim.pesc(cwd), "")
end

local function marked_in_order()
    local out = {}
    for _, b in ipairs(M.list) do
        if M.marks[b] and vim.api.nvim_buf_is_valid(b) then
            table.insert(out, b)
        end
    end
    return out
end

local function refresh_lines()
    if not (M.buf and vim.api.nvim_buf_is_valid(M.buf)) then return end

    local mark_numbers = {}
    for i, b in ipairs(marked_in_order()) do
        mark_numbers[b] = i
    end

    local current_buf = nil
    if M.prev_win and vim.api.nvim_win_is_valid(M.prev_win) then
        current_buf = vim.api.nvim_win_get_buf(M.prev_win)
    end

    local lines = {}
    for _, b in ipairs(M.list) do
        if not vim.api.nvim_buf_is_valid(b) then
            goto continue
        end
        local mark = mark_numbers[b] and ("[" .. mark_numbers[b] .. "]") or "[ ]"
        local mod = vim.bo[b].modified and " [+]" or ""
        local active = (b == current_buf) and " [O]" or ""
        table.insert(lines, mark .. " " .. filename(b) .. active .. mod)
        ::continue::
    end

    if #lines == 0 then lines = { " <no listed buffers>" } end

    local prev = vim.bo[M.buf].modifiable
    vim.bo[M.buf].modifiable = true
    vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
    vim.bo[M.buf].modifiable = prev

    vim.api.nvim_set_hl(0, "NvHopperMarked", { bold = true })
    vim.api.nvim_buf_clear_namespace(M.buf, ns, 0, -1)

    for i, b in ipairs(M.list) do
        if M.marks[b] then
            vim.api.nvim_buf_add_highlight(M.buf, ns, "NvHopperMarked", i - 1, 0, -1)
        end
    end
end

local function load_session()
    if is_home() then return end

    local file = session_file()
    if vim.fn.filereadable(file) == 0 then
        session_loaded = true
        return
    end

    local raw = table.concat(vim.fn.readfile(file), "\n")
    local ok, data = pcall(vim.json.decode, raw)
    if not ok or not data then
        session_loaded = true
        return
    end

    local scratch_buf = nil
    if vim.fn.argc() == 0 then
        for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
            if info.name == "" and info.changed == 0 then
                scratch_buf = info.bufnr
                break
            end
        end
    end

    M.list, M.marks = {}, {}
    for _, name in ipairs(data.list or {}) do
        if vim.fn.filereadable(name) == 1 then
            vim.cmd("badd " .. vim.fn.fnameescape(name))
            local bufnr = vim.fn.bufnr(name)
            if bufnr > 0 then
                table.insert(M.list, bufnr)
                if data.marks[name] then
                    M.marks[bufnr] = true
                end
            end
        end
    end
    for bufnr in pairs(M.marks) do
        if not buf_is_usable(bufnr) then
            M.marks[bufnr] = nil
        end
    end

    if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
        vim.schedule(refresh_lines)
    end

    session_loaded = true

    if vim.fn.argc() == 0 then
        local target = marked_in_order()[1] or M.list[1]
        if target and vim.api.nvim_buf_is_valid(target) then
            vim.api.nvim_set_current_buf(target)
        end
        if scratch_buf and vim.api.nvim_buf_is_valid(scratch_buf) then
            vim.api.nvim_buf_delete(scratch_buf, { force = true })
            rebuild_list(true)
        end
    end
end

local function cursor_buf()
    if not (M.win and vim.api.nvim_win_is_valid(M.win)) then return nil, nil end
    local pos = vim.api.nvim_win_get_cursor(M.win)
    if not pos then return nil, nil end
    local lnum = pos[1]
    local buf = M.list[lnum]
    if not buf then return nil, nil end
    return buf, lnum
end

local function toggle_mark()
    local buf = cursor_buf()
    if not buf then return end
    if not M.marks[buf] and #marked_in_order() >= 9 then
        vim.notify("nvhopper: maximum 9 marks reached", vim.log.levels.WARN)
        return
    end
    M.marks[buf] = not M.marks[buf] or nil
    refresh_lines()
end

local function move_item(delta)
    local _, lnum = cursor_buf()
    if not lnum then return end
    local new_pos = lnum + delta
    if new_pos < 1 or new_pos > #M.list then return end
    M.list[lnum], M.list[new_pos] = M.list[new_pos], M.list[lnum]
    refresh_lines()
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_win_set_cursor(M.win, { new_pos, 0 })
    end
end

function M.jump_to_mark(idx)
    local target = marked_in_order()[idx]
    if target then
        if M.win and vim.api.nvim_get_current_win() == M.win then
            if M.prev_win and vim.api.nvim_win_is_valid(M.prev_win) then
                vim.api.nvim_set_current_win(M.prev_win)
            end
            vim.api.nvim_win_close(M.win, true)
            M.win, M.buf = nil, nil
        end
        vim.api.nvim_set_current_buf(target)
    end
end

local function open_floating_window(buf)
    local width_frac, height_frac = 0.5, 0.4
    local min_width, min_height = 30, 8
    local total_cols, total_lines = vim.o.columns, vim.o.lines

    local width = math.max(min_width, math.floor(total_cols * width_frac))
    local height = math.max(min_height, math.floor(total_lines * height_frac))
    local row = 1
    local col = math.floor((total_cols - width) / 2)

    local title = _git_branch and ("NvHopper [" .. _git_branch .. "]") or "NvHopper"

    return vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        width = width,
        height = height,
        row = row,
        col = col,
        title = title,
        title_pos = "center",
    })
end

local function close_and_do(fn)
    local prev = M.prev_win
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_win_close(M.win, true)
    end
    M.win, M.buf = nil, nil
    if prev and vim.api.nvim_win_is_valid(prev) then
        vim.api.nvim_set_current_win(prev)
    end
    fn()
end

function M.open()
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_win_close(M.win, true)
        M.win, M.buf = nil, nil
        return
    end

    M.prev_win = vim.api.nvim_get_current_win()
    rebuild_list(true)

    M.buf = vim.api.nvim_create_buf(false, true)
    M.win = open_floating_window(M.buf)
    vim.bo[M.buf].bufhidden = "wipe"
    vim.bo[M.buf].filetype = "simple_buffer_marks"
    refresh_lines()
    vim.bo[M.buf].modifiable = false
    vim.wo[M.win].cursorline = true

    vim.api.nvim_create_autocmd("WinLeave", {
        buffer = M.buf,
        once = true,
        callback = function()
            if M.win and vim.api.nvim_win_is_valid(M.win) then
                vim.api.nvim_win_close(M.win, true)
                M.win, M.buf = nil, nil
            end
        end,
    })

    local function map(lhs, rhs)
        vim.keymap.set("n", lhs, rhs, { buffer = M.buf, nowait = true, silent = true })
    end

    map("q", function()
        if M.win and vim.api.nvim_win_is_valid(M.win) then
            vim.api.nvim_win_close(M.win, true)
        end
        M.win, M.buf = nil, nil
    end)

    map("C", function()
        M.marks = {}
        refresh_lines()
        vim.notify("nvhopper: all marks cleared", vim.log.levels.INFO)
    end)

    map("<CR>", toggle_mark)
    map("J", function() move_item(1) end)
    map("K", function() move_item(-1) end)
    map("r", function()
        rebuild_list(true); refresh_lines()
    end)

    if M.config.clear_mark then
        map(M.config.clear_mark, function()
            local buf = cursor_buf()
            if not buf then return end
            if M.marks[buf] then
                M.marks[buf] = nil
                refresh_lines()
            end
        end)
    end

    if M.config.goto_file then
        map(M.config.goto_file, function()
            local buf = cursor_buf()
            if not buf then return end
            close_and_do(function()
                vim.api.nvim_set_current_buf(buf)
            end)
        end)
    end

    if M.config.split_h then
        map(M.config.split_h, function()
            local buf = cursor_buf()
            if not buf then return end
            close_and_do(function()
                vim.cmd("split")
                vim.api.nvim_set_current_buf(buf)
            end)
        end)
    end

    if M.config.split_v then
        map(M.config.split_v, function()
            local buf = cursor_buf()
            if not buf then return end
            close_and_do(function()
                vim.cmd("vsplit")
                vim.api.nvim_set_current_buf(buf)
            end)
        end)
    end

    if M.config.swap_last then
        map(M.config.swap_last, function()
            if M.last_buf and vim.api.nvim_buf_is_valid(M.last_buf) then
                local target = M.last_buf
                close_and_do(function()
                    vim.api.nvim_set_current_buf(target)
                end)
            else
                vim.notify("nvhopper: no last buffer", vim.log.levels.INFO)
            end
        end)
    end

    if M.config.delete_buffer then
        map(M.config.delete_buffer, function()
            local buf, lnum = cursor_buf()
            if not buf or not lnum then return end

            if vim.bo[buf].modified then
                local choice = vim.fn.confirm(
                    "Buffer " .. filename(buf) .. " is modified. Save before closing?",
                    "&Yes\n&No\n&Cancel", 1
                )
                if choice == 1 then
                    vim.api.nvim_buf_call(buf, function() vim.cmd("write") end)
                elseif choice == 3 or choice == 0 then
                    return
                end
            end

            M.marks[buf] = nil
            if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_delete(buf, { force = true })
            end

            rebuild_list(true)
            refresh_lines()
            if M.win and vim.api.nvim_win_is_valid(M.win) and #M.list > 0 then
                local new_lnum = math.min(lnum, #M.list)
                vim.api.nvim_win_set_cursor(M.win, { new_lnum, 0 })
            end
        end)
    end
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})

    if M.config.open_mapping then
        vim.keymap.set("n", M.config.open_mapping, M.open, { desc = "Open buffer marks list" })
    end
    if M.config.jump_mappings then
        for i, lhs in ipairs(M.config.jump_mappings) do
            vim.keymap.set("n", lhs, function() M.jump_to_mark(i) end, { desc = "Jump to buffer mark " .. i })
        end
    end

    if M.config.swap_last then
        vim.keymap.set("n", M.config.swap_last, function()
            if M.win and vim.api.nvim_win_is_valid(M.win) then return end
            if M.last_buf and vim.api.nvim_buf_is_valid(M.last_buf) then
                vim.api.nvim_set_current_buf(M.last_buf)
            else
                vim.notify("nvhopper: no last buffer", vim.log.levels.INFO)
            end
        end, { desc = "Swap to last nvhopper buffer" })
    end

    if M.config.persist and M.config.persist.manual then
        if M.config.persist.save_session then
            vim.keymap.set("n", M.config.persist.save_session, save_session, { desc = "Save buffer marks session" })
        end
        if M.config.persist.load_session then
            vim.keymap.set("n", M.config.persist.load_session, load_session, { desc = "Load buffer marks session" })
        end
    end

    if M.config.persist and M.config.persist.auto then
        if vim.v.vim_did_enter == 1 then
            vim.schedule(load_session)
        else
            vim.api.nvim_create_autocmd("VimEnter", {
                callback = function() vim.schedule(load_session) end,
            })
        end

        vim.api.nvim_create_autocmd("VimLeavePre", {
            callback = function()
                if session_loaded then save_session() end
            end,
        })
    end

    vim.api.nvim_create_autocmd("WinClosed", {
        callback = function(ev)
            if tonumber(ev.match) == M.win then
                M.win, M.buf = nil, nil
            end
        end,
    })

    vim.api.nvim_create_autocmd("BufDelete", {
        callback = function(ev)
            M.marks[ev.buf] = nil
            if M.last_buf == ev.buf then M.last_buf = nil end
            for i, b in ipairs(M.list) do
                if b == ev.buf then
                    table.remove(M.list, i)
                    break
                end
            end
        end,
    })

    vim.api.nvim_create_autocmd("BufEnter", {
        callback = function(ev)
            if ev.buf == M.buf then return end
            if vim.bo[ev.buf].buftype ~= "" then return end
            if vim.api.nvim_buf_get_name(ev.buf) == "" then return end
            local prev = vim.fn.bufnr("#")
            if prev > 0 and prev ~= ev.buf then
                M.last_buf = prev
            end
        end,
    })

    vim.api.nvim_create_autocmd("DirChanged", {
        callback = function()
            M.display_root = (vim.uv or vim.loop).cwd() or vim.fn.getcwd(-1, -1)
        end,
    })

    vim.api.nvim_create_user_command("NvHopperSave", save_session, { desc = "Save buffer marks session" })
    vim.api.nvim_create_user_command("NvHopperLoad", load_session, { desc = "Load buffer marks session" })
    vim.api.nvim_create_user_command("NvHopperOpen", M.open, { desc = "Open buffer marks floating window" })
    vim.api.nvim_create_user_command("NvHopperJump", function(nopts)
        local idx = tonumber(nopts.args)
        if idx then M.jump_to_mark(idx) else vim.notify("NvHopperJump: invalid index", vim.log.levels.WARN) end
    end, { nargs = 1, desc = "Jump to marked buffer at index" })
end

return M
