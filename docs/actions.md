# Actions

An action is one file in `libexec/`. `kitty-sessionizer <name>` runs
`libexec/<name>.zsh`. This page tells you how to add one and how to change one.

## How an action runs

1. `bin/kitty-sessionizer` finds the repository through the symlink, loads
   `lib/bootstrap.zsh`, and loads the prelude `lib/common.zsh`.
2. The prelude loads `lib/config.zsh` and `lib/ui.zsh`, so every action starts
   with the configuration and the output helpers.
3. The dispatcher sources `libexec/<name>.zsh`. The file runs top to bottom.
   It is not a function, so `return` ends the action and `exit` ends the shell.

`help` reads the `# summary:` comment of each file. An unknown name prints the
help and exits non-zero.

## Layout

```
bin/kitty-sessionizer   Find the repository, load the prelude, run one action
libexec/*.zsh           One file per action
lib/bootstrap.zsh       ks_use, ks_die, ks_require_tools
lib/config.zsh          Every tunable value
lib/common.zsh          The prelude: config, ui and small helpers
lib/ui.zsh              Colours, messages, key and line prompts
lib/kitty.zsh           Wrappers over `kitten @`
lib/git.zsh             Wrappers over `git`
lib/gum.zsh             Wrappers over `gum`: line, choice, confirm, spinner
lib/session.zsh         Session files and the record of open sessions
lib/discovery.zsh       Stream the candidate paths
lib/picker.zsh          Row format, row order, fzf run, selection parse
kitty/autosave.py       kitty watcher that saves open sessions
tests/                  Tests, run with `make test`
```

## Add an action

1. Write `libexec/<name>.zsh`.
2. Put `# summary: <one line>` on the first line. `help` shows it.
3. Call `ks_use <module> …` for the modules you need. `config` and `ui` are
   already loaded. A module loads once, so list every module you use.
4. Bind a key in `kitty.conf`, see [Bind a key](#bind-a-key).
5. Add the action to the `Use` list in the README.

The dispatcher finds the file on its own. Nothing else changes.

A short action looks like this:

```zsh
# summary: Switch back to the session you were in before the current one

ks_use kitty session

ks_session_last
```

## Bind a key

An action that asks a question needs a terminal. Run it in an overlay:

```
map alt+shift+p launch --type=overlay --title "Project Selector" /bin/zsh ~/.local/bin/kitty-sessionizer open
```

An action that asks nothing runs in the background through
`remote_control_script`, so no window opens:

```
map alt+shift+[ remote_control_script /bin/zsh ~/.local/bin/kitty-sessionizer prev
```

Do not use `launch --type=background`. kitty gives such a window no remote
control, so every `kitten @` call fails.

The Nix module lists the actions and their keys in `nix/hm-module.nix`. Add a
new action there too, so a Nix user gets the binding.

## Conventions

The actions share a few habits. Follow them, so a reader of one action can
read the next one.

### Results

A function returns one value in `REPLY` and a list in the array `reply`. It
returns 0 even when the value is empty. The caller checks the value, not the
exit status:

```zsh
ks_tracker_current
current="$REPLY"
[[ -n "$current" ]] || return 0
```

### Errors

`ks_die <message>` prints `kitty-sessionizer: <message>` to standard error and
exits 1. Use it for a state the action cannot work with. Use a message and
`return` for a cancel, because a cancel is not an error.

Every `kitten @` call goes through `ks_kitty`, which drops the error. kitty is
not always reachable, and a failed call must never stop an action.

The shell runs with `set -euo pipefail`. A command that may fail goes inside
an `if`, or takes `|| true`, so the overlay does not close before the reader
sees why.

### Prompts

`lib/gum.zsh` holds the prompts: `ks_gum_input`, `ks_gum_choose`,
`ks_gum_choose_many`, `ks_gum_confirm` and `ks_gum_spin`. Each one turns Esc
and Ctrl-C into an empty result, which the action reads as a cancel. Print the
lines between prompts with `ks_gum_line`, so they share the margin of the
prompts.

kitty closes the overlay as soon as the action returns. End an action that
shows a result with `ks_pause`, so the reader can see it.

### Sessions

Every action that enters a project calls `ks_session_enter <path>`. It makes
the session file, records the move, switches kitty and brings back the default
tabs. Save the session you leave first, with `ks_kitty_save_session`, because
each action leaves at a different moment.

A move that must not change the order of the open sessions, such as `prev`,
uses `ks_tracker_set_current` and `ks_session_goto` instead.

### Variables

An action runs at the top level, so its variables are global. Give them the
`ks_` prefix, and declare them with `typeset -g`. A function uses `local`.

Do not name a variable `path`. zsh ties it to `PATH`, and a local `path`
clobbers the search path of the shell.

### Where a helper belongs

A helper goes in `lib/common.zsh` only when two or more modules call it and it
knows nothing about kitty or about sessions. A helper that names a session
file or a `kitten` command goes in `lib/session.zsh` or `lib/kitty.zsh`. A
helper that only one action uses stays in that action.

## Change an action

1. Read the action and the modules it uses. The comments hold the reasons for
   the code.
2. Make the smallest change that does the job.
3. Run `make test`. It parses every script first, so a syntax error shows
   before any test runs.
4. Try the action in kitty. The README section [Develop](../README.md#develop)
   shows how to point it at throwaway state.
5. Update the README when the behaviour the user sees changes.

## Tests

`tests/test_session.zsh` tests the session record, the save guard and the
picker. `kitten` is faked by `tests/fake-kitten`, so no kitty has to run. The
fake prints a canned `ls` and logs every other call, one argument per line.

A test is a function whose name starts with `test_`. It runs in a subshell
with its own state, so a test cannot leak into the next one. To add one:

1. Write `test_<what_it_checks>()` in `tests/test_session.zsh`.
2. Put the canned `ls` output in `FAKE_LS`, `FAKE_LS_FOCUSED` or
   `FAKE_LS_SESSION` with `ls_json` or `ls_tabs`.
3. Call the function under test, then compare `FAKE_LOG` or the state files
   with `assert_eq`.

`tests/test_autosave.py` tests the watcher in the Python of kitty. It fakes
the kitty `boss`, so a test gives it the windows of each session and checks
which files were written.
