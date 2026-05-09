# Claude Code project context sync and backup

Shell functions for syncing Claude Code project context across machines, with local backups.

## Syncing contexts between machines

`cc-sync-from` and `cc-sync-to` rsync a context directory in `~/.claude/projects` between machines. `cc-sync-from` pulls from a remote machine to the local machine. `cc-sync-to` pushes the local context to the remote machine. `cc-sync` remains an alias for `cc-sync-from`. The functions derive context directory names from the current working directory, accounting for OS home directory path differences.

For example, `~/code/catbutt` will have context at
- `~/.claude/projects/-home-wesley-code-catbutt` on Linux and
- `~/.claude/projects/-Users-wesley-code-catbutt` on macOS.

If the relative path is the same on both machines, only the host is needed:

```sh
~/code/catbutt$ cc-sync-from xicamatl
```

A remote path is necessary when the relative directory differs:

```sh
~/code/catbutt$ cc-sync-from xicamatl:projects/catbutt
```

To retrieve the context of a renamed project:

```sh
~/code/cul-de-chat$ cc-sync-from localhost:code/catbutt
```

By default (`rsync` and therefore) these sync commands are additive, consolidating context across machines. Use `--delete` to make the destination match the source exactly.

A backup of the destination context directory is created before syncing, except with `--dry-run`.

To push the local context to the remote machine:

```sh
~/code/catbutt$ cc-sync-to xicamatl
```

If the target project path differs on the remote machine:

```sh
~/code/catbutt$ cc-sync-to xicamatl:projects/catbutt
```

When pushing, `cc-sync-to` creates the remote context directory if it does not already exist.

## Functions

- `cc-sync-from [rsync-options] <host[:path]>`
  - Wraps `rsync -av` with passthrough of recognized rsync options:
    - `--dry-run`, `-n`: preview what would be transferred
    - `--delete`: remove local context not present in the remote source
    - `-z`, `--compress`: compress data during transfer
  - Context directories determined with tilde expansions of CWD relative to  `~/`
  - Assumes same relative path on remote unless `:path` is specified.

- `cc-sync-to [rsync-options] <host[:path]>`
  - Wraps `rsync -av` with passthrough of recognized rsync options:
    - `--dry-run`, `-n`: preview what would be transferred
    - `--delete`: remove remote context not present in the local source
    - `-z`, `--compress`: compress data during transfer
  - Context directories determined with tilde expansions of CWD relative to  `~/`
  - Assumes same relative path on remote unless `:path` is specified.

- `cc-sync [rsync-options] <host[:path]>`
  - Alias for `cc-sync-from`

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
