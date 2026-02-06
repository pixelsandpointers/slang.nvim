-- slang.nvim - Neovim support for the Slang shader language
local M = {}

M.config = {
  slangd_path = nil, -- Auto-detected
  auto_format = true,
  inlay_hints = true,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  -- Auto-detect slangd path if not provided
  if not M.config.slangd_path then
    if vim.fn.executable 'slangd' == 1 then
      -- slangd is in PATH
      M.config.slangd_path = 'slangd'
    elseif vim.env.VULKAN_SDK then
      -- Fall back to Vulkan SDK
      M.config.slangd_path = vim.env.VULKAN_SDK .. '/bin/slangd'
    else
      vim.notify('slang.nvim: slangd not found in PATH and VULKAN_SDK not set. Please install Slang or set VULKAN_SDK.', vim.log.levels.ERROR)
      return
    end
  end

  -- Load modules
  require('slang.lsp').setup(M.config)
  require('slang.navigation').setup(M.config)
end

return M
