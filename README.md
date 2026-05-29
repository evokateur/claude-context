# Claude Code project context sync and backup

Shell functions for syncing and backing up Claude Code project context across machines.

## Syncing context between machines

`cc-sync` (or `cc-sync from`) syncs the context for the CWD in `~/.claude/projects` from a remote.

`cc-sync to` syncs context for the CWD to a remote.

Since the remote path is determined relative to `$HOME`, the CWD must be within `$HOME`.

The remote OS is taken into account when determining the context directory; context for `~/code/catbutt` would be in

- `~/.claude/projects/-home-username-code-catbutt` on Linux and
- `~/.claude/projects/-Users-username-code-catbutt` on macOS.

Context for the same relative path on the remote is assumed:

```sh
~/code/catbutt$ cc-sync xicamatl 
# same as:
~/code/catbutt$ cc-sync xicamatl:code/catbutt
```

The remote relative path can be specified if different:

```sh
~/code/catbutt$ cc-sync xicamatl:projects/catbutt
```

A relative path can be used with `localhost` to retrieve the context of a renamed project:

```sh
~/code/cul-de-chat$ cc-sync localhost:code/catbutt
```

To sync the local context to a remote:

```sh
~/code/catbutt$ cc-sync to xicamatl
```

As with `cc-sync [from]`, the remote relative path can be specified.

`cc-sync [from]` and `cc-sync to` are `rsync` wrappers. By default `rsync` commands are additive, consolidating context across machines. Using the `--delete` option (without `--files-from`, see below) will clobber the destination with the source.

A backup of existing destination context is created before syncing when files would be transferred, except with `--dry-run`.

### Limiting what files from the source are synced

- `--find-args '<expression>'` writes the output of `find <expression>` to `/tmp` for `rsync --files-from <file-list>`
- `--modified-within <days>` is equivalent to `--find-args '-type f -mtime -<days>'`
- `--modified-within` and `--find-args` are mutually exclusive
- `--delete` with either will *not* delete files not in the `find` output

Examples:

```sh
~/code/catbutt$ cc-sync --modified-within-days 3 xicamatl
~/code/catbutt$ cc-sync to --find-expr "-type f -name '*.jsonl'" --dry-run xicamatl
```

## Listing context directory contents

`cc-sync list` shows the local context directory for the CWD with `ls -l -t`.

`cc-sync list host` shows the matching remote context directory with `ls -l -t`.

`cc-sync ls` and `cc-sync ls host` are aliases for the same commands.

## Functions

- `cc-sync [from|to] [rsync-options] <host[:path]>`
  - Wraps `rsync -av` with passthrough of the following options:
    - `--dry-run`, `-n`: preview what would be transferred
    - `--delete`: clobber the destination, removing context not present in the source
    - `-z`, `--compress`: compress data during transfer
  - Bounded sync options:
    - `--modified-within-days <days>`: select regular files matching `find . -type f -mtime -<days>`
    - `--find-expr '<expression>'`: select files using `find . <expression>`
  - Local context directory determined by CWD
  - Remote context determined by the same relative path unless `:path` is specified
  - If `from` or `to` is omitted, `from` is assumed
  - `cc-sync to` creates the remote context directory if it doesn't exist

- `cc-sync backup`
  - Creates a context backup for current working directory
  - Backups are stored in `~/.claude/backups/projects/` as `{context-dir}_{timestamp}.tar.gz`

- `cc-sync restore`
  - Restores the most recent backup for current working directory without deleting the backup

- `cc-sync pop`
  - Restores the most recent backup for current working directory and deletes the backup file

- `cc-sync [list|ls] [host[:path]]`
  - Lists the local or remote context directory for the current working directory
  - Uses `ls -l -t` to show newest entries first
  - If `host[:path]` is omitted, lists the local context directory

## Requirements

- Claude Code (`~/.claude/projects/` directory must exist)
- Read/write access to `~/.claude/projects/` and `~/.claude/backups/projects/`

### For `cc-sync`

- Passwordless SSH access to remote machine
- `rsync` installed on both machines

## Setup

- Source `claude-context.sh` path in `.zshrc` or `.bashrc` etc.
