# starship-links

A [Starship](https://starship.rs) powerline prompt where the segments are links.
Ctrl+click (Cmd+click on macOS) a segment to open the folder, the repo, the
branch, the Python venv, or a running Docker port.

One `starship.toml` serves PowerShell 7 on Windows and zsh on Linux and WSL.
On WSL, you can share one copy with Windows.

## What each segment does

| Segment | Click opens | Hover shows |
|---|---|---|
| Folder | The folder in your file manager (Explorer for WSL paths too) | The full path |
| GitHub icon | Your GitHub profile | Your login and git email |
| `owner` | The owner page on the git host | |
| `repo` | The repository | |
| Branch icon | The branch list | |
| Branch name | The branch on the git host | |
| Python | The venv folder, or the folder of the `python` on PATH | The Python version |
| Node, Rust, Go and others | The language docs | The version |
| Claude | claude.ai | The signed-in account |
| Docker `:5173` | `http://localhost:5173`, one link per published compose port | |
| Antigravity | antigravity.google | The signed-in account |

Segments show only when they apply. For example, the git part appears only
inside a repo, and Docker appears only in a folder with a compose file.

## Requirements

- Starship. Tested with 1.26.
- A [Nerd Font](https://www.nerdfonts.com) as the terminal font.
- A terminal that supports OSC 8 links: Windows Terminal, the VS Code terminal,
  WezTerm, iTerm2, Kitty or GNOME Terminal.
- PowerShell 7 on Windows, or zsh on Linux and WSL.
- Optional: `gh`, `docker`, and the Claude or Antigravity CLIs, for their segments.

## Install

### Windows (PowerShell 7)

1. Clone the repo:

   ```powershell
   git clone https://github.com/ricardowong/starship-links "$HOME\.config\starship-links"
   ```

2. Open your profile with `notepad $PROFILE`.
3. Remove any existing `starship init powershell` line.
4. Add this line:

   ```powershell
   . "$HOME\.config\starship-links\shell\init.ps1"
   ```

5. Open a new terminal.

### Linux (zsh)

1. Clone the repo:

   ```sh
   git clone https://github.com/ricardowong/starship-links ~/.config/starship-links
   ```

2. Remove any existing `starship init zsh` line from `~/.zshrc`.
3. Add this line to `~/.zshrc`:

   ```sh
   source ~/.config/starship-links/shell/init.zsh
   ```

4. Open a new terminal.

### WSL, sharing the Windows copy

Do the Windows install first. Then add this line to `~/.zshrc` in WSL, with your
Windows user name:

```sh
source /mnt/c/Users/<you>/.config/starship-links/shell/init.zsh
```

A change to the repo then applies to both shells.

## Themes

Every palette maps the same color roles, so a theme switch is one line in
`starship.toml`:

```toml
palette = 'high_contrast'
```

| Palette | Style |
|---|---|
| `high_contrast` (default) | Light and dark segments alternate, so every border is visible by lightness and not only by hue |
| `catppuccin_mocha` | Pastel |
| `tokyo_night` | Cool blues with neon accents |
| `gruvbox_dark` | Warm and earthy |

Every palette keeps text at 7:1 contrast or more on its segment (WCAG AAA).
Only `high_contrast` also separates neighboring segments by lightness.

To see all palettes on your own prompt, run the preview from inside a git repo:

```powershell
pwsh -File "$HOME\.config\starship-links\tools\preview-themes.ps1"
```

```sh
zsh ~/.config/starship-links/tools/preview-themes.zsh
```

If you add or change a palette, check it:

```sh
python tools/contrast.py starship.toml
```

## Options

| Variable | Effect |
|---|---|
| `STARSHIP_LINKS_QUIET=1` | Skips the startup banner and the screen clear. The links still work. |
| `STARSHIP_CONFIG` | Uses a different `starship.toml`. The init scripts set it to the repo copy only if it is empty. |

Set them before the `init` line.

## How it works

Starship cannot run code, so a small hook runs before every prompt:
`shell/prompt.ps1` in PowerShell, `shell/prompt.zsh` in zsh. The hook sets the
`STARSHIP_*` environment variables listed at the top of `starship.toml`. The
config then turns them into OSC 8 links with `env_var` modules.

- The hook starts no processes. It reads `.git/HEAD` and `.git/config`
  directly, worktrees included, because each `git` or `python` start costs
  80 to 300 ms on Windows.
- `docker compose ps` runs in the background every 10 seconds. The ports
  therefore appear one prompt after you enter a compose project.
- The startup banner reads local files only: `gh`'s `hosts.yml`, `~/.claude.json`
  and `~/.gemini`. It makes no network calls.
- zsh measures the prompt width from `%{ %}` markers. Starship ends a marker at
  the first `m`, which cuts URLs such as `github.com` in half. `prompt.zsh`
  marks every escape sequence again so the cursor stays in place.
- On WSL, `git status` on `/mnt/<drive>` paths is slow. `git_status.windows_starship`
  hands it to the Windows binary. If you installed Starship somewhere other than
  `C:\Program Files\starship`, change that path.

The two shells have one hook each, which do the same job. If you change one,
change the other.

## Limits

- A link can only open a URL or a file. It cannot run a command in your shell.
- The account names on hover come from the URL fragment (`#...`). The website
  ignores the fragment.

## Uninstall

1. Remove the `init` line from your profile or `~/.zshrc`.
2. Delete the `starship-links` folder.

## License

MIT
