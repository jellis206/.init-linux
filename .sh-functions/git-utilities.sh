# ~/.zshrc

function g() {
  git "$@"
}

gdbr() {
  # Initialize variables
  local dry_run=false
  local pattern=""

  # Define color codes
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local NC='\033[0m' # No Color

  # Check for --dry-run flag
  if [ "$1" = "--dry-run" ]; then
    dry_run=true
    shift
  fi

  # Ensure a pattern is provided
  if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage: gdbr [--dry-run] <pattern>${NC}"
    echo -e "${YELLOW}Please provide a pattern to match branch names.${NC}"
    return 1
  fi

  pattern="$1"

  # Define protected branches to prevent accidental deletion
  local protected_branches=("main" "master" "develop")

  # Fetch the list of branches matching the pattern
  # Using git for-each-ref for accurate branch listing
  local branches
  branches=$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -E "$pattern")

  # Check if any branches match the pattern
  if [ -z "$branches" ]; then
    echo -e "${YELLOW}No branches match the pattern: '$pattern'${NC}"
    return 1
  fi

  # Get the currently checked-out branch to avoid deleting it
  local current_branch
  current_branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)

  # Dry-Run Mode: List branches that would be deleted
  if [ "$dry_run" = true ]; then
    echo -e "${YELLOW}Dry Run:${NC} The following branches match the pattern '$pattern' and would be deleted:"
    while IFS= read -r branch; do
      # Skip protected branches and current branch
      if [ "$branch" = "$current_branch" ]; then
        echo -e "  ${YELLOW}[SKIPPED] Currently checked-out branch: '$branch'${NC}"
        continue
      fi
      for protected in "${protected_branches[@]}"; do
        if [ "$branch" = "$protected" ]; then
          echo -e "  ${YELLOW}[SKIPPED] Protected branch: '$branch'${NC}"
          continue 2
        fi
      done
      echo "  $branch"
    done <<<"$branches"
    return 0
  fi

  # Iterate over each matching branch using a here-string to avoid subshell issues
  while IFS= read -r branch; do
    # Skip the current branch
    if [ "$branch" = "$current_branch" ]; then
      echo -e "${YELLOW}Skipping the currently checked-out branch: '$branch'${NC}"
      continue
    fi

    # Skip protected branches
    local protected=false
    for protected_branch in "${protected_branches[@]}"; do
      if [ "$branch" = "$protected_branch" ]; then
        protected=true
        echo -e "${YELLOW}Skipping protected branch: '$branch'${NC}"
        break
      fi
    done
    if [ "$protected" = true ]; then
      continue
    fi

    # Prompt for confirmation using printf and read for POSIX compatibility
    while true; do
      printf "Are you sure you want to delete the branch '%s'? [y/N]: " "$branch"
      # Explicitly use /dev/tty to read input from the terminal
      read -r confirm </dev/tty
      case "$confirm" in
      [Yy]*)
        # Attempt to delete the branch
        if git branch -D "$branch" &>/dev/null; then
          echo -e "${GREEN}Deleted branch '$branch'.${NC}"
        else
          echo -e "${RED}Failed to delete branch '$branch'.${NC}" >&2
        fi
        break
        ;;
      [Nn]* | "")
        echo -e "${YELLOW}Skipped deletion of branch '$branch'.${NC}"
        break
        ;;
      *)
        echo -e "${YELLOW}Please answer yes or no (y/n).${NC}"
        ;;
      esac
    done
  done <<<"$branches"
}

function wt_a() {
  usage() {
    echo "Usage:"
    echo "  wt_a <branch>                # Create worktree for existing remote branch"
    echo "  wt_a <new-branch> <base>     # Create new branch off remote <base>"
    echo "  echo <branch> | wt_a         # Read branch name from stdin (no args case)"
    echo
    echo "Examples:"
    echo "  wt_a feature-login           # Creates worktree for origin/feature-login"
    echo "  wt_a feature-payments main   # Creates new branch 'feature-payments' off origin/main"
    echo "  echo feature-login | wt_a    # Same as 'wt_a feature-login' (via stdin)"
  }

  # Only run dev if we aren't in a git repo
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    dev
  fi

  git fetch --all

  # If no args, try to read branch name from stdin
  if [ $# -eq 0 ]; then
    if read -r branch; then
      set -- "$branch"
    else
      usage
      return 1
    fi
  fi

  if [ $# -eq 1 ]; then
    branch="$1"
    target="../wt/$branch"

    if [ -d "$target" ]; then
      echo "Error: worktree directory '$target' already exists."
      return 1
    fi

    echo "Creating worktree for existing branch '$branch'..."
    git worktree add "$target" "origin/$branch" || return 1
    dev "wt" "$branch"
    git checkout "$branch"

  elif [ $# -eq 2 ]; then
    new_branch="$1"
    base_branch="$2"
    target="../wt/$new_branch"

    if [ -d "$target" ]; then
      echo "Error: worktree directory '$target' already exists."
      return 1
    fi

    echo "Creating new branch '$new_branch' off 'origin/$base_branch'..."
    git worktree add -b "$new_branch" "$target" "origin/$base_branch" || return 1
    dev "wt" "$new_branch"
    git push -u origin "$new_branch"
    npm install

  else
    echo "Error: Too many arguments."
    usage
    return 1
  fi
}

function wt_r() {
  # Initialize variables
  local dry_run=false
  local pattern=""

  # Define color codes
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local NC='\033[0m' # No Color

  # Check for --dry-run flag
  if [ "$1" = "--dry-run" ]; then
    dry_run=true
    shift
  fi

  # Ensure a pattern is provided
  if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage: wt_r [--dry-run] <pattern>${NC}"
    echo -e "${YELLOW}Please provide a pattern to match worktree paths.${NC}"
    return 1
  fi

  pattern="$1"

  # List all worktrees, filter by the pattern, and extract the worktree paths
  local worktrees
  worktrees=$(git worktree list | grep "$pattern" | awk '{print $1}')

  if [ -z "$worktrees" ]; then
    echo -e "${YELLOW}No worktrees match the pattern: '$pattern'${NC}"
    return 1
  fi

  # Dry-Run Mode: List worktrees that would be removed
  if [ "$dry_run" = true ]; then
    echo -e "${YELLOW}Dry Run:${NC} The following worktrees match the pattern '$pattern' and would be removed:"
    echo "$worktrees"
    return 0
  fi

  # Loop through each worktree one at a time and ask for confirmation before removal
  while IFS= read -r wt; do
    echo -e "${YELLOW}Worktree found: $wt${NC}"
    printf "Are you sure you want to remove this worktree? [y/N]: "
    read -r confirm </dev/tty
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      if git worktree remove "$wt" &>/dev/null; then
        echo -e "${GREEN}Removed worktree: $wt${NC}"
      else
        echo -e "${RED}Failed to remove worktree: $wt${NC}" >&2
      fi
    else
      echo -e "${YELLOW}Skipped worktree: $wt${NC}"
    fi
  done <<<"$worktrees"
}
