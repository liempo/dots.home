# Activate zoxide
eval "$(zoxide init zsh)"

# Load fzf
source <(fzf --zsh)

# Run 'ls' every 'cd'
function chpwd() {
    emulate -L zsh
    ls -al
}

#  tmux attach or create session
function tat {
  name=$(basename `pwd` | sed -e 's/\.//g')
  if tmux ls 2>&1 | grep "$name"; then
    tmux attach -t "$name"
  elif [ -f .envrc ]; then
    direnv exec / tmux new-session -s "$name"
  else
    tmux new-session -s "$name"
  fi
}

# automatically attach tmux with zoxide
function ztat {
  z $1
  tat
}
