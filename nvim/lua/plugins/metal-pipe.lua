return {
  'pavlo-skobnikov/metal-pipe.nvim',
  event = 'VeryLazy',
  config = function()
    vim.keymap.set('n', '<leader>nc', function()
      require('metal-pipe').play_sound('~/.config/nvim/sounds/-click-nice_3.mp3')
    end)
    vim.keymap.set('n', '<leader>ok', function()
      require('metal-pipe').play_sound('~/.config/nvim/sounds/my-song-2_2.mp3')
    end)
    vim.keymap.set('n', '<leader>lt', function()
      require('metal-pipe').play_sound('~/.config/nvim/sounds/let-me-tell-you-something.mp3')
    end)
    vim.keymap.set('n', '<leader>bd', function()
      require('metal-pipe').play_sound('~/.config/nvim/sounds/joke_drum_effect.mp3')
    end)
  end
}
