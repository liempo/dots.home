return {
  { -- Commentary
    'tpope/vim-commentary',
    config = function()
      vim.cmd([[autocmd FileType swift setlocal commentstring=//\ %s]])
    end
  },

  { -- Context based comments
    'JoosepAlviste/nvim-ts-context-commentstring'
  },

  { -- Surround
    'tpope/vim-surround'
  }

}
