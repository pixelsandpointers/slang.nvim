# slang.nvim

Neovim plugin for the [Slang](https://github.com/shader-slang/slang) shader language.

## Features

- **Fixed LSP support** via slangd (code completion, diagnostics, hover)
- **Core library navigation** - Browse and search Slang's standard library (`slang-synth://` URIs)
- **Go to definition** - Jump to definitions in your code and the Slang core library
- **Find references** - Search-based reference finding in synthetic buffers

## Requirements

- Neovim ≥ 0.11
- [slangd](https://github.com/shader-slang/slang) (from Vulkan SDK or Slang distribution)
- `VULKAN_SDK` environment variable set (or configure manually)
- Optional: [blink.cmp](https://github.com/saghen/blink.cmp) for completion

## Installation

### lazy.nvim

```lua
{
  'pixelsandpointers/slang.nvim',
  dependencies = {
    'neovim/nvim-lspconfig',
    'nvim-treesitter/nvim-treesitter',
  },
  opts = {
    -- slangd_path = '/path/to/vulkan-sdk/x86_64',
    auto_format = true,
    inlay_hints = true,
  },
}
```

### Manual

```lua
require('slang').setup({
  -- slangd_path = '/path/to/vulkan-sdk/x86_64',
  auto_format = true,
  inlay_hints = true,
})
```

## Usage

### Keybindings (in synthetic buffers)

- `gd` - Go to definition (shows picker with definitions sorted first)
- `gr` - Find references (only works on identifiers, not keywords)

### Jump to Core Library

When you use LSP "go to definition" on a Slang standard library function (like `TraceRay`), it will:
1. Open the core library source code in a read-only buffer
2. Jump to the definition
3. Allow you to navigate within the library using `gd` and `gr`

## Configuration

```lua
require('slang').setup({
  -- Path to slangd or Vulkan SDK (searches for both in path) 
  -- slangd_path = '/path/to/vulkan-sdk/x86_64',

  -- Enable auto-formatting on save (requires conform.nvim)
  auto_format = true,

  -- Enable inlay hints for types and parameters
  inlay_hints = true,
})
```

## Treesitter

The plugin automatically installs the Slang treesitter parser. If you want to configure it manually:

```lua
require('nvim-treesitter.configs').setup({
  ensure_installed = { 'slang' },
})
```

## How It Works
### Synthetic Buffers

Slang's core library is distributed as precompiled code, but slangd provides a way to view the source via `--print-builtin-module`. This plugin:

1. Intercepts `slang-synth://` URIs returned by slangd
2. Fetches the module source using `slangd --print-builtin-module <name>`
3. Creates a read-only buffer with the content
4. Provides search-based navigation since LSP features don't work in synthetic buffers

### Search-Based Navigation

In synthetic buffers, the plugin implements smart search-based navigation:
- Recognizes common patterns (struct, class, function, typedef, etc.)
- Sorts results by type (definitions first, then references)
- Filters out keywords using Tree-sitter
- Shows results in a picker for easy selection

## Troubleshooting
### Semantic tokens errors
The plugin automatically disables semantic tokens for slangd due to known issues with synthetic buffers. You'll still have Tree-sitter syntax highlighting.

## Credits
Developed for the Slang shader language community. Contributions welcome!

## License
MIT
