get_context_vars() {
    if [ ! -d "$HOME/.claude/projects" ]; then
        echo "Error: $HOME/.claude/projects directory does not exist"
        echo "Is Claude Code installed?"
        return 1
    fi

    backup_dir="$HOME/.claude/backups/projects"
    current_dir=$(pwd)
    claude_context_dir=$(echo "$current_dir" | sed 's/\//-/g')
    local_context_path="$HOME/.claude/projects/$claude_context_dir"
}

cc-backup() {
    get_context_vars || return 1
    if [ ! -d "$local_context_path" ]; then
        echo "Error: Claude context directory does not exist on this machine"
        echo "Expected path: $local_context_path"
        return 1
    fi

    mkdir -p "$backup_dir"

    timestamp=$(date +%Y%m%d-%H%M%S)
    backup_file="${backup_dir}/${claude_context_dir}_${timestamp}.tar.gz"

    echo "Creating backup of local context directory..."
    (cd "$HOME/.claude/projects" && tar czf "$backup_file" "./$claude_context_dir/")

    echo "Backup created: $backup_file"
    echo "$backup_file"
}

cc-restore() {
    get_context_vars || return 1
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

cc-pop() {
    get_context_vars || return 1
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

cc-copy() {
    get_context_vars || return 1

    dry_run=false
    remote_host=""

    while [[ $# -gt 0 ]]; do
        case $1 in
        --dry-run)
            dry_run=true
            shift
            ;;
        *)
            remote_host="$1"
            shift
            ;;
        esac
    done

    if [ -z "$remote_host" ]; then
        echo "Error: remote host argument is required"
        echo "Usage: cc-copy [--dry-run] <remote-host>"
        return 1
    fi

    echo "Checking SSH connectivity to $remote_host..."
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$remote_host" exit 2>/dev/null; then
        echo "Error: Cannot connect to $remote_host over SSH"
        return 1
    fi

    echo "Detecting remote home directory..."
    remote_home=$(ssh "$remote_host" "echo \$HOME" 2>/dev/null)
    if [ -z "$remote_home" ]; then
        echo "Error: Could not determine remote home directory"
        return 1
    fi

    relative_path="${current_dir#$HOME/}"
    remote_full_path="${remote_home}/${relative_path}"
    remote_context_dir=$(echo "$remote_full_path" | sed 's/\//-/g')

    echo "Checking if Claude context directory exists on $remote_host..."
    remote_path="${remote_home}/.claude/projects/$remote_context_dir"
    if ! ssh "$remote_host" "test -d $remote_path" 2>/dev/null; then
        echo "Error: Claude context directory does not exist on $remote_host"
        echo "Expected path: $remote_path"
        return 1
    fi

    echo "From machine: $remote_host"
    echo "Claude context directory: $claude_context_dir"
    echo "All checks passed!"

    if [ "$dry_run" = true ]; then
        echo ""
        echo "Dry run - showing what would be transferred:"
        rsync -av --delete --dry-run "${remote_host}:${remote_path}/" "${local_context_path}/"
    else
        if [ -d "$local_context_path" ]; then
            cc-backup
            echo ""
        fi
        echo "Syncing from $remote_host..."
        rsync -av --delete "${remote_host}:${remote_path}/" "${local_context_path}/"
        echo "Sync complete!"
    fi
}
