# Every tunable value lives here and nowhere else.
#
# Each assignment uses := , so an environment variable of the same name wins. To
# change a search path or a colour for one run, export the variable before the
# command. To change it for good, edit the default below.

# --- External tools -----------------------------------------------------------
# Absolute paths, because kitty starts the tool with a short PATH.

: ${KS_FD:=/opt/homebrew/bin/fd}
: ${KS_FZF:=/opt/homebrew/bin/fzf}
: ${KS_GUM:=/opt/homebrew/bin/gum}
: ${KS_KITTEN:=/opt/homebrew/bin/kitten}
: ${KS_TREE:=/opt/homebrew/bin/tree}
: ${KS_BAT:=/opt/homebrew/bin/bat}
: ${KS_GIT:=/usr/bin/git}
: ${KS_EDITOR:=nvim}

# --- Locations ----------------------------------------------------------------

: ${KS_KITTY_CONFIG_DIR:=${XDG_CONFIG_HOME:-$HOME/.config}/kitty}
: ${KS_SESSION_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/kitty/sessions}
: ${KS_TEMPLATE:=$KS_KITTY_CONFIG_DIR/default.kitty-session}

# Suffix of a generated session file, and the name a project uses to carry its
# own layout. A project file wins over the generated one.
: ${KS_SESSION_SUFFIX:=.kitty-session}
: ${KS_LOCAL_SESSION_NAME:=.kitty-session}

# What joins the directory to the project in a generated name, as in
# `personal-roboboba`. The name reaches the kitty tab title, so a short mark
# reads better there than a long one.
: ${KS_SESSION_NAME_SEP:=-}

# --- State between runs -------------------------------------------------------
# The current session, the session before it, and every session that has been
# opened, newest first. kitty does not report the order the sessions were used
# in, so the tool keeps its own record.
#
# The record belongs to one kitty process. A restarted kitty starts with an
# empty record. A child of kitty gets KITTY_PID, and a remote_control_script
# runs as a direct child of kitty, so $PPID covers it. kitty/autosave.py reads
# the same directory, so KS_STATE_ROOT must match in both.

: ${KS_STATE_ROOT:=${XDG_RUNTIME_DIR:-/tmp}/kitty-sessionizer}
: ${KS_STATE_DIR:=$KS_STATE_ROOT/${KITTY_PID:-$PPID}}
: ${KS_CURRENT_TRACKER:=$KS_STATE_DIR/current-session}
: ${KS_PREVIOUS_TRACKER:=$KS_STATE_DIR/previous-session}
: ${KS_ACTIVE_TRACKER:=$KS_STATE_DIR/active-sessions}
: ${KS_PROJECT_TRACKER:=$KS_STATE_DIR/session-projects}

# --- Discovery ----------------------------------------------------------------
# Search paths keep their order in the picker. A path that does not exist is
# skipped. A search path lists its folders. A file search path lists its files
# too.

: ${KS_DEPTH:=1}

# An array cannot cross a process boundary, so the search paths also have a
# colon-separated form. Set KS_SEARCH_PATH to override them for one run, or
# export it from ~/.zshenv to set them for good:
#
#   export KS_SEARCH_PATH=~/workspace/work:~/workspace/personal:~/.config
#   export KS_FILE_SEARCH_PATH=~
#
typeset -ga KS_SEARCH_PATHS
if [[ -n "${KS_SEARCH_PATH:-}" ]]; then
    KS_SEARCH_PATHS=("${(@s.:.)KS_SEARCH_PATH}")
fi

typeset -ga KS_FILE_SEARCH_PATHS
if [[ -n "${KS_FILE_SEARCH_PATH:-}" ]]; then
    KS_FILE_SEARCH_PATHS=("${(@s.:.)KS_FILE_SEARCH_PATH}")
fi

typeset -ga KS_EXTRA_PROJECT_PATHS
if [[ -n "${KS_EXTRA_PROJECTS:-}" ]]; then
    KS_EXTRA_PROJECT_PATHS=("${(@s.:.)KS_EXTRA_PROJECTS}")
fi

# --- Row format ---------------------------------------------------------------
# Column 1 is padded to a fixed width. A computed width would need the full list
# first, which would stop the picker from drawing rows as fd produces them.

: ${KS_PAD:=48}
: ${KS_TAG_CURRENT:="●"}
: ${KS_TAG_ACTIVE:="○"}
: ${KS_TAG_NONE:=" "}

# --- Colours ------------------------------------------------------------------
# Jellybeans, matched to the fzf theme below.

: ${KS_C_WARN:=$'\e[1;38;2;207;106;76m'}
: ${KS_C_OK:=$'\e[38;2;153;173;106m'}

# The blue the picker gives its prompt, so a question in the terminal and a
# question in the picker look the same. A key choice takes it too, because both
# mark the place where the user acts.
: ${KS_C_PROMPT:=$'\e[1;38;2;143;191;220m'}
: ${KS_C_KEY:=$KS_C_PROMPT}

# The orange gum gives a header. An answered prompt is printed back in it, so
# the answer looks like the prompt did.
: ${KS_C_LABEL:=$'\e[38;2;207;106;76m'}

: ${KS_C_DIM:=$'\e[2m'}
: ${KS_C_RESET:=$'\e[0m'}

# --- gum ----------------------------------------------------------------------
# The same Jellybeans colours, in the form gum reads. gum takes its colours from
# the environment, so these are exported and an exported value of the same name
# wins.

: ${KS_GUM_PROMPT:=">> "}

# Every gum prompt and every line around it sits in one column of this width,
# centred in the overlay.
: ${KS_GUM_WIDTH:=64}

export GUM_INPUT_PROMPT_FOREGROUND="${GUM_INPUT_PROMPT_FOREGROUND:-#8fbfdc}"
export GUM_INPUT_HEADER_FOREGROUND="${GUM_INPUT_HEADER_FOREGROUND:-#cf6a4c}"
export GUM_INPUT_CURSOR_FOREGROUND="${GUM_INPUT_CURSOR_FOREGROUND:-#cf6a4c}"
export GUM_INPUT_PLACEHOLDER_FOREGROUND="${GUM_INPUT_PLACEHOLDER_FOREGROUND:-#888888}"

export GUM_CHOOSE_HEADER_FOREGROUND="${GUM_CHOOSE_HEADER_FOREGROUND:-#cf6a4c}"
export GUM_CHOOSE_CURSOR_FOREGROUND="${GUM_CHOOSE_CURSOR_FOREGROUND:-#cf6a4c}"
export GUM_CHOOSE_ITEM_FOREGROUND="${GUM_CHOOSE_ITEM_FOREGROUND:-#e8e8e8}"
export GUM_CHOOSE_SELECTED_FOREGROUND="${GUM_CHOOSE_SELECTED_FOREGROUND:-#99ad6a}"

export GUM_CONFIRM_PROMPT_FOREGROUND="${GUM_CONFIRM_PROMPT_FOREGROUND:-#8fbfdc}"
export GUM_CONFIRM_SELECTED_FOREGROUND="${GUM_CONFIRM_SELECTED_FOREGROUND:-#ffffff}"
export GUM_CONFIRM_SELECTED_BACKGROUND="${GUM_CONFIRM_SELECTED_BACKGROUND:-#cf6a4c}"
export GUM_CONFIRM_UNSELECTED_FOREGROUND="${GUM_CONFIRM_UNSELECTED_FOREGROUND:-#e8e8e8}"
export GUM_CONFIRM_UNSELECTED_BACKGROUND="${GUM_CONFIRM_UNSELECTED_BACKGROUND:-#303030}"

export GUM_SPIN_SPINNER_FOREGROUND="${GUM_SPIN_SPINNER_FOREGROUND:-#fad07a}"
export GUM_SPIN_TITLE_FOREGROUND="${GUM_SPIN_TITLE_FOREGROUND:-#e8e8e8}"

# --- Picker -------------------------------------------------------------------
# The look every picker shares. Each picker below adds its own label, prompt and
# preview to it, so a colour is written once.

: ${KS_FZF_THEME:="--style=full \
  --color=bg+:#303030,bg:-1,spinner:#fad07a,hl:#fad07a,fg:#e8e8e8 \
  --color=header:#888888,info:#b4b4b9,pointer:#cf6a4c,marker:#99ad6a \
  --color=fg+:#ffffff,prompt:#8fbfdc,hl+:#cf6a4c,border:#333333 \
  --color=query:#cf6a4c \
  --color=label:#cf6a4c \
  --border=sharp \
  --padding=8 \
  --layout=reverse"}

# The project picker. Field 1 is searchable and shown, field 2 is shown only,
# fields 3 and 4 carry the data the action needs.
#
# A {n} placeholder stays bare, because fzf quotes it. A quote around it reaches
# the command as part of the path, and then no path is found.

: ${KS_FZF_OPTS:="$KS_FZF_THEME \
  --with-nth 1,2 \
  --nth 1 \
  --tabstop=1 \
  --delimiter '\t' \
  --border-label='Project selection' \
  --header='Controls: [Enter] Select, [Ctrl-C] Abort, [Ctrl-D/U] Scroll preview' \
  --bind='ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' \
  --prompt='Select workspace >> ' \
  --preview 'if [ -d {4} ]; then ${KS_TREE} --gitignore -C -L 2 {4}; else ${KS_BAT} --color=always --style=numbers {4}; fi' \
  --preview-window='right,55%,border-sharp'"}
