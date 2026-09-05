return function()

local nvim_treesitter = require('nvim-treesitter')
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

end
