return function()
    require("colorizer").setup({
      filetypes = {
        "*",
        "!markdown",
        "!tex",
        html = { mode = "foreground" },
        cmp_docs = { always_update = true },
      },
    })
end

