# Claude Code project context sync and backup

Shell functions that wrap `rsync` for syncing Claude Code project context between machines, with local backups.

## Syncing contexts between machines

`cc-sync` rsyncs a project's context directory in `~/.claude/projects` from a remote machine to the local machine. It derives context directory names from the current working directory, accounting for home directory path differences between OSes.

For example, `~/code/catbutt` will have context at
- `~/.claude/projects/-home-wesley-code-catbutt` on Linux and
- `~/.claude/projects/-Users-wesley-code-catbutt` on macOS.

If the relative path is the same on both machines, only the host is needed:

```sh
~/code/catbutt$ cc-sync xicamatl
```

A remote path is only necessary when the relative directory differs, e.g. `~/projects/catbutt`:

```sh
~/code/catbutt$ cc-sync xicamatl:projects/catbutt
```

One can also use it locally to retrieve the context of a renamed project:

```sh
~/code/cul-de-chat$ cc-sync localhost:code/catbutt
```

By default, `cc-sync` is additive — remote sessions are copied without removing local ones, consolidating sessions from both machines. Use `--delete` to make local match remote exactly.

A backup of the local context directory is created before syncing, except with `--dry-run`.

## Functions

- `cc-sync [rsync-options] <host[:path]>`
  - Wraps `rsync -av` with passthrough of recognized rsync options:
    - `--dry-run`, `-n`: preview what would be transferred (no backup made)
    - `--delete`: remove local files not present on remote (clobber mode)
    - `-z`, `--compress`: compress data during transfer
  - Determines context directories from current working directory and remote `$HOME`
  - Assumes same relative path on both machines unless specified with `host:path`

- `cc-backup`
  - Creates a timestamped backup of the current project's context directory
  - Stored in `~/.claude/backups/projects/` as `{context-dir}_{timestamp}.tar.gz`

- `cc-restore`
  - Restores the most recent backup of the current project's context
  - Keeps the backup file intact

- `cc-pop`
  - Restores the most recent backup of the current project's context
  - Deletes the backup file after restoration

## Requirements

- Claude Code (`~/.claude/projects/` directory must exist)
- Read/write access to `~/.claude/projects/` and `~/.claude/backups/projects/`

### For `cc-sync`

- Passwordless SSH access to remote machine
- `rsync` installed on both machines

## Setup

- Clone or download this repository
- (optional) Copy the script elsewhere, as you like (e.g. `~/.config/shell/functions/`)
- `source` the script in your shell configuration file (e.g., `.bashrc`, `.zshrc`)
