-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ 
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        lazyrepo,
        lazypath
  })
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

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- The GOAT
    { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
    -- A Status line
    { 'nvim-lualine/lualine.nvim',dependencies = {'nvim-tree/nvim-web-devicons'}},
    -- A Top Bar To Show Active Buffers
    {'akinsho/bufferline.nvim', 
        version = "*",
        dependencies = 'nvim-tree/nvim-web-devicons'
    },
    -- Extremely Fast Fuzzy Finder
    {'nvim-telescope/telescope.nvim',
        version = '*',
        dependencies = {
            'nvim-lua/plenary.nvim',
            {'nvim-telescope/telescope-fzf-native.nvim', build = 'make' }
        }
    },
    -- Surround Any Word, Line, Block With Anything
    {"kylechui/nvim-surround",version = "^4.0.0",event = "VeryLazy",},
    -- Stop Manually Typing Every Parens
    {'windwp/nvim-autopairs',event = "InsertEnter",config = true},
    -- Integrates The Best File Manager Ever
    {"mikavilpas/yazi.nvim",
        version = "*",
        event = "VeryLazy",
        dependencies = {
            { "nvim-lua/plenary.nvim", lazy = true }
        },
    },
    -- Outclasses every IDE By A LongShot
    {'neoclide/coc.nvim', branch = 'release', },
    -- Syntax aware highlights
    {'nvim-treesitter/nvim-treesitter',lazy = false,build = ':TSUpdate'},
    -- Forget Your Note Taker
    {'MeanderingProgrammer/render-markdown.nvim',
        dependencies = { 
            'nvim-treesitter/nvim-treesitter', 
            'nvim-tree/nvim-web-devicons' 
        }
    },
    -- Displayes Color Priviews
    {"catgoose/nvim-colorizer.lua",
        event = "BufReadPre"
    }
  },
  ui = {
    border = "bold"
  },
})
