-- LSP configuration for slangd
local M = {}

function M.setup(config)
  local slangd_path = config.slangd_path
  if not slangd_path then
    return
  end

  -- Slangd capabilities
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local has_cmp, cmp = pcall(require, 'blink.cmp')
  if has_cmp then
    capabilities = cmp.get_lsp_capabilities(capabilities)
  end

  local slangd_capabilities = vim.tbl_deep_extend('force', capabilities, {
    offsetEncoding = { 'utf-8', 'utf-16' },
    textDocument = {
      semanticTokens = vim.NIL, -- Disable (causes errors)
    },
  })

  -- Build settings
  local settings = {
    slang = {
      inlayHints = {
        deducedTypes = config.inlay_hints,
        parameterNames = config.inlay_hints,
      },
    },
  }

  -- Add Vulkan SDK search paths if using SDK
  if vim.env.VULKAN_SDK then
    settings.slang.additionalSearchPaths = {
      vim.env.VULKAN_SDK .. '/bin',
      vim.env.VULKAN_SDK .. '/lib/slang-standard-module-2026.1',
    }
  end

  -- Configure slangd
  vim.lsp.config('slangd', {
    capabilities = slangd_capabilities,
    filetypes = { 'slang', 'shaderslang' },
    cmd = { slangd_path },
    root_dir = function(bufnr, on_dir)
      local fname = vim.api.nvim_buf_get_name(bufnr)
      local root = vim.fs.root(fname, {
        '.git',
        'slangdconfig.json',
        'slang.json',
        'CMakeLists.txt',
        'Makefile',
      })
      if root then
        on_dir(root)
      else
        on_dir(vim.fn.fnamemodify(fname, ':p:h'))
      end
    end,
    settings = settings,
  })

  -- Disable semantic tokens (prevents errors with synthetic buffers)
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('slang_lsp', { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == 'slangd' then
        client.server_capabilities.semanticTokensProvider = nil
      end
    end,
  })

  vim.lsp.enable('slangd')
end

return M
