-- Basic editor settings
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.scrolloff = 8
vim.opt.updatetime = 250

-- Neovim only knows .cu/.cuh as CUDA; .cuda would otherwise fall back to "conf"
vim.filetype.add({ extension = { cuda = "cuda" } })

-- ww leaves insert mode; Esc is disabled there
vim.keymap.set("i", "ww", "<Esc>")
vim.keymap.set("i", "<Esc>", "<Nop>")

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- LSP, formatters & linters via mason
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = { "rust_analyzer", "ts_ls", "lua_ls" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "hrsh7th/cmp-nvim-lsp", "mason-lspconfig.nvim" },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- rust-analyzer comes from `rustup component add rust-analyzer`
      -- (proxied via /opt/homebrew/opt/rustup/bin), mason install acts as a fallback.
      vim.lsp.config("rust_analyzer", {
        capabilities = capabilities,
        settings = {
          ["rust-analyzer"] = {
            cargo = { allFeatures = true },
            checkOnSave = true,
            check = { command = "clippy" },
          },
        },
      })
      vim.lsp.config("ts_ls", { capabilities = capabilities })
      vim.lsp.config("lua_ls", { capabilities = capabilities })
      -- clangd comes from the Xcode Command Line Tools (/usr/bin/clangd).
      -- CUDA flags for .cu/.cuh live in ~/Library/Preferences/clangd/config.yaml.
      -- --query-driver lets a project's .clangd (`CompileFlags: Compiler: g++-16`) pull in
      -- Homebrew GCC's libstdc++ headers, e.g. for std::views::enumerate.
      vim.lsp.config("clangd", {
        capabilities = capabilities,
        filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
        -- --completion-style=bundled shows one entry per name; overloads appear in signature help after `(`.
        cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu", "--limit-results=0",
          "--completion-style=bundled", "--function-arg-placeholders",
          "--query-driver=/opt/homebrew/bin/g++-*" },
      })

      -- Inline type hints, e.g. `auto d = hs.erase(4)` shows `: size_type` after `d`.
      -- Toggle with <leader>ih.
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
          end
        end,
      })
      vim.keymap.set("n", "<leader>ih", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
      end)

      vim.lsp.enable({ "rust_analyzer", "ts_ls", "lua_ls", "clangd" })

      vim.keymap.set("n", "gd", vim.lsp.buf.definition)
      vim.keymap.set("n", "K", function() vim.lsp.buf.hover({ border = "rounded" }) end)
      -- Signature + docs for the call under the cursor (also pops up automatically via cmp, see below).
      vim.keymap.set({ "n", "i" }, "<C-k>", function() vim.lsp.buf.signature_help({ border = "rounded" }) end)
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename)
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action)
      vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)
    end,
  },

  -- Autocompletion
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-nvim-lsp-signature-help" },
    config = function()
      local cmp = require("cmp")

      -- C++ standard library headers; inside `#include <...>` only these are offered.
      local std_headers = {}
      for _, h in ipairs({
        -- C++ library
        "algorithm", "any", "array", "atomic", "barrier", "bit", "bitset", "charconv",
        "chrono", "codecvt", "compare", "complex", "concepts", "condition_variable",
        "coroutine", "debugging", "deque", "exception", "execution", "expected",
        "filesystem", "flat_map", "flat_set", "format", "forward_list", "fstream",
        "functional", "future", "generator", "hazard_pointer", "initializer_list",
        "inplace_vector", "iomanip", "ios", "iosfwd", "iostream", "istream", "iterator",
        "latch", "limits", "linalg", "list", "locale", "map", "mdspan", "memory",
        "memory_resource", "mutex", "new", "numbers", "numeric", "optional", "ostream",
        "print", "queue", "random", "ranges", "ratio", "rcu", "regex", "scoped_allocator",
        "semaphore", "set", "shared_mutex", "simd", "source_location", "span", "spanstream",
        "sstream", "stack", "stacktrace", "stdexcept", "stdfloat", "stop_token",
        "streambuf", "string", "string_view", "syncstream", "system_error", "text_encoding",
        "thread", "tuple", "type_traits", "typeindex", "typeinfo", "unordered_map",
        "unordered_set", "utility", "valarray", "variant", "vector", "version",
        -- C compatibility
        "cassert", "cctype", "cerrno", "cfenv", "cfloat", "cinttypes", "climits",
        "clocale", "cmath", "csetjmp", "csignal", "cstdarg", "cstddef", "cstdint",
        "cstdio", "cstdlib", "cstring", "ctime", "cuchar", "cwchar", "cwctype",
      }) do
        std_headers[h] = true
      end

      local function lsp_entry_filter(entry, ctx)
        if not ctx.cursor_before_line:match("^%s*#%s*include%s*<") then
          return true
        end
        local item = entry:get_completion_item()
        local name = (item.filterText or item.label or ""):gsub("^%s+", ""):gsub(">$", "")
        return std_headers[name] == true
      end

      cmp.setup({
        -- Expand LSP snippets (e.g. template args, function params) with Neovim's built-in engine.
        snippet = {
          expand = function(args)
            vim.snippet.expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
          ["<C-d>"] = cmp.mapping.scroll_docs(4),
          ["<C-u>"] = cmp.mapping.scroll_docs(-4),
        }),
        -- Bordered menu + side docs panel (doxygen @brief/@return from libstdc++ headers).
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered({ max_width = 80, max_height = 30 }),
        },
        -- Show the return type / signature (clangd's `detail`) in the menu next to each item.
        formatting = {
          fields = { "abbr", "kind", "menu" },
          format = function(entry, item)
            local detail = entry:get_completion_item().detail
            if detail and detail ~= "" then
              item.menu = #detail > 50 and detail:sub(1, 49) .. "…" or detail
            end
            return item
          end,
        },
        sources = {
          { name = "nvim_lsp_signature_help" },
          { name = "nvim_lsp", entry_filter = lsp_entry_filter },
        },
      })
    end,
  },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    opts = {
      ensure_installed = { "rust", "typescript", "tsx", "lua", "go", "bash", "c", "cpp", "cuda", "cmake" },
      highlight = { enable = true },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  -- File explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup()
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>")
    end,
  },

  -- Fuzzy finder (uses fzf installed via brew)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-file-browser.nvim",
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        extensions = {
          file_browser = {
            hijack_netrw = true,
            grouped = true,
            mappings = {
              i = { ["vv"] = require("telescope.actions").close },
              n = { ["vv"] = require("telescope.actions").close },
            },
          },
        },
      })
      telescope.load_extension("file_browser")

      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files)
      vim.keymap.set("n", "<leader>fg", builtin.live_grep)
      vim.keymap.set("n", "<leader><leader>", ":Telescope file_browser<CR>")
      vim.keymap.set("n", "<leader>fd", ":Telescope file_browser path=%:p:h select_buffer=true<CR>")
    end,
  },

  -- Statusline
  { "nvim-lualine/lualine.nvim", config = true },

  -- Colorscheme
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight")
    end,
  },
})

-- :Cpp (or :cpp) -- save, compile the current file with the compete toolchain
-- (same compiler/flags as ~/cpp/compete/.game/bin/common.sh), then run it.
-- Errors go to the quickfix list; extra args are passed to the program.
vim.api.nvim_create_user_command("Cpp", function(o)
  vim.cmd("write")
  local src = vim.fn.expand("%:p")
  local exe = vim.fn.expand("%:p:r")
  local cmd = {
    "/opt/homebrew/bin/g++-16", "-std=c++23", "-O0", "-g",
    "-Wall", "-Wextra", "-Wno-unused-parameter",
    "-I/Users/grace/cpp/compete/.game", src, "-o", exe,
  }
  local res = vim.system(cmd, { text = true }):wait()
  local out = (res.stderr or "") .. (res.stdout or "")
  vim.fn.setqflist({}, "r", { title = "g++-16", lines = vim.split(out, "\n", { trimempty = true }),
    efm = "%f:%l:%c: %t%*[^:]: %m,%f:%l: %t%*[^:]: %m,%-G%.%#" })
  if res.code ~= 0 then
    vim.notify("compile failed", vim.log.levels.ERROR)
    vim.cmd("copen")
    return
  end
  if out ~= "" then vim.cmd("copen") else vim.cmd("cclose") end
  vim.cmd("botright 15split | terminal " .. vim.fn.shellescape(exe) .. " " .. o.args)
  vim.cmd("startinsert")
end, { nargs = "*", desc = "Compile & run current C++ file with g++-16 -std=c++23" })
vim.cmd([[cnoreabbrev <expr> cpp getcmdtype() == ':' && getcmdline() ==# 'cpp' ? 'Cpp' : 'cpp']])
