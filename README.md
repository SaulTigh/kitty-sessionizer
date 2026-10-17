# kitty-sessionizer

Pick a project with `fzf`, and kitty switches to its session. Each project gets
its own session file, so its tabs and panes come back the way you left them.

## Requirements

| Tool | Use |
|---|---|
| kitty 0.48 or later | sessions, remote control, the watcher |
| zsh | runs the tool |
| fd | finds projects |
| fzf | the picker |
| gum | the prompts of `clone` and `delete` |
| tree | previews a directory |
| bat | previews a file |
| git | clones a repository |
| nvim, or your `KS_EDITOR` | opens a selected file |

`make install` checks that every tool is in place before it links anything.

kitty must allow remote control. Put these lines in `kitty.conf`:

```
allow_remote_control socket-only
listen_on unix:/tmp/kitty
watcher /path/to/kitty-sessionizer/kitty/autosave.py
```

`allow_remote_control yes` works too. kitty adds its pid to the socket name
and leaves the file behind when it is killed. On Linux, `listen_on unix:@kitty`
uses an abstract socket, which leaves no file. The `watcher` line keeps your
sessions across a kitty restart, see [Keep sessions across restarts](#keep-sessions-across-restarts).

## Install

### Make

1. Run `make install`. It checks the tools, then links `bin/kitty-sessionizer`
   into `~/.local/bin`.
2. Add the key bindings that `make install` prints to `kitty.conf`:

   ```
   map alt+shift+p launch --type=overlay --title "Project Selector" /bin/zsh ~/.local/bin/kitty-sessionizer open
   map alt+shift+d launch --type=overlay --title "Delete Sessions" /bin/zsh ~/.local/bin/kitty-sessionizer delete
   map alt+shift+c launch --type=overlay --title "Clone Repository" /bin/zsh ~/.local/bin/kitty-sessionizer clone
   map alt+shift+[ remote_control_script /bin/zsh ~/.local/bin/kitty-sessionizer prev
   map alt+shift+] remote_control_script /bin/zsh ~/.local/bin/kitty-sessionizer next
   map alt+shift+backslash remote_control_script /bin/zsh ~/.local/bin/kitty-sessionizer last
   ```

   `open`, `delete` and `clone` ask questions, so they run in an overlay.
   `prev`, `next` and `last` ask nothing, so they run in the background.
3. Set your search paths, see [Configure](#configure).
4. Reload kitty with `kitten @ load-config`.

Run `make uninstall` to remove the link.

### Nix / Home Manager

Add the input to your flake:

```nix
inputs.kitty-sessionizer.url = "github:SaulTigh/kitty-sessionizer";
```

Import the Home Manager module and enable it:

```nix
{ inputs, ... }:
{
  imports = [ inputs.kitty-sessionizer.homeManagerModules.default ];

  programs.kitty-sessionizer = {
    enable = true;
    searchPaths = [
      "~/workspace/personal"
      "~/.config"
    ];
  };
}
```

The module installs the tool, adds the six key bindings to
`programs.kitty.keybindings`, and sets `watcher` and `listen_on` in
`programs.kitty.settings`. Those two use `mkDefault`, so your own value wins.
kitty still needs `allow_remote_control`.

| Option | Sets | Default |
|---|---|---|
| `searchPaths` | `KS_SEARCH_PATH` | `~` |
| `depth` | `KS_DEPTH` | `1` |
| `editor` | `KS_EDITOR` | `nvim` |
| `sessionDir` | `KS_SESSION_DIR` | `~/.local/share/kitty/sessions` |
| `template` | `KS_TEMPLATE` | `~/.config/kitty/default.kitty-session` |
| `environment` | any other `KS_*` variable | `{ }` |
| `kitty.enable` | the key bindings | `true` |
| `kitty.autosave` | the watcher | `true` |
| `kitty.listenOn` | `listen_on`, or `null` to leave it alone | `unix:@kitty` |
| `kitty.keys.<action>` | the key of each action, or `null` to skip it | the keys above |

A leading `~` in `searchPaths` expands to your home directory.

## Use

```
kitty-sessionizer open      Pick a project and switch to its session
kitty-sessionizer clone     Clone a git repository into a search path
kitty-sessionizer delete    Delete saved sessions
kitty-sessionizer prev      Go to an older open session
kitty-sessionizer next      Go to a newer open session
kitty-sessionizer last      Go back to the session you came from
kitty-sessionizer help      List the actions
```

### The picker

A marker shows the state of each project:

| Marker | Meaning |
|---|---|
| `●` | the session you are in |
| `○` | an open session |
| none | no session yet |

Open sessions come first, most recently used on top. The session you are in
comes last of them, because you open the picker to go somewhere else. The other
projects follow in the order `fd` finds them. When you type, the open sessions
stay on top and the rest sort by match.

Pick a plain file instead of a directory to open it in a new tab in your editor.

### Clone a repository

`clone` asks four things:

1. The clone URL. An empty answer cancels.
2. The search path to clone into. One path is taken without a prompt.
3. The folder name. The repository name is filled in.
4. `Open` to switch to the new session, or `Exit`.

Esc or Ctrl-C cancels at any prompt. The output of git shows only when the
clone fails. A folder name that is already in use stops the action. Nothing is
overwritten.

### Delete sessions

`delete` lists every saved session with the picker markers.

1. Mark sessions with `x` or `Tab`, or all of them with `a` or `Ctrl-A`, then
   press Enter. Enter alone marks nothing: the cursor is not a mark.
2. `Delete` to confirm, or `Cancel`.

The action removes the files, then closes the kitty tabs of the deleted
sessions. When your own session is among them:

- Several other sessions are open: pick the one to land in. Esc asks again,
  because the tab you are in is about to close.
- One is open: kitty switches to it.
- None is open: a plain tab opens and every other tab closes.

### Move between open sessions

`prev` and `next` walk the open sessions in the order you used them, and wrap
at the ends. `last` goes back to the session you came from, and a second press
returns. Only a session with a window open counts. A session whose tabs you
closed by hand drops out instead of reopening.

These moves record where you are, but do not change the order. A move that
counted as a use would put the target on top, and the next press would come
straight back. Only a pick in the picker or a `clone` moves a session to the
top.

## Keep sessions across restarts

Quit kitty and start it again. No session shows as open. Pick one, and it
comes back with the tabs, panes, directories and programs it had.

`kitty/autosave.py` is a kitty watcher. kitty runs no hook when it is killed,
so the watcher saves after every change instead: a tab opens, closes or changes
its title, the focus moves, or a window is resized. A burst of changes gives
one save a second later. A file whose content is already current is not
rewritten.

The watcher saves a session only when the tool opened it in this kitty, kitty
loaded it from that same file, it has a window, and kitty is not quitting. The
tool also saves the session you leave, but only when kitty is really in it.

A program comes back as a new process. `claude` starts again, but not the
conversation you had in it.

## Default tabs come back

Every switch to a session reopens the tabs of the template that the session
lacks. A tab you close by accident is back on your next switch. A tab is
matched by its title, the `new_tab` line of the template. A reopened tab goes
to the end of the tab bar, and the focus stays where it was. A tab you add
yourself is not a default tab. Once you close it, it stays closed.

## Session files

A project's session file is
`~/.local/share/kitty/sessions/<directory>-<project>.kitty-session`. It is
rendered once from `~/.config/kitty/default.kitty-session`. The template may
use `@@session@@` for the project name and `@@session-path@@` for its path:

```
new_tab @@session@@ :: nvim
cd @@session-path@@
launch --title "@@session@@ :: nvim" zsh -i -c "nvim;zsh"

new_tab @@session@@ :: zsh
cd @@session-path@@
launch zsh -i
focus_tab 0
```

The file name holds the directory as well as the project, as in
`personal-roboboba`, because two projects may share a name. `@@session@@` stays
the project alone, so a tab title reads `roboboba`. `KS_SESSION_NAME_SEP` sets
the mark between the two parts.

A project that holds its own `.kitty-session` file is opened from that file
instead. kitty gives such a file an empty session name, so the tool cannot
track it: it never shows as open, is not saved, and `prev`, `next`, `last`
and `delete` skip it. Use the generated files.

## Configure

`lib/config.zsh` holds every tunable value. An environment variable of the same
name wins. kitty starts the tool as `/bin/zsh <script>`, which reads
`~/.zshenv` and not `~/.zshrc`, so export your values there:

```zsh
export KS_SEARCH_PATH="$HOME/workspace/work:$HOME/workspace/personal:$HOME/.config"
```

| Variable | Default |
|---|---|
| `KS_SEARCH_PATH` | `~` |
| `KS_DEPTH` | `1` |
| `KS_HOME_FILE_PATH` | `~` |
| `KS_SESSION_DIR` | `~/.local/share/kitty/sessions` |
| `KS_TEMPLATE` | `~/.config/kitty/default.kitty-session` |
| `KS_EDITOR` | `nvim` |
| `KS_FD`, `KS_FZF`, `KS_GUM`, `KS_KITTEN`, `KS_TREE`, `KS_BAT` | `/opt/homebrew/bin/<tool>` |
| `KS_GIT` | `/usr/bin/git` |

The picker lists the entries under each search path, in the order given, then
the files in `KS_HOME_FILE_PATH`. The tool paths are absolute because kitty
starts the tool with a short `PATH`. gum takes its colours from `GUM_*`
variables, and `lib/config.zsh` exports the Jellybeans set.

## State

kitty does not report the order the sessions were used in, so the tool keeps
its own record in `$XDG_RUNTIME_DIR/kitty-sessionizer/<kitty pid>/`, or under
`/tmp` when `XDG_RUNTIME_DIR` is not set. A restarted kitty starts with an
empty record. Nothing removes the old directories on macOS. They are small,
and `/tmp` is cleared on reboot.

| File | Holds |
|---|---|
| `current-session` | the session you are in |
| `previous-session` | the session you came from |
| `active-sessions` | every session opened in this kitty, newest first |
| `session-projects` | the project of each session, to render its default tabs |

The open marker does not trust the record alone. A session shows as open only
while kitty has a window in it. `delete` clears the record when you delete
every session. `KS_STATE_ROOT` moves the record. The watcher reads it too, so
set it in the environment kitty starts with.

## Develop

```
bin/kitty-sessionizer   Find the repository, load the prelude, run one action
libexec/*.zsh           One file per action
lib/bootstrap.zsh       ks_use, ks_die, ks_require_tools
lib/config.zsh          Every tunable value
lib/common.zsh          The prelude: config, ui and small helpers
lib/ui.zsh              Colours, messages, key and line prompts
lib/kitty.zsh           Wrappers over `kitten @`
lib/git.zsh             Wrappers over `git`
lib/gum.zsh             Wrappers over `gum`
lib/session.zsh         Session files and the record of open sessions
lib/discovery.zsh       Stream the candidate paths
lib/picker.zsh          Row format, row order, fzf run, selection parse
kitty/autosave.py       kitty watcher that saves open sessions
tests/                  Tests, run with `make test`
```

To add an action, write `libexec/<name>.zsh` with a `# summary: <one line>`
comment on the first line, and call `ks_use <module> …` for the modules it
needs. The dispatcher finds the file on its own.

`make test` parses every script, then runs the tests of the session record,
the picker and the watcher. The picker tests need `fd` and `fzf` in `PATH`, and
the watcher tests run in the Python of kitty. To try an action against
throwaway state:

```zsh
KS_SESSION_DIR=/tmp/ks-test \
KS_STATE_DIR=/tmp/ks-state \
KS_SEARCH_PATH=/tmp/ks-roots \
KS_HOME_FILE_PATH=/tmp/ks-roots \
  kitty-sessionizer open
```
