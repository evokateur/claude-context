# Claude Code project context sync and backup

Shell functions I use for copying Claude Code project context from remote machines with local backups.

## Syncing Claude Code contexts between machines

To pick up where I left off on another machine I sync the context directory in `~/.claude/projects` that corresponds to the code directory I'm working in. 

The copy function below derives the context directory from the current working directory. It takes into account differences in home directory structure.

For example, `~/code/catbutt` will have context at 
- `~/.claude/projects/-home-wesley-code-catbutt` on Linux and 
- `~/.claude/projects/-Users-wesley-code-catbutt` on macOS.

If the relative path is the same on both machines, I only need to specify the host:

```sh
~/code-catbutt$ cc-copy xicamatl
```

The remote path spec is only necessary to sync context for different relative directory on the remote, i.e. `~/projects/catbutt`:

```sh
~/code/catbutt$ cc-copy xicamatl:projects/catbutt
```

## Functions

- `cc-copy [--dry-run] <host[:path]>`
  - Syncs a specific context in `~/.claude/projects` from specified remote host to local machine using `rsync`
  - Determines local Claude Code project context directory from current working directory
  - Determines remote context directory based on remote `$HOME` + relative path
  - Assumes code directory has same relative path on both machines unless specified using `host:path` syntax
  - If the local context directory exists, a backup is created before overwriting

- `cc-backup`
  - Creates a timestamped backup of the Claude Code project context for the current working directory
  - Backup stored in `~/.claude/backups/projects/` as `{context-dir}_{timestamp}.tar.gz`

- `cc-restore`
  - Restores the most recent backup for the current working directory's Claude Code project context
  - Keeps the backup file intact after restoration
  - See source for restoring specific backups by timestamp

- `cc-pop`
  - Restores the most recent backup for the current working directory's Claude Code project context
  - Deletes the backup file after successful restoration

## Requirements

- Claude Code (`~/.claude/projects/` directory must exist)
- Read/write access to `~/.claude/projects/`
- Read/write access to `~/.claude/backups/projects/`

### For `cc-copy`

- Passwordless SSH access to remote machine
  - SSH key-based authentication configured
  - Remote host accessible via `ssh <hostname>` or `ssh <user@host>`
- `rsync` installed on both local and remote machines

## Setup

- Clone or download this repository
- (optional) Move the script somewhere, as you like (e.g. `~/.config/shell/functions`)
- `source` the script in your shell configuration file (e.g., `.bashrc`, `.zshrc`)
