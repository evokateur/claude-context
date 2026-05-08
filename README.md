# Claude Code project context sync and backup

Shell functions for syncing Claude Code project context across machines, with local backups.

## Syncing contexts between machines

`cc-sync` rsyncs a context directory in `~/.claude/projects` between machines. By default it pulls from a remote machine to the local machine. With `--push`, it pushes the local context to the remote machine. It derives context directory names from the current working directory, accounting for OS home directory path differences.

For example, `~/code/catbutt` will have context at
- `~/.claude/projects/-home-wesley-code-catbutt` on Linux and
- `~/.claude/projects/-Users-wesley-code-catbutt` on macOS.

If the relative path is the same on both machines, only the host is needed:

```sh
~/code/catbutt$ cc-sync xicamatl
```

A remote path is necessary when the relative directory differs:

```sh
~/code/catbutt$ cc-sync xicamatl:projects/catbutt
```

To retrieve the context of a renamed project:

```sh
~/code/cul-de-chat$ cc-sync localhost:code/catbutt
```

By default (`rsync` and therefore) `cc-sync` is additive, consolidating context across machines. Use `--delete` to make local match remote exactly.

A backup of the destination context directory is created before syncing, except with `--dry-run`.

To push the local context to the remote machine:

```sh
~/code/catbutt$ cc-sync --push xicamatl
```

If the target project path differs on the remote machine:

```sh
~/code/catbutt$ cc-sync --push xicamatl:projects/catbutt
```

When pushing, `cc-sync` creates the remote context directory if it does not already exist.

## Functions

- `cc-sync [rsync-options] <host[:path]>`
  - Wraps `rsync -av` with passthrough of recognized rsync options:
    - `--push`: sync local context to remote instead of pulling from remote
    - `--dry-run`, `-n`: preview what would be transferred
    - `--delete`: remove local context not present on remote
    - `-z`, `--compress`: compress data during transfer
  - Context directories determined with tilde expansions of CWD relative to  `~/`
  - Assumes same relative path on remote unless `:path` is specified.

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
