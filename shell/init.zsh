# Shell startup for zsh (Linux, WSL). Twin of init.ps1: keep both in sync.
# Prints the banner, sets GH_USER / CLAUDE_USER / AG_USER for the prompt links,
# starts starship and loads the prompt link hook. Reads local files only: no network.
# The user values carry no spaces because they end up in URLs.
# Set STARSHIP_LINKS_QUIET=1 to skip the banner. The env vars are still set.

export STARSHIP_CONFIG=${STARSHIP_CONFIG:-${${(%):-%x}:A:h:h}/starship.toml}

zmodload zsh/datetime zsh/mapfile

_icon_github=$'\uF09B'
_icon_claude=$'\uF069'
_icon_ag=$'\U000F0AE2'
_icon_error=$'\uF00D'
_icon_term=$'\uE795'

# _banner_line <icon> <label> <text> <start time> <colour code>
_banner_line() {
    [[ $STARSHIP_LINKS_QUIET == 1 ]] && return
    printf '\e[%sm  %s  %-17s::  %s (%dms)\e[0m\n' $5 $1 $2 $3 $(( (EPOCHREALTIME - $4) * 1000 ))
}

if [[ $STARSHIP_LINKS_QUIET != 1 ]]; then
    clear
    print -P "%K{cyan}%F{black} "$'\uF31A'"  Initializing Linux Environment (%m) %f%k\n"
fi

_git_email=$(git config --global user.email 2>/dev/null)

# 1. GitHub CLI: login from gh's hosts.yml (GH_USER = login#email)
_t=$EPOCHREALTIME
unset GH_USER
if (( ! $+commands[gh] )); then
    _banner_line $_icon_error 'GitHub Account' 'Not Installed' $_t 90
elif [[ ${mapfile[${GH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/gh}/hosts.yml]} =~ $'\n[[:space:]]+user:[[:space:]]*([^[:space:]]+)' ]]; then
    export GH_USER="${match[1]}${_git_email:+#$_git_email}"
    _banner_line $_icon_github 'GitHub Account' "${match[1]}${_git_email:+ - $_git_email}" $_t 32
else
    _banner_line $_icon_error 'GitHub Account' 'Not Authenticated' $_t 31
fi

# 2. Claude CLI: email from ~/.claude.json (CLAUDE_USER = name/email)
_t=$EPOCHREALTIME
unset CLAUDE_USER
if (( ! $+commands[claude] )); then
    _banner_line $_icon_error 'Claude CLI' 'Not Installed' $_t 90
elif [[ ${mapfile[$HOME/.claude.json]} =~ '"emailAddress"[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
    export CLAUDE_USER="${match[1]%@*}/${match[1]}"
    _banner_line $_icon_claude 'Claude CLI' "${match[1]%@*} - ${match[1]}" $_t 32
else
    _banner_line $_icon_error 'Claude CLI' 'Not Authenticated' $_t 31
fi

# 3. Antigravity CLI: active account from ~/.gemini (AG_USER = name/email)
_t=$EPOCHREALTIME
unset AG_USER GEMINI_USER
if (( ! $+commands[agy] && ! $+commands[antigravity] )) && [[ ! -d $HOME/.gemini/antigravity-cli ]]; then
    _banner_line $_icon_error 'Antigravity CLI' 'Not Installed' $_t 90
else
    _ag_email=
    [[ ${mapfile[$HOME/.gemini/google_accounts.json]} =~ '"active"[[:space:]]*:[[:space:]]*"([^"]+)"' ]] && _ag_email=$match[1]
    if [[ -z $_ag_email && ( -f $HOME/.gemini/oauth_creds.json || -f $HOME/.gemini/antigravity-cli/settings.json ) ]]; then
        _ag_email=${_git_email:-$USER}
    fi
    if [[ $_ag_email == *@* ]]; then
        export AG_USER="${_ag_email%@*}/$_ag_email"
        _banner_line $_icon_ag 'Antigravity CLI' "${_ag_email%@*} - $_ag_email" $_t 32
    elif [[ -n $_ag_email ]]; then
        export AG_USER=$_ag_email
        _banner_line $_icon_ag 'Antigravity CLI' $_ag_email $_t 32
    else
        _banner_line $_icon_error 'Antigravity CLI' 'Not Authenticated' $_t 31
    fi
fi

# 4. Starship + prompt link hook
_t=$EPOCHREALTIME
# /mnt/<drive> is slow over 9p: starship's folder scan times out and warns in the prompt
export STARSHIP_LOG=error
eval "$(starship init zsh)"
source ${${(%):-%x}:A:h}/prompt.zsh
_banner_line $_icon_term 'Starship Engine' 'Ready' $_t 33
[[ $STARSHIP_LINKS_QUIET == 1 ]] || print

unset _t _git_email _ag_email
