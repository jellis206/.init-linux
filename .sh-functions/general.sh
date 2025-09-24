# ~/.zshrc

function notes() {
  local dir="$HOME/jottings"
  if [[ -n "$1" ]]; then
    dir="$dir/$1"
  fi
  mkdir -p "$dir"
  z "$dir" && nvim
}

function dev() {
  base_dir="$HOME/dev/l2l"
  if [ $# -eq 0 ]; then
    file_path="$base_dir/dispatchweb"
  elif [[ $1 = "wt" && -n $2 ]]; then
    file_path="$base_dir/wt/$2"
  else
    file_path="$base_dir/$1"
  fi
  z "$file_path"
}

brewup() {
  brew update &&
    brew upgrade &&
    brew upgrade --cask --greedy &&
    brew outdated --cask --greedy --verbose |
    grep -v '(latest)' |
      awk '{print $1}' |
      xargs brew reinstall --cask
}
