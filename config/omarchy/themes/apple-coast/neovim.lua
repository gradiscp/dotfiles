-- Same as the stock template: aether, fed from colors.toml, so nvim follows
-- the theme's palette. (crimson-core pins ashen, which has its own colors.)
return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg = "#151921", dark_bg = "#0f131a", darker_bg = "#0a0d13", lighter_bg = "#1e232d",
        fg = "#ddd3ca", dark_fg = "#7b7a84", light_fg = "#e9e0d7", bright_fg = "#f5eee6",
        muted = "#585663",
        red = "#d6796f", yellow = "#e4bf8f", orange = "#df9c76", green = "#9cab94",
        cyan = "#85a9ae", blue = "#7f9bc0", magenta = "#b08ca3", brown = "#6b4a41",
        bright_red = "#ec9086", bright_yellow = "#f3d3a4", bright_green = "#b6c5ad",
        bright_cyan = "#a3c6cb", bright_blue = "#9db5d8", bright_magenta = "#c8a5bb",
        accent = "#d19083", cursor = "#f5eee6", foreground = "#ddd3ca",
        background = "#151921", selection = "#363043",
      },
    },
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "aether" } },
}
