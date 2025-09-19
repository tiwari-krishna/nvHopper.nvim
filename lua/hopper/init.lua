local M = {}

M.marks, M.list, M.win, M.buf, M.prev_win = {}, {}, nil, nil, nil

M.config = {
    open_mapping = "<leader>m",
    jump_mappings = {
        "<leader>1",
        "<leader>2",
        "<leader>3",
        "<leader>4",
        "<leader>5",
        "<leader>6",
        "<leader>7",
        "<leader>8",
        "<leader>9",
    },
    goto_file = "gl",
    delete_buffer = "dd",
    persist = {
        save_session = "<leader>bs",
        load_session = "<leader>bl",
    },
}

local function session_file()
    local cwd = vim.loop.cwd()
    local base = vim.fn.stdpath("data") .. "/nvhopper"
    vim.fn.mkdir(base, "p")
    local fname = cwd:gsub("[/:\\]", "_")
    return base .. "/" .. fname .. ".json"
end

local function save_session()
    local data = {
        list = {},
        marks = {},
    }
    for _, b in ipairs(M.list) do
        if vim.api.nvim_buf_is_valid(b) then
            local name = vim.api.nvim_buf_get_name(b)
            if name ~= "" and not vim.startswith(name, "term://") then
                table.insert(data.list, name)
                if M.marks[b] then
                    data.marks[name] = true
                end
            end
        end
    end
    vim.fn.writefile({ vim.json.encode(data) }, session_file())
    vim.notify("nvhopper: session saved", vim.log.levels.INFO)
end

local function rebuild_list(preserve_order)
    local infos = vim.fn.getbufinfo({ buflisted = 1 })
    local present = {}
    for _, info in ipairs(infos) do
        present[info.bufnr] = true
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
            table.insert(new_list, info.bufnr)
        end
    end

    M.list = new_list
end

local function filename(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then
        return "[No Name]"
    end
    local cwd = vim.loop.cwd() .. "/"
    local rel = name:gsub("^" .. vim.pesc(cwd), "")
    return rel
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
    if not (M.buf and vim.api.nvim_buf_is_valid(M.buf)) then
        return
    end

    local mark_numbers = {}
    for i, b in ipairs(marked_in_order()) do
        mark_numbers[b] = i
    end
    local lines = {}
    for _, b in ipairs(M.list) do
        local mark = mark_numbers[b] and ("[" .. mark_numbers[b] .. "]") or "[ ]"
        local mod = vim.api.nvim_buf_get_option(b, "modified") and " [+]" or ""
        table.insert(lines, mark .. " " .. filename(b) .. mod)
    end
    if #lines == 0 then
        lines = { " <no listed buffers>" }
    end

    local prev = vim.bo[M.buf].modifiable
    vim.bo[M.buf].modifiable = true
    vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
    vim.bo[M.buf].modifiable = prev
end

local function load_session()
    local file = session_file()
    if vim.fn.filereadable(file) == 0 then
        vim.notify("nvhopper: no saved session for cwd", vim.log.levels.WARN)
        return
    end
    local raw = table.concat(vim.fn.readfile(file), "\n")
    local ok, data = pcall(vim.json.decode, raw)
    if not ok or not data then
        vim.notify("nvhopper: failed to load session", vim.log.levels.ERROR)
        return
    end

    M.list, M.marks = {}, {}
    for _, name in ipairs(data.list or {}) do
        -- ensure buffer exists
        vim.cmd("badd " .. vim.fn.fnameescape(name))
        local bufnr = vim.fn.bufnr(name)
        if bufnr > 0 then
            table.insert(M.list, bufnr)
            if data.marks[name] then
                M.marks[bufnr] = true
            end
        end
    end

    if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
        vim.schedule(function()
            vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, {})
            refresh_lines()
        end)
    end

    vim.notify("nvhopper: session loaded", vim.log.levels.INFO)
end

local function cursor_buf()
    if not (M.win and vim.api.nvim_win_is_valid(M.win)) then
        return nil, nil
    end
    local pos = vim.api.nvim_win_get_cursor(M.win)
    if not pos then
        return nil, nil
    end
    local lnum = pos[1]
    local buf = M.list[lnum]
    if not buf then return nil, nil end
    return buf, lnum
end

local function toggle_mark()
    local buf = cursor_buf()
    if not buf then
        return
    end
    M.marks[buf] = not M.marks[buf] or nil
    refresh_lines()
end

local function move_item(delta)
    local _, lnum = cursor_buf()
    if not lnum then
        return
    end
    local new_pos = lnum + delta
    if new_pos < 1 or new_pos > #M.list then
        return
    end
    M.list[lnum], M.list[new_pos] = M.list[new_pos], M.list[lnum]
    refresh_lines()
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_win_set_cursor(M.win, { new_pos, 0 })
    end
end

function M.jump_to_mark(idx)
    local target = marked_in_order()[idx]
    if target then
        vim.api.nvim_set_current_buf(target)
    end
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
    M.win = vim.api.nvim_open_win(M.buf, true, {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        title = {
            { "N", "Normal" }, { "v", "Normal" }, { "H", "Normal" },
            { "o", "Normal" }, { "p", "Normal" }, { "p", "Normal" },
            { "e", "Normal" }, { "r", "Normal" },
        },
        title_pos = "center",

        width = math.max(30, math.floor(vim.o.columns * 0.5)),
        height = math.max(8, math.floor(vim.o.lines * 0.4)),
        row = math.floor((vim.o.lines - math.floor(vim.o.lines * 1.0)) / 2),
        col = math.floor((vim.o.columns - math.floor(vim.o.columns * 0.5)) / 2),
    })
    vim.bo[M.buf].bufhidden = "wipe"
    vim.bo[M.buf].filetype = "simple_buffer_marks"
    refresh_lines()

    local function map(lhs, rhs)
        vim.keymap.set("n", lhs, rhs, { buffer = M.buf, nowait = true, silent = true })
    end

    map("q", function()
        if M.win and vim.api.nvim_win_is_valid(M.win) then
            vim.api.nvim_win_close(M.win, true)
        end
        M.win, M.buf = nil, nil
    end)

    map("<CR>", toggle_mark)
    map("J", function() move_item(1) end)
    map("K", function() move_item(-1) end)
    map("r", function()
        rebuild_list(true)
        refresh_lines()
    end)

    if M.config.goto_file then
        map(M.config.goto_file, function()
            local buf = cursor_buf()
            if buf and M.prev_win and vim.api.nvim_win_is_valid(M.prev_win) then
                vim.api.nvim_set_current_win(M.prev_win)
                vim.api.nvim_set_current_buf(buf)
            end
            if M.win and vim.api.nvim_win_is_valid(M.win) then
                vim.api.nvim_win_close(M.win, true)
            end
            M.win, M.buf = nil, nil
        end)
    end

    if M.config.delete_buffer then
        map(M.config.delete_buffer, function()
            local buf, lnum = cursor_buf()
            if not buf or not lnum then
                return
            end
            if vim.api.nvim_buf_get_option(buf, "modified") then
                local choice = vim.fn.confirm(
                    "Buffer " .. filename(buf) .. " is modified. Save before closing?",
                    "&Yes\n&No\n&Cancel",
                    1
                )
                if choice == 1 then
                    vim.api.nvim_buf_call(buf, function() vim.cmd("write") end)
                elseif choice == 3 then
                    return
                end
            end
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
            vim.keymap.set("n", lhs, function() M.jump_to_mark(i) end,
                { desc = "Jump to buffer mark " .. i })
        end
    end
    if M.config.persist then
        if M.config.persist.save_session then
            vim.keymap.set("n", M.config.persist.save_session, save_session,
                { desc = "Save buffer marks session" })
        end
        if M.config.persist.load_session then
            vim.keymap.set("n", M.config.persist.load_session, load_session,
                { desc = "Load buffer marks session" })
        end
    end

    vim.api.nvim_create_user_command("NvHopperSave", save_session, { desc = "Save buffer marks session" })
    vim.api.nvim_create_user_command("NvHopperLoad", load_session, { desc = "Load buffer marks session" })
    vim.api.nvim_create_user_command("NvHopperOpen", M.open, { desc = "Open buffer marks floating window" })
    vim.api.nvim_create_user_command(
        "NvHopperJump",
        function(nopts)
            local idx = tonumber(nopts.args)
            if idx then
                M.jump_to_mark(idx)
            else
                vim.notify("NvHopperJump: invalid index", vim.log.levels.WARN)
            end
        end,
        { nargs = 1, desc = "Jump to marked buffer at index" })
end

return M
