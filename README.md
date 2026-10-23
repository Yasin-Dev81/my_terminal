# my_terminal

One-command setup for my terminal: **Hyper** + **zsh** with a fast, plugin-managed shell, a starship prompt, and proper **Persian/Farsi (RTL)** text rendering.

There are two scripts:

| Script | For | Installs |
| --- | --- | --- |
| [`setup-desktop.sh`](setup-desktop.sh) | macOS (Intel / Apple Silicon), Debian / Ubuntu desktop | Hyper, fonts, Persian/RTL plugin, full zsh setup |
| [`setup-server.sh`](setup-server.sh) | Headless Debian / Ubuntu server | zsh setup only (no Hyper, no fonts) |

Both support `amd64` and `arm64`.

## Quick start

Run straight from GitHub, no clone needed.

**Desktop (macOS / Debian / Ubuntu):**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Yasin-Dev81/my_terminal/master/setup-desktop.sh)"
```

**Server (Debian / Ubuntu):**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Yasin-Dev81/my_terminal/master/setup-server.sh)"
```

If `curl` isn't installed (e.g. a minimal server), use `wget`:

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/Yasin-Dev81/my_terminal/master/setup-server.sh)"
```

Prefer to read the script before running it? Clone the repo instead:

```bash
git clone https://github.com/Yasin-Dev81/my_terminal.git
cd my_terminal
bash setup-desktop.sh   # or: bash setup-server.sh
```

> **Notes**
> - Run `setup-desktop.sh` as your **normal user**, not root. It calls `sudo` when it needs to.
> - `setup-server.sh` works as root or as a user with `sudo`.
> - You may be asked for your password (for `sudo` and for changing your login shell).

## What it sets up

### Shell (both scripts)

- **zsh** as your login shell, started through the [zflash](https://github.com/arastu/zflash) plugin manager for fast startup
- **Oh My Zsh** library + `git` plugin
- **[starship](https://starship.rs)** prompt
- **zsh-completions**, **zsh-syntax-highlighting**, **zsh-history-substring-search**, **zsh-autosuggestions**
- **conda** hook (if Anaconda / Miniconda is installed)
- **[uv](https://github.com/astral-sh/uv)** Python package manager, plus `git`, `htop` and `gcal`
- `en_US.UTF-8` locale

Config files written:

```
~/.zshrc
~/.zshenv
~/.zprofile                      # desktop, macOS only
~/.config/zflash/plugins.zsh     # list of everything the shell loads, in order
~/.zsh/options.zsh
~/.zsh/exports.zsh
~/.zsh/history.zsh
~/.zsh/completion.zsh
~/.zsh/keybindings.zsh
~/.zsh/aliases.zsh
```

### Desktop only

- **[Hyper](https://hyper.is) 3.4.1** (via Homebrew on macOS, `.deb` on Linux) with a complete `~/.hyper.js`
- **Fira Code** and **Vazirmatn** fonts
- Hyper plugins: `hyper-one-dark`, `hyper-search`, `hypercwd`, `hyper-active-tab`, `hyper-pane`
- Local plugins written to `~/.hyper_plugins/local/`:
  - **`hyper-dom-renderer`**: renders Persian/Farsi text joined and right-to-left
  - **`hyper-transparent-bg`**: makes the background slightly transparent
- On macOS, **Homebrew** is installed first if it's missing

## Aliases

| Alias | Command |
| --- | --- |
| `..`, `...`, `....` | go up 1 / 2 / 3 directories |
| `g` | `git` |
| `py`, `pip` | `python3`, `pip3` |
| `jl` | `jupyter lab` |
| `cb`, `cdx` | `conda activate base`, `conda deactivate` |
| `cal` | `gcal --starting-day=1` (calendar, week starts Monday) |
| `weather` | `curl v2.wttr.in` |
| `shtop` | `sudo htop` |
| `bup` | update and upgrade all packages (`brew` on macOS, `apt` on Linux) |
| `zshreload` | `source ~/.zshrc` |
| `rm`, `cp`, `mv` | ask before overwriting / removing (`-i`) |

## Shortcuts

| Keys | Action |
| --- | --- |
| <kbd>↑</kbd> / <kbd>↓</kbd> | search history for commands containing what you've typed |
| <kbd>⌘</kbd><kbd>⌥</kbd> + arrows | move between split panes (Hyper) |
| <kbd>⌘</kbd><kbd>⌥</kbd> + <kbd>1</kbd>–<kbd>9</kbd> | jump to pane N (Hyper) |
| <kbd>⌘</kbd><kbd>Enter</kbd> | maximize the current pane (Hyper) |
| <kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>←</kbd> / <kbd>→</kbd> | previous / next tab (Hyper) |

## After installing

1. **Desktop:** start Hyper. On first launch it downloads its npm plugins; restart it once they finish.
2. Test Persian rendering:
   ```bash
   echo "سلام دنیا، این یک متن فارسی است"
   ```
3. Log out and back in (or reconnect over SSH) so the new login shell and locale take effect.

## Customizing

- **Add or remove zsh plugins:** edit `~/.config/zflash/plugins.zsh`, then open a new tab. zflash rebuilds automatically when the file changes. Run `zflash build` to rebuild by hand (e.g. after installing conda).
- **Aliases:** `~/.zsh/aliases.zsh`
- **Hyper look and keys:** `~/.hyper.js`

## Backups and re-running

Every config file the scripts replace is first moved to `<file>.bak-<timestamp>`, e.g. `~/.zshrc.bak-20261023-142501`. To undo, move the backup back into place.

The scripts are safe to re-run: tools that are already installed (Homebrew, Hyper, Oh My Zsh, zflash, starship, uv) are skipped.
