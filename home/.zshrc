eval "$(zoxide init zsh)"

# Run 'ls' every 'cd'
function chpwd() {
    emulate -L zsh
    ls -al
}

# tmux attach a session to the current directory
function tmux-attach { 
  name=$(basename `pwd` | sed -e 's/\.//g')
  if tmux ls 2>&1 | grep "$name"; then
    tmux attach -t "$name"
  elif [ -f .envrc ]; then
    direnv exec / tmux new-session -s "$name"
  else
    tmux new-session -s "$name"
  fi
}