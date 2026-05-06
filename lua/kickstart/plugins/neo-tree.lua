-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

---@module 'lazy'
---@type LazySpec
return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  -- [J] Git status colors (applied after colorscheme loads so they don't get overridden)
  init = function()
    local function set_neo_tree_git_colors()
      vim.api.nvim_set_hl(0, 'NeoTreeGitModified', { fg = '#e0af68' })  -- yellow: modified/unstaged
      vim.api.nvim_set_hl(0, 'NeoTreeGitAdded', { fg = '#7aa2f7' })     -- blue: staged (new file)
      vim.api.nvim_set_hl(0, 'NeoTreeGitUntracked', { fg = '#9ece6a' }) -- green: untracked (newly added)
      vim.api.nvim_set_hl(0, 'NeoTreeGitConflict', { fg = '#f7768e' })  -- red: conflict
      vim.api.nvim_set_hl(0, 'NeoTreeGitIgnored', { fg = '#565f89' })   -- dim grey: ignored
      vim.api.nvim_set_hl(0, 'NeoTreeGitRenamed', { fg = '#e0af68' })   -- yellow: renamed
      vim.api.nvim_set_hl(0, 'NeoTreeGitDeleted', { fg = '#f7768e' })   -- red: deleted
      vim.api.nvim_set_hl(0, 'NeoTreeGitStaged', { fg = '#7aa2f7' })    -- blue: staged
    end
    set_neo_tree_git_colors()
    vim.api.nvim_create_autocmd('ColorScheme', {
      group = vim.api.nvim_create_augroup('j-neotree-git-colors', { clear = true }),
      callback = set_neo_tree_git_colors,
    })
  end,
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  ---@module 'neo-tree'
  ---@type neotree.Config
  opts = {
    -- [J] Git status colors in file tree
    highlight_git_status_colors = true,
    git_status_async = false,
    filesystem = {
      follow_current_file = { enabled = true, leave_dirs_open = true },
      bind_to_cwd = false,
      filtered_items = {
        visible = true,
        never_show = {
          'node_modules',
          'dist',
        },
      },
      window = {
        mappings = {
          ['\\'] = 'close_window',
        },
      },
    },
    default_component_configs = {
      git_status = {
        symbols = {
          modified  = '',
          renamed   = '',
          untracked = '',
          ignored   = '',
          unstaged  = '',
          staged    = '',
          conflict  = '',
        },
      },
    },
  },
}
