-- Filetype detection for Slang
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = { '*.slang', '*.slangh' },
  group = vim.api.nvim_create_augroup('slang_filetype', { clear = true }),
  callback = function()
    vim.bo.filetype = 'slang'
  end,
})
