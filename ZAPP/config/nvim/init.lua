-- STAGE 1 {{{

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)
vim.g.mapleader = " "

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
    { 'nvim-lualine/lualine.nvim',dependencies = { 'nvim-tree/nvim-web-devicons' }},
    {'akinsho/bufferline.nvim', version = "*", dependencies = 'nvim-tree/nvim-web-devicons'},
    {'nvim-telescope/telescope.nvim', version = '*',dependencies = {'nvim-lua/plenary.nvim',
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' }} },
    {"kylechui/nvim-surround",version = "^4.0.0",event = "VeryLazy",},
    {'windwp/nvim-autopairs',event = "InsertEnter",config = true},
    {"mikavilpas/yazi.nvim",version = "*",event = "VeryLazy",
        dependencies = {{ "nvim-lua/plenary.nvim", lazy = true }},
    },
    {'neoclide/coc.nvim', branch = 'release', },
    {'nvim-treesitter/nvim-treesitter',lazy = false,build = ':TSUpdate'},
    {'MeanderingProgrammer/render-markdown.nvim',
        dependencies = { 
            'nvim-treesitter/nvim-treesitter', 
            'nvim-tree/nvim-web-devicons' 
        },
    opts = {},
    },
    {"catgoose/nvim-colorizer.lua",
        event = "BufReadPre",
        opts = {},
    },
  },
  ui = {
    border = "bold"
  },
})
-- }}}

-- STAGE 2 {{{

nvim_colorscheme = "catppuccin" 
lualine_theme = "catppuccin-nvim" 
vim.cmd.colorscheme(nvim_colorscheme)

-- Lualine {{{
require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = lualine_theme,
    component_separators = { left = '', right = ''},
    section_separators = { left = '', right = ''},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    always_show_tabline = true,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
      refresh_time = 16, -- ~60fps
      events = {
        'WinEnter',
        'BufEnter',
        'BufWritePost',
        'SessionLoadPost',
        'FileChangedShellPost',
        'VimResized',
        'Filetype',
        'CursorMoved',
        'CursorMovedI',
        'ModeChanged',
      },
    }
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {'filename'},
    lualine_x = {'encoding', 'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}
-- }}}

-- Bufferline {{{
local bufferline = require("bufferline")
bufferline.setup{
    options = {
        style_preset = bufferline.style_preset.minimal,
        indicator = {
            style = 'icon'
        }
    }
}
-- }}}

-- Telescope {{{
require("telescope").setup {
    defaults = {
        borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" }
    } 
}
local telescope = require('telescope.builtin')

-- }}}

-- auto-pairs {{{
local remap = vim.api.nvim_set_keymap
local npairs = require('nvim-autopairs')

npairs.setup({ map_bs = false, map_cr = false })

vim.g.coq_settings = { keymap = { recommended = false } }

-- these mappings are coq recommended mappings unrelated to nvim-autopairs
remap('i', '<esc>', [[pumvisible() ? "<c-e><esc>" : "<esc>"]], { expr = true, noremap = true })
remap('i', '<c-c>', [[pumvisible() ? "<c-e><c-c>" : "<c-c>"]], { expr = true, noremap = true })
remap('i', '<tab>', [[pumvisible() ? "<c-n>" : "<tab>"]], { expr = true, noremap = true })
remap('i', '<s-tab>', [[pumvisible() ? "<c-p>" : "<bs>"]], { expr = true, noremap = true })

-- skip it, if you use another global object
_G.MUtils= {}

MUtils.CR = function()
  if vim.fn.pumvisible() ~= 0 then
    if vim.fn.complete_info({ 'selected' }).selected ~= -1 then
      return npairs.esc('<c-y>')
    else
      return npairs.esc('<c-e>') .. npairs.autopairs_cr()
    end
  else
    return npairs.autopairs_cr()
  end
end
remap('i', '<cr>', 'v:lua.MUtils.CR()', { expr = true, noremap = true })

MUtils.BS = function()
  if vim.fn.pumvisible() ~= 0 and vim.fn.complete_info({ 'mode' }).mode == 'eval' then
    return npairs.esc('<c-e>') .. npairs.autopairs_bs()
  else
    return npairs.autopairs_bs()
  end
end
remap('i', '<bs>', 'v:lua.MUtils.BS()', { expr = true, noremap = true })    
-- }}}

-- Coc {{{
-- https://raw.githubusercontent.com/neoclide/coc.nvim/master/doc/coc-example-config.lua

-- Global extensions
vim.g.coc_global_extensions = {'coc-snippets'}
-- Some servers have issues with backup files, see #649
vim.opt.backup = false
vim.opt.writebackup = false

-- Having longer updatetime (default is 4000 ms = 4s) leads to noticeable
-- delays and poor user experience
vim.opt.updatetime = 300

-- Always show the signcolumn, otherwise it would shift the text each time
-- diagnostics appeared/became resolved
vim.opt.signcolumn = "yes"

local keyset = vim.keymap.set
-- Autocomplete
function _G.check_back_space()
    local col = vim.fn.col('.') - 1
    return col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') ~= nil
end

-- Use Tab for trigger completion with characters ahead and navigate
-- NOTE: There's always a completion item selected by default, you may want to enable
-- no select by setting `"suggest.noselect": true` in your configuration file
-- NOTE: Use command ':verbose imap <tab>' to make sure Tab is not mapped by
-- other plugins before putting this into your config
local opts = {silent = true, noremap = true, expr = true, replace_keycodes = false}
keyset("i", "<TAB>", 'coc#pum#visible() ? coc#pum#next(1) : v:lua.check_back_space() ? "<TAB>" : coc#refresh()', opts)
keyset("i", "<S-TAB>", [[coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"]], opts)

-- Make <CR> to accept selected completion item or notify coc.nvim to format
-- <C-g>u breaks current undo, please make your own choice
keyset("i", "<cr>", [[coc#pum#visible() ? coc#pum#confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"]], opts)

-- Use <c-j> to trigger snippets
keyset("i", "<c-j>", "<Plug>(coc-snippets-expand-jump)", {silent = true, remap = true})
-- Use <c-space> to trigger completion
keyset("i", "<c-space>", "coc#refresh()", {silent = true, expr = true})

-- Use `[g` and `]g` to navigate diagnostics
-- Use `:CocDiagnostics` to get all diagnostics of current buffer in location list
keyset("n", "[g", "<Plug>(coc-diagnostic-prev)", {silent = true})
keyset("n", "]g", "<Plug>(coc-diagnostic-next)", {silent = true})

-- GoTo code navigation
keyset("n", "gd", "<Plug>(coc-definition)", {silent = true})
keyset("n", "gy", "<Plug>(coc-type-definition)", {silent = true})
keyset("n", "gi", "<Plug>(coc-implementation)", {silent = true})
keyset("n", "gr", "<Plug>(coc-references)", {silent = true})


-- Use K to show documentation in preview window
function _G.show_docs()
    local cw = vim.fn.expand('<cword>')
    if vim.fn.index({'vim', 'help'}, vim.bo.filetype) >= 0 then
        vim.api.nvim_command('h ' .. cw)
    elseif vim.api.nvim_eval('coc#rpc#ready()') then
        vim.fn.CocActionAsync('doHover')
    else
        vim.api.nvim_command('!' .. vim.o.keywordprg .. ' ' .. cw)
    end
end
keyset("n", "K", '<CMD>lua _G.show_docs()<CR>', {silent = true})


-- Highlight the symbol and its references on a CursorHold event(cursor is idle)
vim.api.nvim_create_augroup("CocGroup", {})
vim.api.nvim_create_autocmd("CursorHold", {
    group = "CocGroup",
    command = "silent call CocActionAsync('highlight')",
    desc = "Highlight symbol under cursor on CursorHold"
})


-- Symbol renaming
keyset("n", "<leader>rn", "<Plug>(coc-rename)", {silent = true})


-- Formatting selected code
keyset("x", "<leader>f", "<Plug>(coc-format-selected)", {silent = true})
keyset("n", "<leader>f", "<Plug>(coc-format-selected)", {silent = true})


-- Setup formatexpr specified filetype(s)
vim.api.nvim_create_autocmd("FileType", {
    group = "CocGroup",
    pattern = "typescript,json",
    command = "setl formatexpr=CocAction('formatSelected')",
    desc = "Setup formatexpr specified filetype(s)."
})

-- Apply codeAction to the selected region
-- Example: `<leader>aap` for current paragraph
local opts = {silent = true, nowait = true}
keyset("x", "<leader>a", "<Plug>(coc-codeaction-selected)", opts)
keyset("n", "<leader>a", "<Plug>(coc-codeaction-selected)", opts)

-- Remap keys for apply code actions at the cursor position.
keyset("n", "<leader>ac", "<Plug>(coc-codeaction-cursor)", opts)
-- Remap keys for apply source code actions for current file.
keyset("n", "<leader>as", "<Plug>(coc-codeaction-source)", opts)
-- Apply the most preferred quickfix action on the current line.
keyset("n", "<leader>qf", "<Plug>(coc-fix-current)", opts)

-- Remap keys for apply refactor code actions.
keyset("n", "<leader>re", "<Plug>(coc-codeaction-refactor)", { silent = true })
keyset("x", "<leader>r", "<Plug>(coc-codeaction-refactor-selected)", { silent = true })
keyset("n", "<leader>r", "<Plug>(coc-codeaction-refactor-selected)", { silent = true })

-- Run the Code Lens actions on the current line
keyset("n", "<leader>cl", "<Plug>(coc-codelens-action)", opts)


-- Map function and class text objects
-- NOTE: Requires 'textDocument.documentSymbol' support from the language server
keyset("x", "if", "<Plug>(coc-funcobj-i)", opts)
keyset("o", "if", "<Plug>(coc-funcobj-i)", opts)
keyset("x", "af", "<Plug>(coc-funcobj-a)", opts)
keyset("o", "af", "<Plug>(coc-funcobj-a)", opts)
keyset("x", "ic", "<Plug>(coc-classobj-i)", opts)
keyset("o", "ic", "<Plug>(coc-classobj-i)", opts)
keyset("x", "ac", "<Plug>(coc-classobj-a)", opts)
keyset("o", "ac", "<Plug>(coc-classobj-a)", opts)


-- Remap <C-f> and <C-b> to scroll float windows/popups
---@diagnostic disable-next-line: redefined-local
local opts = {silent = true, nowait = true, expr = true}
keyset("n", "<C-f>", 'coc#float#has_scroll() ? coc#float#scroll(1) : "<C-f>"', opts)
keyset("n", "<C-b>", 'coc#float#has_scroll() ? coc#float#scroll(0) : "<C-b>"', opts)
keyset("i", "<C-f>",
       'coc#float#has_scroll() ? "<c-r>=coc#float#scroll(1)<cr>" : "<Right>"', opts)
keyset("i", "<C-b>",
       'coc#float#has_scroll() ? "<c-r>=coc#float#scroll(0)<cr>" : "<Left>"', opts)
keyset("v", "<C-f>", 'coc#float#has_scroll() ? coc#float#scroll(1) : "<C-f>"', opts)
keyset("v", "<C-b>", 'coc#float#has_scroll() ? coc#float#scroll(0) : "<C-b>"', opts)


-- Use CTRL-S for selections ranges
-- Requires 'textDocument/selectionRange' support of language server
keyset("n", "<C-s>", "<Plug>(coc-range-select)", {silent = true})
keyset("x", "<C-s>", "<Plug>(coc-range-select)", {silent = true})


-- Add `:Format` command to format current buffer
vim.api.nvim_create_user_command("Format", "call CocAction('format')", {})

-- " Add `:Fold` command to fold current buffer
vim.api.nvim_create_user_command("Fold", "call CocAction('fold', <f-args>)", {nargs = '?'})

-- Add `:OR` command for organize imports of the current buffer
vim.api.nvim_create_user_command("OR", "call CocActionAsync('runCommand', 'editor.action.organizeImport')", {})

-- Add (Neo)Vim's native statusline support
-- NOTE: Please see `:h coc-status` for integrations with external plugins that
-- provide custom statusline: lightline.vim, vim-airline
vim.opt.statusline:prepend("%{coc#status()}%{get(b:,'coc_current_function','')}")

-- Mappings for CoCList
-- code actions and coc stuff
---@diagnostic disable-next-line: redefined-local
local opts = {silent = true, nowait = true}
-- Show all diagnostics
keyset("n", "<space>a", ":<C-u>CocList diagnostics<cr>", opts)
-- Manage extensions
keyset("n", "<space>e", ":<C-u>CocList extensions<cr>", opts)
-- Show commands
keyset("n", "<space>c", ":<C-u>CocList commands<cr>", opts)
-- Find symbol of current document
keyset("n", "<space>o", ":<C-u>CocList outline<cr>", opts)
-- Search workspace symbols
keyset("n", "<space>s", ":<C-u>CocList -I symbols<cr>", opts)
-- Do default action for next item
keyset("n", "<space>j", ":<C-u>CocNext<cr>", opts)
-- Do default action for previous item
keyset("n", "<space>k", ":<C-u>CocPrev<cr>", opts)
-- Resume latest coc list
keyset("n", "<space>p", ":<C-u>CocListResume<cr>", opts)
-- }}}

-- Treesitter {{{
nvim_treesitter = require('nvim-treesitter')
nvim_treesitter.install {'latex' , 'vala'}
vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
    pattern = {'*.c', '*.tex', '*.vala'},
    callback = function() vim.treesitter.start() end,
})
function print_treesitter_installed () 
    for k, v in pairs(nvim_treesitter.get_installed()) do
        print(k,v)
    end
end
-- }}} 

-- Markdown {{{
-- }}}

-- Colorizer {{{
require("colorizer").setup({
  filetypes = {
    "*",
    "!markdown",
    "!tex",
    html = { mode = "foreground" },
    cmp_docs = { always_update = true },
  },
})
-- }}}

-- Yazi {{{
require("yazi").setup({
     yazi_floating_window_border = "bold"
})
-- }}}

-- }}}

-- STAGE 3 {{{
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

-- Move cache 
-- This redues clutter in $HOME

local viminfo_dir = vim.fn.expand("~/.local/state/nvim")
if vim.fn.isdirectory(viminfo_dir) == 0 then
    vim.fn.mkdir(viminfo_dir, "p")
end
vim.opt.viminfofile = viminfo_dir .. "/nviminfo"

-- }}}

-- STAGE 4 {{{ 
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
-- }}}

-- STAGE 5 {{{
-- Telescope
vim.keymap.set('n', '<leader>ff', telescope.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>fF', 
function()
  telescope.find_files({ cwd = vim.env.HOME })
end, { desc = 'Find files in home directory' })
vim.keymap.set('n', '<leader>fg', telescope.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>fs', telescope.current_buffer_fuzzy_find, { desc = 'Telescope current buffer' })
vim.keymap.set('n', '<leader>fh', telescope.help_tags, { desc = 'Telescope help tags' })
vim.keymap.set('n', '<leader>fr', telescope.registers, { desc = 'Telescope registers' })
-- Yazi
vim.keymap.set({'n', 'v'}, '<C-g>', '<cmd>Yazi cwd<cr>', { desc = 'Open yazi in pwd' })
-- custom
vim.keymap.set({'n'}, '<leader>p','"0p' ,{ desc = 'Paste' })
vim.keymap.set({'n'}, 'gb', '<cmd>bn<cr>', { desc = 'Next buffer' })
vim.keymap.set({'n'}, 'gB', '<cmd>bp<cr>', { desc = 'Previous buffer' })
vim.keymap.set({'n'}, '<leader>gw', 
function () 
    if vim.opt.linebreak._value then vim.opt.linebreak = false
    else vim.opt.linebreak = true end
end , {desc = "Toggle linebrake"})
-- }}}
