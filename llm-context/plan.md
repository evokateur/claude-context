# cc-from.sh Implementation Plan

## Purpose
Script to sync Claude Code context from another machine.

## Requirements
1. Takes one argument: `from` (machine name)
2. Determines current directory and extracts:
   - Username from path
   - Project name from directory basename
3. Creates `project` variable in format: `-Users-{username}-{project}`
   - Example: `/Users/wesley/code/cc-from` → `-Users-wesley-cc-from`
4. This matches Claude Code's context directory naming in `~/.claude/projects/`

## Implementation Steps
1. Parse `from` argument
2. Get current working directory using `pwd`
3. Extract username from path (assuming `/Users/{username}/...` structure)
4. Extract project name from directory basename
5. Construct project variable as `-Users-{username}-{project}`

## Edge Cases to Consider
- What if not run from `/Users/{username}/` path?
- What if `from_machine` argument is missing?
- What if `from_machine` is the same as current machine?
- What if `from_machine` is not accessible over SSH?
- What if the context directory doesn't exist on `from_machine`?

## Validation Checks
1. Check if `from_machine` is not the same as current machine (using `hostname`)
2. Check if `from_machine` is accessible over SSH
3. Check if `~/.claude/projects/{claude_context_dir}` exists on `from_machine`

## Refactored Function Structure

### Functions
1. `backup_context()` - Creates timestamped backup of current project context
   - Creates `~/.claude/backups/projects/{claude_context_dir}_{timestamp}.tar.gz`
   - Returns backup file path

2. `restore_context()` - Restores from most recent backup (stack-like)
   - Finds latest backup by timestamp
   - Extracts to `~/.claude/projects/`
   - Like popping from a stack

3. `sync_from_machine()` - Main sync operation
   - Calls `backup_context()` first (safety)
   - Syncs from remote machine using rsync
   - Performs all validation checks

### Main Script
- Parse arguments
- Determine operation (sync vs restore)
- Call appropriate function

## Next Steps
- Implement function-based structure
- Add restore functionality
- Complete sync implementation with rsync
