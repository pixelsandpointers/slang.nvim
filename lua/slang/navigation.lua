-- Search-based navigation for slang-synth:// synthetic buffers
local M = {}

function M.setup(config)
  local slangd_path = config.slangd_path
  if not slangd_path then
    return
  end

  -- Handle slang-synth:// URIs
  vim.api.nvim_create_autocmd('BufReadCmd', {
    pattern = 'slang-synth://*',
    group = vim.api.nvim_create_augroup('slang_synth', { clear = true }),
    callback = function(ev)
      M.load_synthetic_buffer(ev, slangd_path)
    end,
  })
end

function M.load_synthetic_buffer(ev, slangd_path)
  local uri = vim.api.nvim_buf_get_name(ev.buf)
  local module_name = uri:match('slang%-synth://([^/]+)')
  if not module_name then
    return
  end

  -- Fetch module content
  local cmd = { slangd_path, '--print-builtin-module', module_name }
  local obj = vim.system(cmd, { text = true }):wait()

  if obj.code == 0 and obj.stdout then
    -- Set up buffer
    vim.bo[ev.buf].buftype = 'nofile'
    vim.bo[ev.buf].modifiable = true
    local lines = vim.split(obj.stdout, '\n')
    vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, lines)
    vim.bo[ev.buf].modifiable = false
    vim.bo[ev.buf].buflisted = false
    vim.bo[ev.buf].filetype = 'slang'

    -- Set up navigation keybindings
    vim.schedule(function()
      M.setup_buffer_keybindings(ev.buf)

      -- Attach LSP
      local clients = vim.lsp.get_clients({ name = 'slangd' })
      if #clients > 0 then
        vim.lsp.buf_attach_client(ev.buf, clients[1].id)
      end
    end)
  else
    vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, {
      '// Error fetching module: ' .. module_name,
      '// ' .. (obj.stderr or 'Unknown error'),
    })
  end
end

function M.setup_buffer_keybindings(bufnr)
  -- Go to definition
  vim.keymap.set('n', 'gd', function()
    M.goto_definition(bufnr)
  end, { buffer = bufnr, desc = 'Go to definition' })

  -- Find references
  vim.keymap.set('n', 'gr', function()
    M.find_references(bufnr)
  end, { buffer = bufnr, desc = 'Find references' })
end

function M.goto_definition(bufnr)
  local word = vim.fn.expand('<cword>')
  if word == '' then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local matches = {}

  -- Search for definitions
  for i, line in ipairs(lines) do
    local trimmed = line:gsub('^%s+', '')
    if not trimmed:match('%f[%w]' .. word .. '%f[%W]') then
      goto continue
    end

    local match_type = 'reference'
    if trimmed:match('^struct%s+' .. word) then
      match_type = 'struct'
    elseif trimmed:match('^class%s+' .. word) then
      match_type = 'class'
    elseif trimmed:match('^interface%s+' .. word) then
      match_type = 'interface'
    elseif trimmed:match('^typedef%s+.*%s+' .. word) or trimmed:match('^typedef%s+' .. word) then
      match_type = 'typedef'
    elseif trimmed:match('^typealias%s+' .. word) then
      match_type = 'typealias'
    elseif trimmed:match('^enum%s+' .. word) then
      match_type = 'enum'
    elseif trimmed:match('%s+' .. word .. '%s*%(') or trimmed:match('^' .. word .. '%s*%(') then
      match_type = 'function'
    elseif trimmed:match('^%w+%s+' .. word .. '%s*[;=]') then
      match_type = 'variable'
    elseif trimmed:match('%s+' .. word .. '%s*:') then
      match_type = 'member'
    end

    if match_type == 'reference' and not trimmed:match('^/') then
      goto continue
    end

    table.insert(matches, {
      lnum = i,
      col = 1,
      text = trimmed:sub(1, 80),
      type = match_type,
    })

    ::continue::
  end

  if #matches == 0 then
    vim.notify('No definition found for: ' .. word, vim.log.levels.WARN)
    return
  end

  if #matches == 1 then
    vim.api.nvim_win_set_cursor(0, { matches[1].lnum, 0 })
    vim.cmd('normal! zz')
    return
  end

  -- Sort and show in picker
  M.show_matches(matches, word, bufnr)
end

function M.find_references(bufnr)
  local word = vim.fn.expand('<cword>')
  if word == '' then
    return
  end

  -- Only work on identifiers
  local ok, node = pcall(vim.treesitter.get_node)
  if ok and node then
    local node_type = node:type()
    if not (node_type:match('identifier') or node_type:match('name')) then
      return
    end
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  local references = {}

  for i, line in ipairs(lines) do
    if i ~= current_line and line:match('%f[%w]' .. word .. '%f[%W]') then
      table.insert(references, {
        lnum = i,
        col = 1,
        text = line:gsub('^%s+', ''):sub(1, 80),
      })
    end
  end

  if #references == 0 then
    vim.notify('No references found for: ' .. word, vim.log.levels.WARN)
    return
  end

  if #references == 1 then
    vim.api.nvim_win_set_cursor(0, { references[1].lnum, 0 })
    vim.cmd('normal! zz')
    return
  end

  local items = {}
  for _, ref in ipairs(references) do
    table.insert(items, {
      text = string.format('→ %d  %s', ref.lnum, ref.text),
      lnum = ref.lnum,
      col = ref.col,
      bufnr = bufnr,
    })
  end

  vim.ui.select(items, {
    prompt = string.format('References to %s (%d found):', word, #references),
    format_item = function(item)
      return item.text
    end,
  }, function(choice)
    if choice then
      vim.api.nvim_win_set_cursor(0, { choice.lnum, choice.col - 1 })
      vim.cmd('normal! zz')
    end
  end)
end

function M.show_matches(matches, word, bufnr)
  local priority = {
    struct = 1,
    class = 2,
    interface = 3,
    typedef = 4,
    typealias = 5,
    ['enum'] = 6,
    ['function'] = 7,
    variable = 8,
    member = 9,
    reference = 10,
  }

  table.sort(matches, function(a, b)
    local pa = priority[a.type] or 10
    local pb = priority[b.type] or 10
    if pa == pb then
      return a.lnum < b.lnum
    end
    return pa < pb
  end)

  local items = {}
  for _, match in ipairs(matches) do
    local icon = match.type == 'reference' and '→' or '●'
    table.insert(items, {
      text = string.format('%s %d  %s', icon, match.lnum, match.text),
      lnum = match.lnum,
      col = match.col,
      bufnr = bufnr,
    })
  end

  vim.ui.select(items, {
    prompt = 'Select definition for ' .. word .. ':',
    format_item = function(item)
      return item.text
    end,
  }, function(choice)
    if choice then
      vim.api.nvim_win_set_cursor(0, { choice.lnum, choice.col - 1 })
      vim.cmd('normal! zz')
    end
  end)
end

return M
