# kitty-sessionizer

Pick a project with `fzf`, then switch the kitty session to it. Each project gets
its own session file, so its tabs and panes come back the way you left them.

## Requirements

| Tool | Use |
|---|---|
| kitty 0.48 or later | `goto_session` and `save_as_session` |
| fd | find projects |
| fzf | the picker |
| gum | the prompts of `clone` and `delete` |
| tree | preview a directory |
| bat | preview a file |
| git | clone a repository |

kitty must allow remote control. `kitty.conf` needs these two lines:

```
allow_remote_control yes
listen_on unix:/tmp/kitty
```

## Install

### Make

1. Run `make install`. It links `bin/kitty-sessionizer` into `~/.local/bin`.
   A previous file of that name is kept as `kitty-sessionizer.pre-refactor`.
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
   `prev`, `next` and `last` ask nothing, so they run through `remote_control_script`,
   which starts the tool in the background with remote control allowed.
3. Reload the kitty configuration with `kitten @ load-config`.

Run `make uninstall` to remove the link.

### Nix / Home Manager

Add the input to your flake:

```nix
inputs.kitty-sessionizer.url = "github:OWNER/kitty-sessionizer-sh";
```

Then import the Home Manager module and enable it (pass `inputs` through
`extraSpecialArgs` if it is not already available):

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

The module installs the tool and adds the five key bindings to
`programs.kitty.keybindings`. kitty still needs remote control, see
[Requirements](#requirements).

| Option | Sets | Default |
|---|---|---|
| `searchPaths` | `KS_SEARCH_PATH` | the list in `lib/config.zsh` |
| `depth` | `KS_DEPTH` | `1` |
| `editor` | `KS_EDITOR` | `nvim` |
| `sessionDir` | `KS_SESSION_DIR` | `~/.local/share/kitty/sessions` |
| `template` | `KS_TEMPLATE` | `~/.config/kitty/default.kitty-session` |
| `environment` | any other `KS_*` variable | `{ }` |
| `kitty.enable` | the key bindings | `true` |
| `kitty.keys.<action>` | the key of `open`, `delete`, `clone`, `prev`, `next` or `last` | the keys under [Make](#make) |

A leading `~` in `searchPaths` expands to the home directory. The module bakes
each value into a wrapper, so it works when kitty starts the tool with a short
environment. An exported variable of the same name still wins. Set a key to
`null` to skip that binding.

## Use

```
kitty-sessionizer open      Pick a project and switch to its kitty session
kitty-sessionizer clone     Clone a git repository into a workspace directory
kitty-sessionizer delete    Delete saved kitty sessions
kitty-sessionizer prev      Switch to the session used before the current one
kitty-sessionizer next      Switch to the session used after the current one
kitty-sessionizer last      Switch back to the session you were in before the current one
kitty-sessionizer help      List the actions
```

A marker in the picker shows the state of each project:

| Marker | Meaning |
|---|---|
| `▶ (current)` | the session you are in |
| `▶` | a session that is open |
| none | no session yet |

Select a plain file instead of a directory to open it in a new tab in `$KS_EDITOR`.

## Clone a repository

`kitty-sessionizer clone` asks four things, in this order:

1. The clone URL. Paste it. An empty answer cancels.
2. The directory to clone into. The list holds the `KS_SEARCH_PATHS` that
   exist, so the clone lands where `open` will find it again. A list of one is
   taken without a prompt.
3. The folder name. The repository name is filled in, so press Enter to keep it
   or edit the line to change it.
4. `Open` to switch to the session of the clone, or `Exit` to close.

Esc or Ctrl-C cancels at any prompt. A spinner runs while git clones, and the
output of git is shown only when the clone fails. The prompts sit in one column
of `KS_GUM_WIDTH` characters, centred in the overlay.

The action stops when the folder name is already in use. Nothing is deleted and
nothing is overwritten. Run it again with another name.

## Delete sessions

`kitty-sessionizer delete` lists every saved session with the same markers as
the picker.

1. Press `x` or `Tab` to mark a session, or `a` or `Ctrl-A` to mark them all.
   Enter submits the marked rows, and the list of them stays on screen above
   the confirm. Enter alone submits nothing: the cursor highlight is not
   a mark. Space does not mark a row in gum 2.0.2, see
   https://github.com/charmbracelet/gum/issues/1143.
2. `Delete` to confirm, or `Cancel`.

The action removes the session files, prints each deleted session, and waits
for a key. Then it closes the kitty tabs of the deleted sessions that were
open. Esc or Ctrl-C cancels at any prompt up to here.

When the current session is among the deleted ones, what happens next depends
on the other open sessions:

- Several are open: a `Switch to session` prompt lists them. Pick one. Esc
  asks again, because the tab you are in is about to close.
- One is open: kitty switches to it without a prompt.
- None is open: a plain tab opens and every other tab closes.

## Move between open sessions

`prev` and `next` walk the open sessions in the order you used them. `prev`
goes to an older session, `next` to a newer one, and both wrap at the ends.
The bindings run the tool with `remote_control_script`, so no window opens.

Only a session with a window open counts. A session whose tabs you closed by
hand drops out of the cycle instead of reopening. With fewer than two open
sessions the action does nothing.

A `prev` or `next` move does not change the order. It only records where you
are. If a move counted as a use, the target would go to the top of the list
and the second press would come straight back. A pick in the project picker,
`clone` or `delete` moves the target to the top.

`last` switches back to the session you were in before the current one. Press
it again to return. Every move counts, so after `prev` from C to B and `prev`
again to A, `last` goes to B. Like `prev` and `next`, it does not change the
order. It does nothing when the previous session is deleted or has no window
open.

## How a session file is chosen

1. If the project holds a `.kitty-session` file, that file is used.
2. Otherwise the file is
   `~/.local/share/kitty/sessions/<directory>-<project>.kitty-session`.
   It is rendered once from `~/.config/kitty/default.kitty-session`. The template
   may use `@@session@@` for the project name and `@@session-path@@` for the path
   of the project.

The file name holds the directory as well as the project, as in
`personal-roboboba`. Every generated file shares one flat directory, and the
project name alone is not unique: `workspace/personal/roboboba` and
`workspace/backups/roboboba` are two projects, and one name would give them one
session. `KS_SESSION_NAME_SEP` sets the mark between the two parts.

`@@session@@` stays the project alone, so a tab title reads `roboboba`, not
`personal-roboboba`. kitty tells the two sessions apart on its own, because it
names a session after its file. That is why `delete` closes tabs with a
`session:` match and not with a title match.

## Configure

`lib/config.zsh` holds every tunable value. Each one uses `:=`, so an environment
variable of the same name wins. Export a variable to change one run, or edit the
default to change it for good.

The values you are most likely to change:

| Variable | Default |
|---|---|
| `KS_SEARCH_PATHS` | `~/workspace/nc ~/workspace/personal ~/workspace/backups ~/.config` |
| `KS_DEPTH` | `1` |
| `KS_HOME_FILE_PATH` | `~` |
| `KS_SESSION_DIR` | `~/.local/share/kitty/sessions` |
| `KS_TEMPLATE` | `~/.config/kitty/default.kitty-session` |
| `KS_EDITOR` | `nvim` |
| `KS_GIT` | `/usr/bin/git` |
| `KS_GUM` | `/opt/homebrew/bin/gum` |

gum takes its colours from `GUM_*` variables. `lib/config.zsh` exports the
Jellybeans set, and an exported value of the same name wins.

`KS_SEARCH_PATHS` is an array, and an array cannot cross a process boundary. To
change the search paths for one run, use the colon-separated `KS_SEARCH_PATH`
instead. It wins over the array when it is set.

## Layout

```
bin/kitty-sessionizer   Find the repository, load the prelude, run one action
libexec/*.zsh           One file per action
lib/bootstrap.zsh       ks_use, ks_die, ks_require_tools
lib/config.zsh          Every tunable value
lib/common.zsh          The prelude: loads config and ui, adds small helpers
lib/ui.zsh              Colours, messages, key and line prompts
lib/kitty.zsh           Wrappers over `kitten @`
lib/git.zsh             Wrappers over `git`
lib/gum.zsh             Wrappers over `gum`: line, choice, confirm, spinner
lib/session.zsh         Session files and the record of open sessions
lib/discovery.zsh       Stream the candidate paths
lib/picker.zsh          fzf options, row format, selection parse
```

## Add an action

1. Write `libexec/<name>.zsh`.
2. Put a `# summary: <one line>` comment on the first line. `help` reads it.
3. Call `ks_use <module> …` for the modules you need. `config` and `ui` are
   already loaded.

The dispatcher finds the file on its own. Nothing else changes.

A helper belongs in `lib/common.zsh` only when two or more modules call it and it
knows nothing about kitty or about sessions. Anything that names a session file
or a `kitten` command goes in its own module.

## State

kitty reports which session a window belongs to, but not the order the sessions
were used in, so the tool keeps its own record:

| File | Holds |
|---|---|
| `/tmp/kitty-current-session` | the session you are in |
| `/tmp/kitty-previous-session` | the session you were in before it |
| `/tmp/kitty-active-sessions` | every session that has been opened, newest first |

All three are cleared by `kitty-sessionizer delete` when you delete all sessions.

## Verify a change

Run `make check` to parse every script. Then:

1. `kitty-sessionizer help` lists the actions.
2. `kitty-sessionizer bogus` prints an error and exits non-zero.
3. Press `alt+shift+p`. Rows appear as `fd` finds them. The preview shows a tree
   for a directory and the file content for a file.
4. Select a project with no session. A file appears in `KS_SESSION_DIR` and kitty
   switches to it.
5. Select the same project three times. `/tmp/kitty-active-sessions` holds one
   line for it, not three, and the line is the first one.
6. Open three projects in turn. Press `alt+shift+[` twice. kitty lands in the
   first project. Press `alt+shift+]` once. kitty lands in the second one.
   `/tmp/kitty-active-sessions` keeps the order it had.
7. Close every tab of the third project by hand. Press `alt+shift+[` from the
   first project. kitty lands in the second one and skips the third.
   Press `alt+shift+backslash`. kitty goes back to the first project. Press it
   again. kitty returns to the second one.
8. Press `alt+shift+d`. Mark one session, then choose `Cancel`. Nothing is
   deleted.
9. Press `alt+shift+c`. Paste a URL, pick a directory, keep the name, and choose
   `Open` at the last prompt. kitty switches to the clone. Every prompt and
   every message shares one left margin.
10. Press `alt+shift+c` again and give the same name. The action reports the
    clash and clones nothing.

To try an action against throwaway state, point the variables somewhere else:

```zsh
KS_SESSION_DIR=/tmp/ks-test \
KS_CURRENT_TRACKER=/tmp/ks-current \
KS_PREVIOUS_TRACKER=/tmp/ks-previous \
KS_ACTIVE_TRACKER=/tmp/ks-active \
KS_SEARCH_PATH=/tmp/ks-roots \
KS_HOME_FILE_PATH=/tmp/ks-roots \
  kitty-sessionizer open
```
