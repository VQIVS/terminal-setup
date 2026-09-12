-- ─── ~/.config/nvim/init.lua ────────────────────────────────────────────────
-- Plugin manager: lazy.nvim (bootstrapped below, no manual install needed).
-- Theme: Catppuccin Mocha, to match ~/.vimrc and Ghostty.

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- ─── options ───────────────────────────────────────────────────────────────
local o = vim.opt
o.termguicolors = true
o.number = true
o.relativenumber = true
o.cursorline = true
o.signcolumn = "yes"
o.expandtab = true
o.tabstop = 4
o.shiftwidth = 4
o.softtabstop = 4
o.smartindent = true
o.ignorecase = true
o.smartcase = true
o.incsearch = true
o.hlsearch = true
o.mouse = "a"
o.clipboard = "unnamedplus"
o.scrolloff = 4
o.splitbelow = true
o.splitright = true
o.undofile = true
o.updatetime = 250
o.timeoutlen = 400
o.swapfile = false

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { silent = true })
vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<CR>", { desc = "File tree" })
vim.keymap.set("n", "<leader>f", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
vim.keymap.set("n", "<leader>g", "<cmd>Telescope live_grep<CR>", { desc = "Grep" })
vim.keymap.set("n", "<leader>b", "<cmd>Telescope buffers<CR>", { desc = "Buffers" })

-- ─── lazy.nvim bootstrap ───────────────────────────────────────────────────
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- theme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha", -- latte | frappe | macchiato | mocha
        transparent_background = true, -- keeps Ghostty's blur/opacity visible
        integrations = {
          treesitter = true,
          telescope = true,
          neotree = true,
          gitsigns = true,
          native_lsp = { enabled = true },
        },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { options = { theme = "catppuccin", globalstatus = true } },
  },

  -- syntax (nvim-treesitter `main` branch = current API)
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local ts = require("nvim-treesitter")
      ts.setup({})
      local langs = {
        "lua", "vim", "vimdoc", "bash", "go", "python",
        "json", "yaml", "markdown", "markdown_inline",
      }
      -- install any parser that isn't present yet (async, one-time)
      local missing = vim.tbl_filter(function(lang)
        return #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".so", false) == 0
      end, langs)
      if #missing > 0 then
        ts.install(missing)
      end
      -- turn highlighting + treesitter indent on per buffer
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
          if lang and pcall(vim.treesitter.start, args.buf, lang) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },

  -- fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },

  -- file tree
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    opts = {},
  },

  -- git gutter + misc quality of life
  { "lewis6991/gitsigns.nvim", opts = {} },
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },
  { "numToStr/Comment.nvim", opts = {} },
  { "folke/which-key.nvim", event = "VeryLazy", opts = {} },
}, {
  install = { colorscheme = { "catppuccin" } },
  checker = { enabled = false },
})
