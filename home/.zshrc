# Activate zoxide
eval "$(zoxide init zsh)"

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

# Auto-attach only if inside an SSH session and no tmux already
if [[ -z "$TMUX" && -t 1 ]]; then
  tat
fi


