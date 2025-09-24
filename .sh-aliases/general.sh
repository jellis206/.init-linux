# ~/.zshrc

# all purpose aliases
alias -g edz='nvim $HOME/.zshrc'
alias -g edp='nvim $HOME/.p10K.zsh'
alias -g sr='source $HOME/.zshrc'
alias -g awslogin='aws sso login'
alias -g px='pnpm exec'
alias -g pxply='pnpm exec playwright'
alias -g mmdc='npx mmdc'
alias -g vim='nvim'
alias -g nx='npx nx'
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# git aliases
alias -g gst='git status'
alias -g gcom='git commit --message'
alias -g gcam='git add . && git commit --all --message'
alias -g gco='git checkout'
alias -g gm='git merge'
alias -g grbi='git rebase --interactive'
alias -g grbc='git rebase --continue'
alias -g grba='git rebase --abort'
alias -g gush='git push'
alias -g gforp='git push --force'
alias -g gmt='git mergetool'
