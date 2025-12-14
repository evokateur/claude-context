# Claude Context Syncing and Backup Management

Shell functions for syncing Claude Code conversation context from remote machines and managing local backups.

## Functions

- `cc-copy [--dry-run] <host[:path]>`
  - Syncs Claude Code project context from specified remote host to local machine using `rsync`
  - Determines local Claude context directory from current working directory
  - Determines remote Claude context directory based on remote `$HOME` + relative path
  - Assumes project directory has same relative path from `$HOME` on both machines unless specified using `host:path` syntax
  - If the local project context exists, a backup is created before overwriting

- `cc-backup`
  - Creates a timestamped backup of the current Claude Code project context in `~/.claude/backups/projects/`

- `cc-restore`
  - Restores the most recent backup of the current Claude Code project context

- `cc-pop`
  - Restores the most recent backup of the current Claude Code project context, deleting that backup after restoration

## Requirements

- Claude Code (`~/.claude/projects/` directory must exist)
- Read/write access to `~/.claude/projects/`
- Read/write access to `~/.claude/backups/projects/`

### For `cc-copy`

- Passwordless SSH access to remote machine
  - SSH key-based authentication configured
  - Remote host accessible via `ssh <hostname>` or `ssh <user@host>`
- `rsync` installed on both local and remote machines
