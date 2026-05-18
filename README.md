# Claude Code project context sync and backup

Shell functions for syncing Claude Code project context across machines, with local backups.

## Syncing contexts between machines

`cc-sync` syncs a context directory in `~/.claude/projects` between machines. `cc-sync pull` pulls from a remote machine to the local machine. `cc-sync push` pushes the local context to the remote machine. `cc-sync <host[:path]>` remains shorthand for `cc-sync pull <host[:path]>`. The functions derive context directory names from the current working directory, accounting for OS home directory path differences.

For example, `~/code/catbutt` will have context at
- `~/.claude/projects/-home-wesley-code-catbutt` on Linux and
- `~/.claude/projects/-Users-wesley-code-catbutt` on macOS.

If the relative path is the same on both machines, only the host is needed:

```sh
~/code/catbutt$ cc-sync pull xicamatl
```

A remote path is necessary when the relative directory differs:

```sh
~/code/catbutt$ cc-sync pull xicamatl:projects/catbutt
```

To retrieve the context of a renamed project:

```sh
~/code/cul-de-chat$ cc-sync pull localhost:code/catbutt
```

By default (`rsync` and therefore) these sync commands are additive, consolidating context across machines. Use `--delete` to make the destination match the source exactly.

A backup of the destination context directory is created before syncing, except with `--dry-run`.

To push the local context to the remote machine:

```sh
~/code/catbutt$ cc-sync push xicamatl
```

If the target project path differs on the remote machine:

```sh
~/code/catbutt$ cc-sync push xicamatl:projects/catbutt
```

When pushing, `cc-sync push` creates the remote context directory if it does not already exist.

Recognized rsync options may appear before or after `pull`/`push`:

```sh
~/code/catbutt$ cc-sync --dry-run push xicamatl
~/code/catbutt$ cc-sync push --dry-run xicamatl
~/code/catbutt$ cc-sync --dry-run xicamatl
```

Non-sync subcommands do not accept rsync options.

## Functions

- `cc-sync [pull|push] [rsync-options] <host[:path]>`
  - Wraps `rsync -av` with passthrough of recognized rsync options:
    - `--dry-run`, `-n`: preview what would be transferred
    - `--delete`: remove destination context not present in the source
    - `-z`, `--compress`: compress data during transfer
  - Context directories determined with tilde expansions of CWD relative to  `~/`
  - Assumes same relative path on remote unless `:path` is specified
  - If `pull` or `push` is omitted, defaults to `pull`

- `cc-sync backup`
  - Creates a context backup for current working directory

- `cc-sync restore`
  - Restores the most recent backup for current working directory without deleting the backup

- `cc-sync pop`
  - Restores the most recent backup for current working directory and deletes the backup file

- Compatibility wrappers:
  - `cc-sync-from` -> `cc-sync pull`
  - `cc-sync-to` -> `cc-sync push`
  - `cc-backup` -> `cc-sync backup`
  - `cc-restore` -> `cc-sync restore`
  - `cc-pop` -> `cc-sync pop`

- `cc-backup`
  - Creates a context backup for current working directory
  - Stored in `~/.claude/backups/projects/` as `{context-dir}_{timestamp}.tar.gz`

- `cc-restore`
  - Restores the most recent backup for current working directory

- `cc-pop`
  - Restores the most recent backup for current working directory
  - Deletes the backup file after restoration

## Requirements

- Claude Code (`~/.claude/projects/` directory must exist)
- Read/write access to `~/.claude/projects/` and `~/.claude/backups/projects/`

### For `cc-sync`

- Passwordless SSH access to remote machine
- `rsync` installed on both machines

## Setup

- Source `claude-context.sh` path in `.zshrc` or `.bashrc` etc.)
