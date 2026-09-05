return function()
    local remap = vim.api.nvim_set_keymap
    local npairs = require('nvim-autopairs')
    npairs.setup({map_cr=false})

    -- skip it, if you use another global object
    _G.MUtils= {}

    -- new version for custom pum
    MUtils.completion_confirm=function()
        if vim.fn["coc#pum#visible"]() ~= 0  then
            return vim.fn["coc#pum#confirm"]()
        else
            return npairs.autopairs_cr()
        end
    end

    remap(
        'i' ,
        '<CR>',
        'v:lua.MUtils.completion_confirm()',
        {expr = true , noremap = true}
    )
end
