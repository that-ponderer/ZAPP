return function()
    local bufferline = require("bufferline")
    bufferline.setup{
        options = {
            style_preset = bufferline.style_preset.minimal,
            indicator = {
                style = 'icon'
            }
        }
    }
end
