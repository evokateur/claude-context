backup_dir="$HOME/.claude/backups/projects"

get_context_vars() {
    current_dir=$(pwd)
    claude_context_dir=$(echo "$current_dir" | sed 's/\//-/g')
    local_context_path="$HOME/.claude/projects/$claude_context_dir"
}

backup_cc() {
    get_context_vars
    if [ ! -d "$local_context_path" ]; then
        echo "Error: Claude context directory does not exist on this machine"
        echo "Expected path: $local_context_path"
        return 1
    fi

    mkdir -p "$backup_dir"

    timestamp=$(date +%Y%m%d-%H%M%S)
    backup_file="${backup_dir}/${claude_context_dir}_${timestamp}.tar.gz"

    echo "Creating backup of local context directory..."
    cd "$HOME/.claude/projects"
    tar czf "$backup_file" "./$claude_context_dir/"

    echo "Backup created: $backup_file"
    echo "$backup_file"
}

restore_cc() {
    get_context_vars
    latest_backup=$(ls -1 "$backup_dir/${claude_context_dir}_"*.tar.gz 2>/dev/null | sort -r | head -1)

    if [ -z "$latest_backup" ]; then
        echo "Error: No backups found for $claude_context_dir"
        return 1
    fi

    echo "Restoring from: $latest_backup"

    if [ -d "$local_context_path" ]; then
        echo "Removing current context directory..."
        rm -rf "$local_context_path"
    fi

    echo "Extracting backup..."
    tar zxf "$latest_backup" -C "$HOME/.claude/projects/"

    echo "Restore complete!"
}

push_cc() {
    backup_cc
}

pop_cc() {
    get_context_vars
    latest_backup=$(ls -1 "$backup_dir/${claude_context_dir}_"*.tar.gz 2>/dev/null | sort -r | head -1)

    if [ -z "$latest_backup" ]; then
        echo "Error: No backups found for $claude_context_dir"
        return 1
    fi

    echo "Restoring from: $latest_backup"

    if [ -d "$local_context_path" ]; then
        echo "Removing current context directory..."
        rm -rf "$local_context_path"
    fi

    echo "Extracting backup..."
    tar zxf "$latest_backup" -C "$HOME/.claude/projects/"

    echo "Removing backup: $latest_backup"
    rm "$latest_backup"

    echo "Pop complete!"
}

copy_cc_from() {
    get_context_vars

    dry_run=false
    from_machine=""

    while [[ $# -gt 0 ]]; do
        case $1 in
        --dry-run)
            dry_run=true
            shift
            ;;
        *)
            from_machine="$1"
            shift
            ;;
        esac
    done

    dry_run=true # HIJACKED: always set to true for now

    if [ -z "$from_machine" ]; then
        echo "Error: from_machine argument is required"
        echo "Usage: copy_cc_from [--dry-run] <machine-name>"
        return 1
    fi

    this_machine=$(hostname -s)

    if [ "$from_machine" = "$this_machine" ]; then
        echo "Error: from_machine ($from_machine) is the same as this machine"
        return 1
    fi

    if [ ! -d "$HOME/.claude/projects" ]; then
        echo "Error: $HOME/.claude/projects directory does not exist"
        echo "Is Claude Code installed?"
        return 1
    fi

    echo "Checking SSH connectivity to $from_machine..."
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$from_machine" exit 2>/dev/null; then
        echo "Error: Cannot connect to $from_machine over SSH"
        return 1
    fi

    echo "Checking if Claude context directory exists on $from_machine..."
    remote_path="~/.claude/projects/$claude_context_dir"
    if ! ssh "$from_machine" "test -d $remote_path" 2>/dev/null; then
        echo "Error: Claude context directory does not exist on $from_machine"
        echo "Expected path: $remote_path"
        return 1
    fi

    echo "From machine: $from_machine"
    echo "Claude context directory: $claude_context_dir"
    echo "All checks passed!"

    if [ -d "$local_context_path" ]; then
        backup_cc
        echo ""
    fi

    if [ "$dry_run" = true ]; then
        echo "Dry run - showing what would be transferred:"
        rsync -av --delete --dry-run "${from_machine}:~/.claude/projects/${claude_context_dir}/" "${local_context_path}/"
    else
        echo "Syncing from $from_machine..."
        rsync -av --delete "${from_machine}:~/.claude/projects/${claude_context_dir}/" "${local_context_path}/"
        echo "Sync complete!"
    fi
}
