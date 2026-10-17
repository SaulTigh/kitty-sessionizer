# Architecture

kitty-sessionizer is a set of zsh scripts and one kitty watcher. The scripts
run for one action and exit. kitty holds the windows, and the file system
holds everything the tool needs to remember. This page explains the parts,
how they talk, and why they are built this way.

## Parts

```
 kitty.conf                 kitty process
 ┌────────────────────┐     ┌─────────────────────────────────────────┐
 │ map … launch       │────▶│ overlay window: zsh kitty-sessionizer   │
 │   --type=overlay   │     │   open | clone | delete                 │
 │ map … remote_      │────▶│ background child: zsh kitty-sessionizer │
 │   control_script   │     │   prev | next | last                    │
 │ watcher autosave.py│────▶│ kitty/autosave.py, inside kitty itself  │
 └────────────────────┘     └──────────┬──────────────────┬───────────┘
                                       │ kitten @         │ read / write
                                       ▼                  ▼
                            ┌──────────────────┐  ┌──────────────────────┐
                            │ kitty remote     │  │ files                │
                            │ control socket   │  │  session dir          │
                            └──────────────────┘  │  state dir (per pid)  │
                                                  │  template             │
                                                  └──────────────────────┘
```

| Part | Role |
|---|---|
| `bin/kitty-sessionizer` | Finds the repository, loads the prelude, runs one action |
| `libexec/*.zsh` | One action each. See [actions.md](actions.md) |
| `lib/*.zsh` | Modules. Each wraps one concern: kitty, gum, git, sessions, discovery, the picker |
| `kitty/autosave.py` | A watcher that saves open sessions from inside kitty |
| session directory | One `.kitty-session` file per project |
| state directory | The record of which sessions are open and in which order |

## Two ways to run

An action that asks a question runs in a kitty overlay. The overlay gives it
a terminal for `fzf` and `gum`, and kitty closes it when the action returns.

An action that asks nothing runs through `remote_control_script`. kitty
starts it as a direct child with remote control allowed, and no window opens.
`launch --type=background` does not work here, because kitty gives such a
window no remote control.

kitty starts both as `/bin/zsh <script>`, a non-interactive shell with a short
environment. That is why the tool paths in `lib/config.zsh` are absolute, and
why a value exported from `~/.zshenv` reaches the tool but a value exported
from `~/.zshrc` does not.

## Talking to kitty

Every call to kitty goes through `ks_kitty` in `lib/kitty.zsh`, which runs
`kitten @` and drops the error. kitty is not always reachable: remote control
can be off, or the window that owned a session can be gone. A failed call
must never stop an action.

The tool uses four kitty commands:

| Command | Use |
|---|---|
| `action goto_session <file>` | Switch to a session, or load it from its file |
| `action save_as_session … <file>` | Write the live layout back to the file |
| `ls` | Which sessions have a window, which tab is focused, which tabs a session has |
| `launch --type=tab --add-to-session` | Reopen a default tab the session lacks |

`ls` prints JSON. The tool reads it by line and picks the `session_name` and
`title` fields by their indent. A JSON parser would be one more tool to
require.

kitty names a session after its file, without the extension. A session file
`personal-roboboba.kitty-session` gives the session `personal-roboboba`. The
tool relies on this: the open marker, the cycle and `delete` all match on
`session:^<name>$`. A match value is a regular expression, so
`ks_kitty_match_pattern` escapes the name first.

## Session files

A project has one session file in the session directory, named
`<directory>-<project>.kitty-session`. The directory is part of the name,
because two projects may share a name and every file sits in one flat
directory.

The file is rendered once from the template, on the first switch to the
project. After that kitty and the watcher own its content. The template may
use `@@session@@` for the project name and `@@session-path@@` for its path.

The template also tells the tool which tabs a session should have. On every
switch, `ks_session_restore_defaults` compares the `new_tab` titles of the
template with the tabs kitty has in the session, and reopens the missing
ones. A tab the user added is not in the template, so once closed it stays
closed.

## The record of open sessions

kitty reports which session a window belongs to, but not the order the
sessions were used in. The tool keeps that order itself, in the state
directory:

| File | Holds |
|---|---|
| `current-session` | the session the user is in |
| `previous-session` | the session before it, for `last` |
| `active-sessions` | every session opened in this kitty, newest first |
| `session-projects` | the project of each session, to render its template again |

The state directory is keyed to the kitty pid: `KITTY_PID` in an overlay,
`$PPID` in a `remote_control_script` child, `os.getpid()` in the watcher. A
restarted kitty starts with an empty record. This is why no session shows as
open after a restart, and why `prev` and `next` have nothing to walk until
the user picks a project again.

The record is never trusted alone. A session counts as open only when its
file exists and `ls` shows a window in it. A session whose tabs the user
closed by hand drops out of the picker markers and out of the cycle.

A pick in the picker and a `clone` move a session to the top of
`active-sessions`. `prev`, `next` and `last` record the move in
`current-session` but leave the order alone. A move that counted as a use
would put the target on top, and the next press would come straight back.

## Saving a session

A session file is written in two places.

The tool saves the session it leaves, before it switches. The save runs
`save_as_session --match=session:.`, which takes the windows of the session
kitty is in. The tool checks first that this is the session its record names.
Otherwise a stale record could overwrite one session file with the windows of
another.

The watcher saves every tracked session from inside kitty, because kitty runs
no hook when it is killed. It listens to tab bar changes, focus changes and
window resizes, and saves one second after the first event of a burst. It
saves a session only when the tool opened it in this kitty, kitty loaded it
from the same file, it has a window, and kitty is not quitting. A file whose
content is already current is not rewritten.

## The picker

The picker streams. `fd` lists the entries under each search path. Chosen
folders and home files follow. Each row goes to `fzf` as soon as it is found,
so the first rows show before the search ends.

The open sessions come first, in the order of `active-sessions`, with the
current one last. Search results and chosen folders follow in configured order.
Each row carries four tab-separated fields: the marker and name, the group,
the session file and the path. `fzf` searches the first field and shows the
first two. The action reads the last two.

A typed query keeps the open sessions on top. `fzf` cannot do that on its own,
so the rows are also written to a cache, and the `change` event runs
`fzf --filter` over the open rows and the other rows in turn. A query typed
before the search ends waits for a `done` marker, then ranks the full list.

## Why zsh

The tool is glue between `fd`, `fzf`, `gum` and `kitten`. Each action is a
short sequence of prompts and calls, and zsh handles that with no build step
and no runtime to install. The watcher is Python because kitty loads
watchers into its own Python process, and that process is the only place a
save can run when kitty is killed.
