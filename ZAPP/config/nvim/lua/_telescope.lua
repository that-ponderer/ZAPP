return function()
    local telescope = require("telescope")
    local builtin = require("telescope.builtin")

    telescope.setup({
        defaults = {
            borderchars = {
                "─", "│", "─", "│",
                "┌", "┐", "┘", "└",
            },
        },
    })

    return builtin
end
