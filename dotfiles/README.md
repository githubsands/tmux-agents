# dotfiles

Neovim and tmux configuration used with tmux-agents.

    nvim/init.lua          -> ~/.config/nvim/init.lua
    nvim/lazy-lock.json    -> ~/.config/nvim/lazy-lock.json
    tmux/tmux.conf         -> ~/.tmux.conf
    tmux/cmds/*.sh         -> ~/.tmux/cmds/

Install:

    ln -s "$PWD/dotfiles/nvim" ~/.config/nvim
    ln -s "$PWD/dotfiles/tmux/tmux.conf" ~/.tmux.conf
    mkdir -p ~/.tmux && ln -s "$PWD/dotfiles/tmux/cmds" ~/.tmux/cmds

tmux plugins are managed by tpm, not stored here:

    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    # then inside tmux: prefix + I

The scripts in `tmux/cmds` (prefix + N, V, B) and the prefix + G / T popups
expect a practice harness at `~/cpp/compete/.game`, which is not included.
