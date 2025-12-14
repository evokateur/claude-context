set_vars() {
    if [ ! -d "$HOME/.claude/projects" ]; then
        echo "Error: $HOME/.claude/projects directory does not exist"
        echo "Is Claude Code installed?"
        return 1
    fi

    backup_dir="$HOME/.claude/backups/projects"
    current_dir=$(pwd)
    local_context_dir=$(echo "$current_dir" | sed 's/\//-/g')
    local_context_path="$HOME/.claude/projects/$local_context_dir"
}

set_remote_context_path() {
    remote_host="$1"
    relative_path="$2"

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

    remote_full_path="${remote_home}/${relative_path}"
    remote_context_dir=$(echo "$remote_full_path" | sed 's/\//-/g')
    remote_context_path="${remote_home}/.claude/projects/$remote_context_dir"

    echo "Checking if Claude context directory exists on $remote_host..."
    if ! ssh "$remote_host" "test -d $remote_context_path" 2>/dev/null; then
        echo "Error: Claude context directory does not exist on $remote_host"
        echo "Expected path: $remote_context_path"
        return 1
    fi
}

cc-backup() {
    set_vars || return 1
    if [ ! -d "$local_context_path" ]; then
        echo "Error: Claude context directory does not exist on this machine"
        echo "Expected path: $local_context_path"
        return 1
    fi

    mkdir -p "$backup_dir"

    timestamp=$(date +%Y%m%d-%H%M%S)
    backup_file="${backup_dir}/${local_context_dir}_${timestamp}.tar.gz"

    echo "Creating backup of local context directory..."
    (cd "$HOME/.claude/projects" && tar czf "$backup_file" "./$local_context_dir/")

    echo "Backup created: $backup_file"
    echo "$backup_file"
}

cc-pop() {
    set_vars || return 1

    delete_backup=true
    if [ "$1" = "--no-delete" ]; then
        delete_backup=false
    fi

    latest_backup=$(ls -1 "$backup_dir/${local_context_dir}_"*.tar.gz 2>/dev/null | sort -r | head -1)

    if [ -z "$latest_backup" ]; then
        echo "Error: No backups found for $local_context_dir"
        return 1
    fi

    echo "Restoring from: $latest_backup"

    if [ -d "$local_context_path" ]; then
        echo "Removing current context directory..."
        rm -rf "$local_context_path"
    fi

    echo "Extracting backup..."
    tar zxf "$latest_backup" -C "$HOME/.claude/projects/"

    if [ "$delete_backup" = true ]; then
        echo "Removing backup: $latest_backup"
        rm "$latest_backup"
        echo "Pop complete!"
    else
        echo "Restore complete!"
    fi
}

cc-restore() {
    cc-pop --no-delete
}

cc-copy() {
    set_vars || return 1

    dry_run=false
    remote_spec=""

    while [[ $# -gt 0 ]]; do
        case $1 in
        --dry-run)
            dry_run=true
            shift
            ;;
        *)
            remote_spec="$1"
            shift
            ;;
        esac
    done

    if [ -z "$remote_spec" ]; then
        echo "Error: remote host argument is required"
        echo "Usage: cc-copy [--dry-run] <remote-host[:path]>"
        return 1
    fi

    if [[ "$remote_spec" == *:* ]]; then
        remote_host="${remote_spec%%:*}"
        relative_path="${remote_spec#*:}"
    else
        remote_host="$remote_spec"
        relative_path="${current_dir#$HOME/}"
    fi

    set_remote_context_path "$remote_host" "$relative_path" || return 1

    echo "Remote host: $remote_host"
    echo "Remote context directory: $remote_context_path"
    echo "Local context directory: $local_context_path"

    if [ "$dry_run" = true ]; then
        echo ""
        echo "Dry run - showing what would be transferred:"
        rsync -av --delete --dry-run "${remote_host}:${remote_context_path}/" "${local_context_path}/"
    else
        if [ -d "$local_context_path" ]; then
            cc-backup
            echo ""
        fi
        echo "Syncing from $remote_host..."
        rsync -av --delete "${remote_host}:${remote_context_path}/" "${local_context_path}/"
        echo "Sync complete!"
    fi
}
