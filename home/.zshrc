eval "$(zoxide init zsh)"

## Aliases
alias update="sudo nixos-rebuild switch --flake \"$HOME/.dots#homestation\""

## Functions

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

# `services [compose-args...]`
# - With no args: cd into ~/.dots/services
# - With args: run `docker compose ...` from ~/.dots/services
function services() {
  local services_dir="$HOME/.dots/services"
  builtin cd "$services_dir" || return
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  docker compose "$@"
}