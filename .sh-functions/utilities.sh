# ~/.zshrc

# will ask if you want to delete each swap file for the current directory
function del_swp() {
  find "$HOME/.local/state/nvim/swap" -type f -name "*$(basename "$(pwd)")*" -exec rm -i {} +
}

function aws_switch() {
  export AWS_PROFILE="$1"
  echo "AWS_PROFILE set to $AWS_PROFILE"
}
