-- Options are automatically loaded before lazy.nvim startup.
require("config.remote_clipboard").setup()

vim.opt.relativenumber = false
vim.g.autoformat = false

-- Allow Left/Right arrow keys and h/l to wrap across line boundaries (Normal and Insert modes)
vim.opt.whichwrap:append("<,>,h,l,[,]")
