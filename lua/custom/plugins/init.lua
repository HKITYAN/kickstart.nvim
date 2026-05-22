-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

---@module 'lazy'
---@type LazySpec
return {
  {
    'iamcco/markdown-preview.nvim',
    cmd = { 'MarkdownPreview', 'MarkdownPreviewStop', 'MarkdownPreviewToggle' },
    ft = 'markdown',
    build = 'cd app && bash install.sh',
    init = function()
      vim.g.mkdp_open_to_the_world = 1
      vim.g.mkdp_open_ip = '0.0.0.0'
      vim.g.mkdp_port = '8090'
      vim.g.mkdp_echo_preview_url = 1
      vim.g.mkdp_auto_close = 0
      vim.g.mkdp_browser = 'echo'
      vim.api.nvim_create_user_command('Md', 'MarkdownPreview', {})
    end,
  },
}
