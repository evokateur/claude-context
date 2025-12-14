# Claude Code project context sync and backup

Shell functions for rsyncing Claude Code project context from remote machines and managing local backups.

## Functions

- `cc-copy [--dry-run] <host[:path]>`
  - Syncs a specific context in `~/.claude/projects` from specified remote host to local machine using `rsync`
  - Determines local Claude Code project context directory from current working directory
  - Determines remote Claude Code project context directory based on remote `$HOME` + relative path
  - Assumes project directory has same relative path on both machines unless specified using `host:path` syntax
  - If the local project context exists, a backup is created before overwriting

- `cc-backup`
  - Creates a timestamped backup of the Claude Code project context for the current working directory
  - Backup stored in `~/.claude/backups/projects/` as `{context-dir}_{timestamp}.tar.gz`

- `cc-restore`
  - Restores the most recent backup for the current working directory's Claude Code project context
  - Keeps the backup file intact after restoration
  - See source for restoring specific backups by timestamp

- `cc-pop`
  - Restores the most recent backup for the current working directory's Claude Code project context
  - Deletes the backup file after successful restoration (stack-like "pop" operation)

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
