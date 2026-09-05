-- ================================================================
-- Lazy
-- ================================================================
local zappPath = vim.env.ZAPP_PATH
if zappPath then
    local NvimDir = zappPath .. "/config/nvim"
    local statNvimDir = vim.uv.fs_stat(NvimDir)
    if statNvimDir and statNvimDir.type == "directory" then
        -- Globals:
        nvim_colorscheme = "catppuccin" 
        lualine_theme    = "catppuccin-nvim" 
        telescope        = nil 
        -- Lazy
        dofile(NvimDir .. "/lua/_lazy.lua")
        vim.opt.rtp:prepend(NvimDir)
        -- ColorScheme
        vim.cmd.colorscheme(nvim_colorscheme)
        -- Configs
        require("_lualine")(lualine)
        require("_bufferline")()
        telescope = require("_telescope")()
        require("_coc")()
        require("_auto-pairs")()
        require("_tree-sitter")()
        require("_colorizer")()
        require("_yazi")()
    end
end
-- ================================================================
-- Global Functions
-- ================================================================
function dump(t, indent)
    indent = indent or 0
    for key, value in pairs(t) do
        print(string.rep(" ", indent) .. tostring(key) .. " = " .. tostring(value))
        if type(value) == "table" then
            dump(value, indent + 2)
        end
    end
end
-- ================================================================
-- Nvim Config
-- ================================================================
vim.cmd("syntax on")
vim.opt.background = "dark"
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.foldmethod = "marker"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.history = 1000 
vim.opt.autoindent = true
vim.opt.expandtab = true
vim.opt.termguicolors = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.mouse = "a"
vim.opt.title = true
-- Move cache, This redues clutter in $HOME
local viminfo_dir = vim.fn.expand("~/.local/state/nvim")
if vim.fn.isdirectory(viminfo_dir) == 0 then
    vim.fn.mkdir(viminfo_dir, "p")
end
vim.opt.viminfofile = viminfo_dir .. "/nviminfo"
-- ================================================================
-- Binds
-- ================================================================
-- leader
vim.g.mapleader = " "
-- telescope
if telescope then
    vim.keymap.set(
        'n',
        '<leader>ff',
        telescope.find_files,
        { desc = 'Telescope find files' }
    )
    vim.keymap.set(
        'n',
        '<leader>fF', 
        function() telescope.find_files({ cwd = vim.env.HOME }) end,
        { desc = 'Find files in home directory' }
    )
    vim.keymap.set(
        'n',
        '<leader>fg',
        telescope.live_grep,
        { desc = 'Telescope live grep' }
    )
    vim.keymap.set(
        'n',
        '<leader>fs',
        telescope.current_buffer_fuzzy_find,
        { desc = 'Telescope current buffer' }
    )
    vim.keymap.set(
        'n',
        '<leader>fh',
        telescope.help_tags,
        { desc = 'Telescope help tags' }
    )
    vim.keymap.set(
        'n',
        '<leader>fr',
        telescope.registers,
        { desc = 'Telescope registers' }
    )
end
-- Yazi
vim.keymap.set(
    {'n', 'v'},
    '<C-g>',
    '<cmd>Yazi cwd<cr>',
    { desc = 'Open yazi in pwd' }
)
-- custom
vim.keymap.set({'n'}, '<leader>p','"0p' ,{ desc = 'Paste' })
vim.keymap.set({'n'}, '<leader>d','<cmd>bd<CR>' ,{ desc = 'Buffer Delete' })
vim.keymap.set({'n'}, 'gb','<cmd>bn<cr>', { desc = 'Next buffer' })
vim.keymap.set({'n'}, 'gB','<cmd>bp<cr>', { desc = 'Previous buffer' })
vim.keymap.set(
    {'n'},
    '<leader>gw', 
    function () 
        if vim.opt.linebreak._value then
            vim.opt.linebreak = false
        else 
            vim.opt.linebreak = true
        end
    end,
    {desc = "Toggle linebrake"}
)
-- ================================================================
-- Splash
-- ================================================================
-- Center text horizontally
local function Center(lines)
    local width = vim.o.columns
    local centered = {}
    for _, line in ipairs(lines) do
        local pad_len = math.max(0, math.floor((width - vim.fn.strdisplaywidth(line)) / 2))
        table.insert(centered, string.rep(" ", pad_len) .. line)
    end
    return centered
end
-- Center text vertically
local function CenterVertical(lines)
    local height = vim.o.lines
    local top_padding = math.max(0, math.floor((height - #lines) / 2))
    local empty = {}
    for _ = 1, top_padding do
        table.insert(empty, "")
    end
    for _, line in ipairs(lines) do
        table.insert(empty, line)
    end
    return empty
end
-- Fill remaining lines to screen
local function FillToScreen(start_line)
    local total = vim.o.lines
    local current = vim.fn.line("$")
    local needed = total - current
    if needed > 0 then
        local fill = {}
        for _ = 1, needed do
            table.insert(fill, " ")
        end
        vim.fn.append(current, fill)
    end
end
-- Show splash screen on VimEnter if no files are opened
vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        -- If no argument is passed
        if vim.fn.argc() == 0 then
            -- create a new buffer
            vim.cmd("enew")
            -- set some local variables to make the buffer inconsequential
            vim.opt_local.buftype = "nofile"
            vim.opt_local.swapfile = false
            vim.opt_local.buflisted = false
            vim.opt_local.number = false
            vim.opt_local.relativenumber = false

            local header = {
                "██████╗ ██╗     ██╗████████╗███████╗      ",
                "██╔══██╗██║     ██║╚══██╔══╝╚══███╔╝      ",
                "██████╔╝██║     ██║   ██║     ███╔╝       ",
                "██╔══██╗██║     ██║   ██║    ███╔╝        ",
                "██████╔╝███████╗██║   ██║   ███████╗██╗██╗",
                "╚═════╝ ╚══════╝╚═╝   ╚═╝   ╚══════╝╚═╝╚═╝",
                "    \"clankers envy your motions\"      ",

            }

            local splash = CenterVertical(Center(header))
            vim.fn.setline(1, splash)
            FillToScreen(#splash)
        end
    end
})

