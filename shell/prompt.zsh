# Prompt link hook for starship (zsh). Twin of prompt.ps1: keep both in sync.
# Sets the STARSHIP_* env vars that starship.toml turns into links.
# It runs before every prompt and starts no process: it reads .git files with
# zsh/mapfile. docker runs in the background.
# Source it after `eval "$(starship init zsh)"`.

zmodload zsh/mapfile

typeset -ga _starship_vars=(CWD_URI GIT_ROOT GIT_OWNER GIT_OWNER_URL GIT_REPO
    GIT_REPO_URL GIT_BRANCHES_URL GIT_TREE_URL PY_URI DOCKER)
typeset -g _starship_osc=$'\e]8;;' _starship_bel=$'\a'

# WSL: /mnt/e/x -> file:///E:/x and other paths -> file://wsl.localhost/<distro>/x,
# so Windows apps can open them. Native Linux: file:///x.
_starship_file_uri() {
    if [[ $1 =~ '^/mnt/([a-z])(/.*)?$' ]]; then
        REPLY="file:///${(U)match[1]}:${match[2]:-/}"
    elif [[ -n $WSL_DISTRO_NAME ]]; then
        REPLY="file://wsl.localhost/${WSL_DISTRO_NAME}$1"
    else
        REPLY="file://$1"
    fi
    REPLY=${REPLY// /%20}
}

_starship_links() {
    unset STARSHIP_${^_starship_vars}
    _starship_file_uri $PWD
    export STARSHIP_CWD_URI=$REPLY

    local root=$PWD
    while [[ -n $root && ! -e $root/.git ]]; do root=${root%/*}; done
    [[ -n $root ]] && _starship_git_vars $root
    _starship_python_var $PWD $root
    _starship_docker_var ${root:-$PWD}
}

_starship_git_vars() {
    local root=$1 git_dir=$1/.git line in_origin url branch
    export STARSHIP_GIT_ROOT=$root
    if [[ -f $git_dir ]]; then
        # Worktree: .git is a file that points at .git/worktrees/<name>
        git_dir=${${mapfile[$root/.git]#gitdir: }%%$'\n'*}
        [[ $git_dir =~ '^([A-Za-z]):(/.*)$' ]] && git_dir="/mnt/${(L)match[1]}${match[2]}"
        [[ $git_dir != /* ]] && git_dir=$root/$git_dir
    fi
    local common_dir=$git_dir
    [[ -f $git_dir/commondir ]] && common_dir=$git_dir/${mapfile[$git_dir/commondir]%%$'\n'*}
    [[ ${mapfile[$git_dir/HEAD]} =~ '^ref: refs/heads/([^[:space:]]+)' ]] && branch=$match[1]

    for line in "${(@f)mapfile[$common_dir/config]}"; do
        if [[ $line == '['* ]]; then
            [[ $line == '[remote "origin"]' ]] && in_origin=1 || in_origin=
        elif [[ -n $in_origin && $line =~ '^[[:space:]]*url[[:space:]]*=[[:space:]]*([^[:space:]]+)' ]]; then
            url=$match[1]
            break
        fi
    done

    if [[ $url =~ '^([a-z+]+://)?([^@/]+@)?([^/:]+)(:[0-9]+)?[:/](.+)$' ]]; then
        local web="https://$match[3]" repo_path=${${match[5]%/}%.git}
        export STARSHIP_GIT_OWNER=${repo_path%/*}
        export STARSHIP_GIT_OWNER_URL="$web/${repo_path%/*}"
        export STARSHIP_GIT_REPO=${repo_path##*/}
        export STARSHIP_GIT_REPO_URL="$web/$repo_path"
        export STARSHIP_GIT_BRANCHES_URL="$web/$repo_path/branches"
        [[ -n $branch ]] && export STARSHIP_GIT_TREE_URL="$web/$repo_path/tree/$branch"
    else
        _starship_file_uri $root
        export STARSHIP_GIT_BRANCHES_URL=$REPLY
    fi
}

_starship_python_var() {
    local venv=$VIRTUAL_ENV dir=$1 root=$2 line version
    if [[ -z $venv ]]; then
        while [[ -n $dir ]]; do
            [[ -f $dir/.venv/pyvenv.cfg ]] && { venv=$dir/.venv; break }
            [[ $dir == $root ]] && break
            dir=${dir%/*}
        done
    fi
    if [[ -z $venv ]]; then
        # No venv: link the folder of the python3 on PATH. The version comes from the
        # symlink target name (python3.11), so no python process starts.
        local exe=${commands[python3]:-$commands[python]}
        [[ -z $exe ]] && return
        _starship_file_uri ${exe:h}
        export STARSHIP_PY_URI="$REPLY#${exe:A:t}"
        return
    fi
    for line in "${(@f)mapfile[$venv/pyvenv.cfg]}"; do
        [[ $line =~ '^[[:space:]]*version(_info)?[[:space:]]*=[[:space:]]*([^[:space:]]+)' ]] && { version="#python-$match[2]"; break }
    done
    _starship_file_uri $venv
    export STARSHIP_PY_URI=$REPLY$version
}

_starship_docker_var() {
    local dir=$1 f found port links
    for f in compose.yaml compose.yml docker-compose.yml docker-compose.yaml; do
        [[ -f $dir/$f ]] && { found=1; break }
    done
    [[ -z $found ]] && return
    local cache=${TMPDIR:-/tmp}/starship-docker-${dir//[^A-Za-z0-9]/_}.txt
    local -a fresh=( $cache(Nms-10) ) busy=( $cache.lock(Nms-30) )
    if (( ! $#fresh && ! $#busy )); then
        : >| $cache.lock
        ( cd -q $dir && docker compose ps --format '{{range .Publishers}}{{if .PublishedPort}}{{.PublishedPort}} {{end}}{{end}}' 2>/dev/null \
            | tr -s ' ' '\n' | sort -nu >| $cache.tmp; mv -f $cache.tmp $cache; rm -f $cache.lock ) &!
    fi
    for port in ${(f)mapfile[$cache]}; do
        [[ -n $port ]] && links+="${_starship_osc}http://localhost:$port${_starship_bel}:$port${_starship_osc}${_starship_bel} "
    done
    export STARSHIP_DOCKER=" $links"
}

precmd_functions+=(_starship_links)

# Starship ends its %{ %} wrap at the first "m", which splits OSC 8 links
# (https://github.com...). Re-wrap every escape sequence whole.
PROMPT="${PROMPT%)} | sed -E 's/%[{}]//g; s/(\x1b\[[0-9;]*m|\x1b\]8;[^\x07]*\x07)/%{\1%}/g')"
