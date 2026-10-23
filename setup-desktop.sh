#!/usr/bin/env bash
#
# setup-desktop.sh — reproduce the Hyper + zsh terminal setup on a desktop machine.
#
# Supported: macOS (Intel / Apple Silicon) and Debian / Ubuntu desktop (amd64 / arm64).
# For a headless server (zsh only, no Hyper or fonts) use setup-server.sh.
#
# What it sets up:
#   - Hyper 3.4.1 with the full ~/.hyper.js config (theme, colors, plugins)
#   - The local "hyper-dom-renderer" plugin that renders Persian/Farsi text
#     joined and right-to-left, and "hyper-transparent-bg", which makes the
#     background slightly transparent
#   - Fira Code + Vazirmatn fonts
#   - zsh, started through the zflash plugin manager (github.com/arastu/zflash):
#     Oh My Zsh's library + git plugin, starship prompt, zsh-completions,
#     syntax highlighting, history substring search and autosuggestions
#   - ~/.zshrc, ~/.zshenv, ~/.zprofile, ~/.config/zflash/plugins.zsh and
#     ~/.zsh/{options,exports,history,completion,keybindings,aliases}.zsh
#   - uv (Python package manager), installed to ~/.local/bin on Linux
#   - en_US.UTF-8 locale
#
# Usage:  bash setup-desktop.sh
#
# Existing config files are backed up as <file>.bak-<timestamp> before being replaced.

set -euo pipefail

HYPER_VERSION="3.4.1"
VAZIRMATN_VERSION="v33.003"
STAMP="$(date +%Y%m%d-%H%M%S)"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# Move an existing file out of the way before writing a new one.
backup() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    mv "$1" "$1.bak-$STAMP"
    info "Backed up $1 -> $1.bak-$STAMP"
  fi
}

# ---------------------------------------------------------------------------
# Detect OS
# ---------------------------------------------------------------------------
case "$(uname -s)" in
  Darwin) OS=mac ;;
  Linux)
    if command -v apt-get >/dev/null 2>&1; then
      OS=debian
    else
      die "Only Debian/Ubuntu (apt) Linux distributions are supported."
    fi
    ;;
  *) die "Unsupported OS: $(uname -s)" ;;
esac

case "$(uname -m)" in
  x86_64|amd64)  ARCH=amd64 ;;
  arm64|aarch64) ARCH=arm64 ;;
  *) die "Unsupported CPU architecture: $(uname -m)" ;;
esac

info "Detected $OS ($ARCH)"

if [ "$(id -u)" -eq 0 ]; then
  die "Run this script as your normal user, not root. It will use sudo when needed."
fi

# ---------------------------------------------------------------------------
# Packages, Hyper, fonts
# ---------------------------------------------------------------------------
install_mac() {
  if ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  info "Installing command-line tools"
  brew install git starship gcal htop uv

  info "Installing fonts"
  brew install --cask font-fira-code font-vazirmatn

  if [ -d /Applications/Hyper.app ]; then
    info "Hyper is already installed"
  else
    info "Installing Hyper"
    brew install --cask hyper
  fi
}

install_debian() {
  info "Installing packages with apt"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    zsh git curl unzip ca-certificates locales fontconfig fonts-firacode gcal htop

  info "Enabling the en_US.UTF-8 locale"
  sudo sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen || echo 'en_US.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen >/dev/null
  sudo locale-gen

  info "Installing the Vazirmatn font"
  if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fonts-vazirmatn 2>/dev/null; then
    local tmp fontdir="$HOME/.local/share/fonts/vazirmatn"
    tmp="$(mktemp -d)"
    curl -fL -o "$tmp/vazirmatn.zip" \
      "https://github.com/rastikerdar/vazirmatn/releases/download/$VAZIRMATN_VERSION/vazirmatn-$VAZIRMATN_VERSION.zip"
    unzip -q "$tmp/vazirmatn.zip" -d "$tmp/vazirmatn"
    mkdir -p "$fontdir"
    find "$tmp/vazirmatn" -path '*fonts/ttf/*' -name 'Vazirmatn-*.ttf' -exec cp {} "$fontdir/" \;
    rm -rf "$tmp"
  fi
  fc-cache -f >/dev/null

  if ! command -v starship >/dev/null 2>&1; then
    info "Installing starship"
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y
  fi

  if ! command -v uv >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/uv" ]; then
    info "Installing uv"
    # ~/.local/bin is already on PATH via ~/.zshenv; don't let it edit rc files.
    curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
  fi

  if command -v hyper >/dev/null 2>&1 || [ -x /opt/Hyper/hyper ]; then
    info "Hyper is already installed"
  else
    info "Installing Hyper $HYPER_VERSION"
    local deb
    deb="$(mktemp -d)/hyper.deb"
    curl -fL -o "$deb" "https://github.com/vercel/hyper/releases/download/v$HYPER_VERSION/hyper_${HYPER_VERSION}_${ARCH}.deb"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$deb"
    rm -f "$deb"
  fi
}

if [ "$OS" = mac ]; then install_mac; else install_debian; fi

# ---------------------------------------------------------------------------
# Oh My Zsh
# ---------------------------------------------------------------------------
if [ -d "$HOME/.oh-my-zsh" ]; then
  info "Oh My Zsh is already installed"
else
  info "Installing Oh My Zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# ---------------------------------------------------------------------------
# zflash (zsh plugin manager)
# ---------------------------------------------------------------------------
ZFLASH_DIR="$HOME/.local/share/zflash/zflash"
if [ -d "$ZFLASH_DIR/.git" ]; then
  info "zflash is already installed"
else
  info "Installing zflash"
  mkdir -p "$(dirname "$ZFLASH_DIR")"
  git clone --quiet --depth=1 https://github.com/arastu/zflash.git "$ZFLASH_DIR"
fi
mkdir -p "$HOME/.cache/zflash"

# ---------------------------------------------------------------------------
# Hyper config
# ---------------------------------------------------------------------------
info "Writing ~/.hyper.js"
backup "$HOME/.hyper.js"
cat > "$HOME/.hyper.js" <<'EOF'
"use strict";
// See https://hyper.is#cfg for all supported options.
module.exports = {
    config: {
        updateChannel: 'stable',
        fontSize: 16,
        // Vazirmatn supplies the Persian glyphs that Fira Code lacks.
        fontFamily: '"Fira Code", "Vazirmatn", Menlo, "DejaVu Sans Mono", Consolas, "Lucida Console", monospace',
        fontWeight: 'normal',
        fontWeightBold: 'bold',
        lineHeight: 1,
        letterSpacing: 0,
        activeTab: '🚀',
        cursorColor: 'rgba(248,28,229,0.8)',
        cursorAccentColor: '#000',
        cursorShape: 'BLOCK',
        cursorBlink: false,
        foregroundColor: '#fff',
        backgroundColor: '#000',
        selectionColor: 'rgba(248,28,229,0.3)',
        borderColor: '#333',
        css: '',
        termCSS: '',
        workingDirectory: '',
        showHamburgerMenu: '',
        showWindowControls: 'top right',
        padding: '12px 14px',
        colors: {
            black: '#000000',
            red: '#C51E14',
            green: '#1DC121',
            yellow: '#C7C329',
            blue: '#0A2FC4',
            magenta: '#C839C5',
            cyan: '#20C5C6',
            white: '#C7C7C7',
            lightBlack: '#686868',
            lightRed: '#FD6F6B',
            lightGreen: '#67F86F',
            lightYellow: '#FFFA72',
            lightBlue: '#6A76FB',
            lightMagenta: '#FD7CFC',
            lightCyan: '#68FDFE',
            lightWhite: '#FFFFFF',
            limeGreen: '#32CD32',
            lightCoral: '#F08080',
        },
        shell: 'zsh',
        shellArgs: ['--login'],
        env: { LANG: 'en_US.UTF-8', LC_ALL: 'en_US.UTF-8' },
        bell: 'SOUND',
        copyOnSelect: true,
        defaultSSHApp: true,
        quickEdit: false,
        macOptionSelectionMode: 'force',
        webGLRenderer: false,
        webLinksActivationKey: '',
        disableLigatures: true,
        disableAutoUpdates: false,
        screenReaderMode: false,
        preserveCWD: true,
        // hyper-pane: move between split panes by direction (Cmd+Alt+arrows),
        // jump to pane N (Cmd+Alt+1-9), swap panes (add Shift), maximize (Cmd+Enter)
        paneNavigation: {
            hotkeys: {
                navigation: {
                    up: 'meta+alt+up',
                    down: 'meta+alt+down',
                    left: 'meta+alt+left',
                    right: 'meta+alt+right'
                },
                jump_prefix: 'meta+alt',
                permutation_modifier: 'shift',
                maximize: 'meta+enter'
            },
            showIndicators: true,
            indicatorPrefix: '⌘⌥',
            focusOnMouseHover: false,
            inactivePaneOpacity: 0.6
        },
    },
    // Installed from npm automatically the first time Hyper starts.
    plugins: [
        "hyper-one-dark",
        "hyper-search",
        "hypercwd",
        "hyper-active-tab",
        "hyper-pane"
    ],
    // Loaded from ~/.hyper_plugins/local/
    localPlugins: ["hyper-dom-renderer", "hyper-transparent-bg"],
    keymaps: {
        // Hyper's defaults also bind Cmd+Alt+Left/Right to switching tabs; drop
        // those so they move between panes (hyper-pane). Tabs keep Cmd+Shift+arrows.
        'tab:next': ['cmd+shift+]', 'cmd+shift+right', 'ctrl+tab'],
        'tab:prev': ['cmd+shift+[', 'cmd+shift+left', 'ctrl+shift+tab'],
    },
};
EOF

# ---------------------------------------------------------------------------
# Persian/RTL rendering plugin
# ---------------------------------------------------------------------------
PLUGIN_DIR="$HOME/.hyper_plugins/local/hyper-dom-renderer"
info "Writing the hyper-dom-renderer plugin"
mkdir -p "$PLUGIN_DIR"

cat > "$PLUGIN_DIR/package.json" <<'EOF'
{ "name": "hyper-dom-renderer", "version": "1.0.0", "main": "index.js" }
EOF

cat > "$PLUGIN_DIR/index.js" <<'EOF'
// Make Persian/Arabic text render joined and right-to-left in Hyper.
//
// 1. Switch xterm.js from the per-cell canvas renderer to the DOM renderer, so
//    text is laid out by the browser engine.
// 2. xterm's DOM renderer still draws every cell as a fixed-width inline-block,
//    which blocks letter joining and BiDi reordering. Override that so cells
//    flow as normal inline text. (Hyper's termCSS doesn't reach the DOM
//    renderer's rows, so the style is injected into the page directly.)
const TAG = '[hyper-dom-renderer]';
const STYLE_ID = 'hyper-dom-renderer-style';
const CSS = `
  /* Keep runs of spaces intact once cells are plain inline text. */
  .xterm-rows > div {
    white-space: pre !important;
  }
  .xterm-rows span {
    display: inline !important;
    width: auto !important;
  }
  /* The cursor is usually a space at the end of the line, which collapses to
     zero width as inline text, so keep it a cell-sized block. */
  .xterm-rows span.xterm-cursor {
    display: inline-block !important;
    min-width: 1ch;
    white-space: pre;
  }
`;

function injectStyle() {
  if (document.getElementById(STYLE_ID)) return;
  const style = document.createElement('style');
  style.id = STYLE_ID;
  style.textContent = CSS;
  document.head.appendChild(style);
}

// Other plugins may wrap Term, so look a few levels deep for the xterm instance.
function findXterm(obj, depth = 0) {
  if (!obj || depth > 4) return null;
  if (typeof obj.setOption === 'function' && obj.element !== undefined) return obj;
  for (const key of ['term', '_term', 'terminal']) {
    const found = findXterm(obj[key], depth + 1);
    if (found) return found;
  }
  return null;
}

function useDom(xterm) {
  try {
    xterm.setOption('rendererType', 'dom');
    injectStyle();
    // The new renderer misses the focus event if the terminal was already
    // focused, leaving the block cursor drawn as an unfocused outline.
    setTimeout(() => {
      if (xterm.element && xterm.element.contains(document.activeElement)) {
        xterm.blur();
        xterm.focus();
      }
    }, 0);
  } catch (e) {
    console.error(TAG, 'failed to switch renderer:', e);
  }
}

exports.decorateTerm = (Term, { React }) =>
  class extends React.Component {
    constructor(props) {
      super(props);
      this.onDecorated = this.onDecorated.bind(this);
    }
    onDecorated(term) {
      if (this.props.onDecorated) this.props.onDecorated(term);
      if (!term) return;
      const xterm = findXterm(term);
      if (xterm) useDom(xterm);
      else console.warn(TAG, 'xterm instance not found on', term);
    }
    render() {
      return React.createElement(Term, Object.assign({}, this.props, { onDecorated: this.onDecorated }));
    }
  };
EOF

# ---------------------------------------------------------------------------
# Slightly transparent background plugin
# ---------------------------------------------------------------------------
BG_PLUGIN_DIR="$HOME/.hyper_plugins/local/hyper-transparent-bg"
info "Writing the hyper-transparent-bg plugin"
mkdir -p "$BG_PLUGIN_DIR"

cat > "$BG_PLUGIN_DIR/package.json" <<'EOF'
{ "name": "hyper-transparent-bg", "version": "1.0.0", "main": "index.js" }
EOF

cat > "$BG_PLUGIN_DIR/index.js" <<'EOF'
// Make the terminal background slightly transparent. Runs after the theme
// plugin (local plugins load last), so it keeps the theme's color and only
// lowers its opacity. Transparency needs webGLRenderer: false.
const OPACITY = 0.92;

exports.decorateConfig = (config) => {
  const hex = (config.backgroundColor || '#000').replace('#', '');
  const full = hex.length === 3 ? hex.split('').map((c) => c + c).join('') : hex.slice(0, 6);
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(full.slice(i, i + 2), 16));
  if ([r, g, b].some(Number.isNaN)) return config;
  return Object.assign({}, config, { backgroundColor: `rgba(${r}, ${g}, ${b}, ${OPACITY})` });
};
EOF

# ---------------------------------------------------------------------------
# zsh config
# ---------------------------------------------------------------------------
info "Writing zsh config"
mkdir -p "$HOME/.zsh" "$HOME/.config/zflash"

backup "$HOME/.zshrc"
cat > "$HOME/.zshrc" <<'EOF'
# ~/.zshrc — the whole file. Everything else is listed, in order, in the zflash
# spec (~/.config/zflash/plugins.zsh): exports and the prompt before the first
# prompt; oh-my-zsh, completions, conda and aliases after it.
source "$HOME/.local/share/zflash/zflash/zflash.zsh"
zflash boot "$HOME/.config/zflash/plugins.zsh"
EOF

backup "$HOME/.zshenv"
cat > "$HOME/.zshenv" <<'EOF'
# uv
export PATH="$HOME/.local/bin:$PATH"
EOF

if [ "$OS" = mac ]; then
  BREW_PREFIX="$(brew --prefix)"
  backup "$HOME/.zprofile"
  cat > "$HOME/.zprofile" <<'EOF'
# Static equivalent of `eval "$(@BREW_PREFIX@/bin/brew shellenv)"`, which forked
# brew (~20 ms) twice per login shell. Homebrew's site-functions are added to
# fpath by zflash (~/.config/zflash/plugins.zsh).
export HOMEBREW_PREFIX="@BREW_PREFIX@"
export HOMEBREW_CELLAR="@BREW_PREFIX@/Cellar"
export HOMEBREW_REPOSITORY="@BREW_REPOSITORY@"
export PATH="@BREW_PREFIX@/bin:@BREW_PREFIX@/sbin${PATH+:$PATH}"
[ -z "${MANPATH-}" ] || { export MANPATH="${MANPATH%"${MANPATH##*[!:]}"}"; export MANPATH=":${MANPATH#"${MANPATH%%[!:]*}"}"; };
export INFOPATH="@BREW_PREFIX@/share/info:${INFOPATH:-}"
EOF
  sed -i '' -e "s|@BREW_PREFIX@|$BREW_PREFIX|g" -e "s|@BREW_REPOSITORY@|$(brew --repository)|g" "$HOME/.zprofile"
fi

backup "$HOME/.config/zflash/plugins.zsh"
cat > "$HOME/.config/zflash/plugins.zsh" <<'EOF'
# zflash spec — everything this shell loads, in order.
# Evaluated only by `zflash build`, never at shell start. Edit, then open a new
# tab (zflash rebuilds automatically when this file is newer than the init).
#
#   zflash load  <repo|file> [path ...]   source before the first prompt
#   zflash defer <repo|file> [path ...]   source after the first prompt
#   zflash fpath <repo|dir>  [path ...]   completions only
#   zflash eval [--defer] '<cmd>'         run at build time, inline the output

# ── before the first prompt ──────────────────────────────────────────────
zflash load ~/.zsh/options.zsh   # setopt must be here: deferred files can't set options
zflash load ~/.zsh/exports.zsh

# oh-my-zsh base library (lib/*.zsh) from the existing checkout, deferred
# except lib/history.zsh, which zflash keeps before the prompt.
zflash defer ~/.oh-my-zsh
zflash load ~/.zsh/history.zsh

# starship prompt, captured once at build time (no fork per shell).
zflash eval 'starship init zsh --print-full-init | grep -v "^PROMPT2="'
zflash eval 'print -r -- "PROMPT2=${(q+)$(starship prompt --continuation)}"'

# ── completions only ─────────────────────────────────────────────────────
@BREW_FPATH@
zflash fpath zsh-users/zsh-completions src

# ── after the first prompt (cached compinit runs first, automatically) ───
zflash defer ~/.zsh/completion.zsh
zflash defer ~/.oh-my-zsh plugins/git

# conda: `conda shell.zsh hook` took ~290 ms per shell; now captured at build
# time, from the first conda install found. Run `zflash build` after
# installing or upgrading conda.
zflash eval --defer 'for c in /opt/homebrew/anaconda3 /usr/local/anaconda3 ~/anaconda3 ~/miniconda3; do [[ -x $c/bin/conda ]] && { $c/bin/conda shell.zsh hook; break }; done; true'

# typing help (order matters: syntax-highlighting first)
zflash defer zsh-users/zsh-syntax-highlighting
zflash defer zsh-users/zsh-history-substring-search
zflash defer zsh-users/zsh-autosuggestions
zflash defer ~/.zsh/keybindings.zsh   # ↑/↓ search history by what's typed

# my aliases, last so they win over plugin aliases
zflash defer ~/.zsh/aliases.zsh
EOF
# Homebrew's completion directory exists only on macOS; zflash errors on a
# missing fpath directory, so drop the line elsewhere.
if [ "$OS" = mac ]; then
  BREW_FPATH="zflash fpath $BREW_PREFIX/share/zsh/site-functions"
else
  BREW_FPATH=""
fi
SPEC="$HOME/.config/zflash/plugins.zsh"
awk -v line="$BREW_FPATH" '$0 == "@BREW_FPATH@" { if (line != "") print line; next } { print }' "$SPEC" > "$SPEC.tmp"
mv "$SPEC.tmp" "$SPEC"

backup "$HOME/.zsh/options.zsh"
cat > "$HOME/.zsh/options.zsh" <<'EOF'
# Shell options, set before the first prompt (loaded by zflash, see
# ~/.config/zflash/plugins.zsh). They live here because setopt inside a deferred
# file is undone when that file finishes (zsh-defer runs it with LOCAL_OPTIONS).
# These are the options oh-my-zsh and ~/.zsh/completion.zsh used to set.

# directories (oh-my-zsh lib/directories.zsh)
setopt auto_cd             # type a folder name to cd into it
setopt auto_pushd          # every cd remembers the previous folder (`d` lists them)
setopt pushd_ignore_dups
setopt pushd_minus

# completion (~/.zsh/completion.zsh, oh-my-zsh lib/completion.zsh)
setopt complete_in_word
setopt always_to_end
unsetopt menu_complete     # don't autoselect the first completion entry
unsetopt flow_control      # free Ctrl+S / Ctrl+Q

# misc (oh-my-zsh lib/misc.zsh)
setopt interactive_comments  # allow `# comments` on the command line
setopt long_list_jobs
EOF

backup "$HOME/.zsh/exports.zsh"
cat > "$HOME/.zsh/exports.zsh" <<'EOF'
# Environment set before the first prompt (loaded by zflash, see ~/.config/zflash/plugins.zsh).
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Keep PATH free of duplicates; ~/.local/bin (uv) stays first.
typeset -gU path   # -g: zflash sources this from inside a function
path=($HOME/.local/bin $path)
EOF

backup "$HOME/.zsh/keybindings.zsh"
cat > "$HOME/.zsh/keybindings.zsh" <<'EOF'
# Key bindings for plugins (deferred by zflash, after the plugins load).

# zsh-history-substring-search: type part of a command, then ↑/↓ cycles
# through past commands that contain it.
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down
EOF

backup "$HOME/.zsh/aliases.zsh"
cat > "$HOME/.zsh/aliases.zsh" <<'EOF'
if [[ "$OSTYPE" == darwin* ]]; then
  alias ls='ls -G'                            # colorize `ls` output (BSD ls)
else
  alias ls='ls --color=auto'                  # colorize `ls` output (GNU ls)
fi
alias zshreload='source ~/.zshrc'             # reload ZSH
alias shtop='sudo htop'                       # run `htop` with root rights
alias grep='grep --color=auto'                # colorize `grep` output
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias less='less -R'
alias g='git'

alias rm='rm -i'                              # confirm removal
alias cp='cp -i'                              # confirm copy
alias mv='mv -i'                              # confirm move
alias cal='gcal --starting-day=1'             # print simple calendar for current month
alias weather='curl v2.wttr.in'               # print weather for current location (https://github.com/chubin/wttr.in)


alias cb='conda activate base'
alias cdx='conda deactivate'

cenv() {
  conda activate "$1"
}

alias py='python3'
alias pip='pip3'
alias jl='jupyter lab'


if command -v brew >/dev/null 2>&1; then
  alias bup='brew update && brew upgrade -y && brew cleanup --dry-run && brew cleanup --prune=all'
elif command -v apt >/dev/null 2>&1; then
  alias bup='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y'
fi
EOF

backup "$HOME/.zsh/completion.zsh"
cat > "$HOME/.zsh/completion.zsh" <<'EOF'
# fixme - the load process here seems a bit bizarre
zmodload -i zsh/complist

WORDCHARS=''

unsetopt menu_complete   # do not autoselect the first completion entry
unsetopt flowcontrol
setopt auto_menu         # show completion menu on successive tab press
setopt complete_in_word
setopt always_to_end

# should this be in keybindings?
bindkey -M menuselect '^o' accept-and-infer-next-history
zstyle ':completion:*:*:*:*:*' menu select

# case insensitive (all), partial-word and substring completion
if [[ "$CASE_SENSITIVE" = true ]]; then
  zstyle ':completion:*' matcher-list 'r:|=*' 'l:|=* r:|=*'
else
  if [[ "$HYPHEN_INSENSITIVE" = true ]]; then
    zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]-_}={[:upper:][:lower:]_-}' 'r:|=*' 'l:|=* r:|=*'
  else
    zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'
  fi
fi
unset CASE_SENSITIVE HYPHEN_INSENSITIVE

# Complete . and .. special directories
zstyle ':completion:*' special-dirs true

zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'

if [[ "$OSTYPE" = solaris* ]]; then
  zstyle ':completion:*:*:*:*:processes' command "ps -u $USERNAME -o pid,user,comm"
else
  zstyle ':completion:*:*:*:*:processes' command "ps -u $USERNAME -o pid,user,comm -w -w"
fi

# disable named-directories autocompletion
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories

# Use caching so that commands like apt and dpkg complete are usable
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path $ZSH_CACHE_DIR

# Don't complete uninteresting users
zstyle ':completion:*:*:*:users' ignored-patterns \
        adm amanda apache at avahi avahi-autoipd beaglidx bin cacti canna \
        clamav daemon dbus distcache dnsmasq dovecot fax ftp games gdm \
        gkrellmd gopher hacluster haldaemon halt hsqldb ident junkbust kdm \
        ldap lp mail mailman mailnull man messagebus mldonkey mysql nagios \
        named netdump news nfsnobody nobody nscd ntp nut nx obsrun openvpn \
        operator pcap polkitd postfix postgres privoxy pulse pvm quagga radvd \
        rpc rpcuser rpm rtkit scard shutdown squid sshd statd svn sync tftp \
        usbmux uucp vcsa wwwrun xfs '_*'

# ... unless we really want to.
zstyle '*' single-ignored show

if [[ ${COMPLETION_WAITING_DOTS:-false} != false ]]; then
  expand-or-complete-with-dots() {
    # use $COMPLETION_WAITING_DOTS either as toggle or as the sequence to show
    [[ $COMPLETION_WAITING_DOTS = true ]] && COMPLETION_WAITING_DOTS="%F{red}…%f"
    # turn off line wrapping and print prompt-expanded "dot" sequence
    printf '\e[?7l%s\e[?7h' "${(%)COMPLETION_WAITING_DOTS}"
    zle expand-or-complete
    zle redisplay
  }
  zle -N expand-or-complete-with-dots
  # Set the function as the default tab completion widget
  bindkey -M emacs "^I" expand-or-complete-with-dots
  bindkey -M viins "^I" expand-or-complete-with-dots
  bindkey -M vicmd "^I" expand-or-complete-with-dots
fi

# automatically load bash completion functions
autoload -U +X bashcompinit && bashcompinit
EOF

backup "$HOME/.zsh/history.zsh"
cat > "$HOME/.zsh/history.zsh" <<'EOF'
## History wrapper
function omz_history {
  # parse arguments and remove from $@
  local clear list stamp REPLY
  zparseopts -E -D c=clear l=list f=stamp E=stamp i=stamp t:=stamp

  if [[ -n "$clear" ]]; then
    # if -c provided, clobber the history file

    # confirm action before deleting history
    print -nu2 "This action will irreversibly delete your command history. Are you sure? [y/N] "
    builtin read -E
    [[ "$REPLY" = [yY] ]] || return 0

    print -nu2 >| "$HISTFILE"
    fc -p "$HISTFILE"

    print -u2 History file deleted.
  elif [[ $# -eq 0 ]]; then
    # if no arguments provided, show full history starting from 1
    builtin fc "${stamp[@]}" -l 1
  else
    # otherwise, run `fc -l` with a custom format
    builtin fc "${stamp[@]}" -l "$@"
  fi
}

# Timestamp format
case ${HIST_STAMPS-} in
  "mm/dd/yyyy") alias history='omz_history -f' ;;
  "dd.mm.yyyy") alias history='omz_history -E' ;;
  "yyyy-mm-dd") alias history='omz_history -i' ;;
  "") alias history='omz_history' ;;
  *) alias history="omz_history -t '$HIST_STAMPS'" ;;
esac

## History file configuration
[ -z "$HISTFILE" ] && HISTFILE="$HOME/.zsh_history"
[ "$HISTSIZE" -lt 50000 ] && HISTSIZE=50000
[ "$SAVEHIST" -lt 10000 ] && SAVEHIST=10000

## History command configuration
setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt share_history          # share command history data
EOF

# ---------------------------------------------------------------------------
# Default shell
# ---------------------------------------------------------------------------
ZSH_PATH="$(command -v zsh)"
[ "$OS" = mac ] && ZSH_PATH=/bin/zsh
CURRENT_SHELL="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || true)"
[ -z "$CURRENT_SHELL" ] && CURRENT_SHELL="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}' || true)"
if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
  info "Changing your login shell to $ZSH_PATH (you may be asked for your password)"
  chsh -s "$ZSH_PATH" || warn "Could not change the login shell. Run: chsh -s $ZSH_PATH"
fi

# ---------------------------------------------------------------------------
# First zflash build: clones the zsh plugins and compiles the init file
# ---------------------------------------------------------------------------
info "Building the zsh init with zflash (clones plugins from GitHub)"
if ! zsh -i -c exit; then
  warn "zflash build reported errors; open a new shell and run 'zflash build' to see them."
fi

info "Done."
cat <<EOF

Next steps:
  1. Start Hyper. On first launch it downloads the npm plugins
     (hyper-one-dark, hyper-search, hypercwd, hyper-active-tab, hyper-pane);
     restart it once they finish installing.
  2. Test Persian rendering:  echo "سلام دنیا، این یک متن فارسی است"
  3. Log out and back in so the new login shell and locale take effect everywhere.

Replaced config files were saved with the suffix .bak-$STAMP
EOF
