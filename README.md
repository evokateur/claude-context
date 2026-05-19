# Claude Code project context sync and backup

Shell functions for syncing Claude Code project context across machines, with local backups.

## Syncing contexts between machines

`cc-sync` syncs a context directory in `~/.claude/projects` between machines. by default pulling from remote to local (`cc-sync pull`). 

`cc-sync push` pushes the local context to the remote machine. 

The functions derive remote context directory names from the current working directory, accounting for home directory absolute path differences by OS. As an example, `~/code/catbutt` will have context in

- `~/.claude/projects/-home-wesley-code-catbutt` on Linux and
- `~/.claude/projects/-Users-wesley-code-catbutt` on macOS.

If the project path relative to `$HOME` is the same on both machines, only the host is needed:

```sh
~/code/catbutt$ cc-sync [pull] xicamatl
```

An explicit remote path is necessary when the relative directory differs:

```sh
~/code/catbutt$ cc-sync xicamatl:projects/catbutt
```

An explicit path can be used with `localhost` to retrieve the context of a renamed project:

```sh
~/code/cul-de-chat$ cc-sync localhost:code/catbutt
```

Paths inside or relative to `$HOME` are assumed. The local CWD must be inside `$HOME`, and paths after `hostname:` must be relative to `$HOME`.

`pull` and `push` are `rsync` wrappers. By default `rsync` commands are additive, consolidating context across machines. Using the `--delete` option will make the destination match the source exactly.

A backup of the destination context directory is created before syncing, except with `--dry-run`.

To *push* the local context to a remote:

```sh
~/code/catbutt$ cc-sync push xicamatl
```

As with `pull`, the remote relative path can be explicit.

## Functions

- `cc-sync [pull|push] [rsync-options] <host[:path]>`
  - Wraps `rsync -av` with passthrough of recognized rsync options:
    - `--dry-run`, `-n`: preview what would be transferred
    - `--delete`: remove destination context not present in the source
    - `-z`, `--compress`: compress data during transfer
  - Context directories determined with tilde expansions of CWD relative to  `~/`
  - Assumes same relative path on remote unless `:path` is specified
  - If `pull` or `push` is omitted, defaults to `pull`
  - `cc-sync push` creates the remote context directory if it does not already exist.

- `cc-sync backup`
  - Creates a context backup for current working directory

- `cc-sync restore`
  - Restores the most recent backup for current working directory without deleting the backup

- `cc-sync pop`
  - Restores the most recent backup for current working directory and deletes the backup file

- Backups are stored in `~/.claude/backups/projects/` as `{context-dir}_{timestamp}.tar.gz`

## Requirements

- Claude Code (`~/.claude/projects/` directory must exist)
- Read/write access to `~/.claude/projects/` and `~/.claude/backups/projects/`

### For `cc-sync`

- Passwordless SSH access to remote machine
- `rsync` installed on both machines

## Setup

- Source `claude-context.sh` path in `.zshrc` or `.bashrc` etc.)
