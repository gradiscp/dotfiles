-- Render Markdown inside the editor: headings, tables, lists, code blocks,
-- links. The line under the cursor stays raw text for editing. Toggle with
-- <leader>um or :RenderMarkdown toggle. Chosen over LazyVim's lang.markdown
-- extra, which also pulls a browser preview, a linter and an LSP via Node.
return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  opts = {},
  keys = {
    { "<leader>um", "<cmd>RenderMarkdown toggle<cr>", ft = "markdown", desc = "Toggle Markdown render" },
  },
}
