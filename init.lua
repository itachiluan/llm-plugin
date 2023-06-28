local api = vim.api

local window_buffer_ids = {}

-- Define a function that creates a floating window and buffer
local function create_window_buffer(params)
    local row = params['row']
    local col = params['col']
    local width = params['width']
    local height = params['height']
    local text = params['text']
    local key = params['key']
    local title = params['title']

    -- Create a new buffer
    local bufnr = api.nvim_create_buf(false, true)

    -- Set the contents of the buffer
    api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(text, "\n"))
    if params.filetype then
        api.nvim_buf_set_option(bufnr, 'filetype', params.filetype)
        api.nvim_command('setlocal syntax=' .. params.filetype)
    end

    -- Create the floating window
    local win_id = api.nvim_open_win(bufnr, true, {
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        border = {"╭", "─", "╮", "│", "╯", "─", "╰", "│"},
        title = title,
        title_pos = 'center',
    })

    -- Set options for the window
    api.nvim_win_set_option(win_id, "wrap", true)
    api.nvim_win_set_option(win_id, "linebreak", true)
    api.nvim_win_set_option(win_id, "number", true)
    api.nvim_win_set_option(win_id, "cursorline", true)
    api.nvim_win_set_option(win_id, "cursorcolumn", false)
    api.nvim_win_set_option(win_id, "list", false)
    api.nvim_win_set_option(win_id, "foldcolumn", "0")
    api.nvim_win_set_option(win_id, "signcolumn", "no")
    api.nvim_win_set_option(win_id, 'winhl', 'Normal:Normal')

    local keymap_opts = {nowait = true, noremap = true, silent = true}
    local noop_cmd = ":<C-u>echo ''<CR>"
    api.nvim_buf_set_keymap(bufnr, "n", "<C-w>l", noop_cmd, keymap_opts)
    api.nvim_buf_set_keymap(bufnr, "n", "<C-w>b", noop_cmd, keymap_opts)
    api.nvim_buf_set_keymap(bufnr, "n", "<C-w>r", noop_cmd, keymap_opts)
    api.nvim_buf_set_keymap(bufnr, "n", "<C-w><C-l>", noop_cmd, keymap_opts)
    api.nvim_buf_set_keymap(bufnr, "n", "<C-w><C-j>", noop_cmd, keymap_opts)
    api.nvim_buf_set_keymap(bufnr, "n", "<C-w><C-k>", noop_cmd, keymap_opts)
    api.nvim_buf_set_keymap(bufnr, "n", "<C-w><C-h>", noop_cmd, keymap_opts)
    -- Keybindings to move the cursor to specific windows

    -- Keybindings to move the cursor to specific windows
    api.nvim_buf_set_keymap(bufnr, "n", "<leader>mvl", ":lua llm_move_cursor_to_window('top_left')<CR>", keymap_opts)
    api.nvim_buf_set_keymap(bufnr, "n", "<leader>mvp", ":lua llm_move_cursor_to_window('bottom_left')<CR>", keymap_opts)
    api.nvim_buf_set_keymap(bufnr, "n", "<leader>mvj", ":lua llm_move_cursor_to_window('right')<CR>", keymap_opts)
    api.nvim_buf_set_keymap(bufnr, "n", "<leader>llm", ":lua call_llm()<CR>", keymap_opts)

    window_buffer_ids[key] = { win_id, bufnr }
end

-- Define a function that closes the floating window
local function close_window()
    api.nvim_win_close(window_id, true)
    api.nvim_buf_delete(buffer_id, {})
end

function _G.llm_move_cursor_to_window(window_key)
    local win_info = window_buffer_ids[window_key]
    if win_info then
        api.nvim_set_current_win(win_info[1])
    end
end

local function get_current_buffer_content(line1, line2)
    local current_bufnr = api.nvim_get_current_buf()
    local mode = api.nvim_get_mode().mode
    local text, filetype

    if line1 and line2 and (line1 ~= line2) then
        -- Get the visually selected text using the passed range
        local selected_lines = api.nvim_buf_get_lines(current_bufnr, line1 - 1, line2, false)
        text = table.concat(selected_lines, "\n")
    else
        -- Get the entire buffer content
        local current_buf_content = api.nvim_buf_get_lines(current_bufnr, 0, -1, false)
        text = table.concat(current_buf_content, "\n")
    end

    filetype = vim.bo.filetype
    return text, filetype
end

local function get_buffer_content_by_key(window_key)
    local bufnr = window_buffer_ids[window_key][2]
    if bufnr then
        local buffer_content = api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local text = table.concat(buffer_content, "\n")
        return text
    else
        print("Window key not found.")
        return nil
    end
end

local function set_buffer_content_by_key(window_key, text)
    local bufnr = window_buffer_ids[window_key][2]
    if bufnr then
        local lines = vim.split(text, "\n")
        api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    else
        print("Window key not found.")
    end
end

local function call_llm_api(code, prompt_content)
    local url = "http://localhost:3500/api/llm"
    local payload = {
        code = code,
        prompt = prompt_content
    }

    local json_payload = vim.fn.json_encode(payload)

    local curl_command = string.format(
        'curl -s -X POST -H "Content-Type: application/json" -d \'%s\' %s',
        json_payload,
        url
    )

    local output_file = io.popen(curl_command)
    local response_body = output_file:read("a")
    output_file:close()

    if response_body == "" then
        print("Error calling LLM API with curl")
        return nil
    else
        local response_data = vim.fn.json_decode(response_body)
        return response_data
    end
end

function _G.call_llm()
    local code = get_buffer_content_by_key("top_left")
    local prompt = get_buffer_content_by_key("bottom_left")
    
    local response_data = call_llm_api(code, prompt)
    set_buffer_content_by_key("right", response_data.response)
end

-- Define the Floaty command to create the floating window
function _G.floaty(line1, line2)

    local win_width = math.floor(vim.o.columns * 0.8)
    local win_height = math.floor(vim.o.lines * 0.8)
    local win_row = math.floor((vim.o.lines - win_height) / 2)
    local win_col = math.floor((vim.o.columns - win_width) / 2)

    ---- Create the left-side windows
    local local_text, filetype = get_current_buffer_content(line1, line2)

    local left_width = win_width / 2
    local left_height = win_height
    local left_row = win_row
    local left_col = win_col

    local top_left_height = math.floor(left_height * 0.8)
    local top_left_row = left_row
    local top_left_col = left_col
    create_window_buffer({
        row = top_left_row,
        col = top_left_col,
        width = left_width,
        height = top_left_height,
        text = local_text,
        key = 'top_left',
        title = 'LOCAL CODE',
        filetype = filetype
    })

    local bottom_left_height = left_height - top_left_height
    local bottom_left_row = left_row + left_height - 8
    local bottom_left_col = left_col
    create_window_buffer({
        row = bottom_left_row,
        col = bottom_left_col,
        width = left_width,
        height = bottom_left_height,
        text = "",
        key = 'bottom_left',
        title = 'PROMPT'
    })

    ---- Create the right-side window
    local right_width = left_width
    local right_height = win_height + 2
    local right_row = win_row
    local right_col = left_col + left_width + 2
    create_window_buffer({
        row = right_row,
        col = right_col,
        width = right_width,
        height = right_height,
        text = "",
        key = 'right',
        title = 'From LLM:'
    })

end
vim.cmd("command! Floaty lua floaty()")
vim.cmd("command! -range Floaty <line1>,<line2>lua floaty(<line1>, <line2>)")

-- Define the CloseFloaty command to close the floating window
function _G.close_floaty()
    for key, value in pairs(window_buffer_ids) do
        api.nvim_win_close(value[1], true)
        api.nvim_buf_delete(value[2], {})
        window_buffer_ids[key] = nil
    end
end
vim.cmd("command! CloseFloaty lua close_floaty()")
