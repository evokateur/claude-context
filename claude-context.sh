_cc_sync_set_vars() {
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

_cc_sync_set_remote_context_path() {
    remote_host="$1"
    relative_path="$2"
    create_if_missing="${3:-false}"
    remote_context_exists=false

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
    if ! ssh "$remote_host" "test -d '$remote_context_path'" 2>/dev/null; then
        if [ "$create_if_missing" = true ]; then
            echo "Creating Claude context directory on $remote_host..."
            ssh "$remote_host" "mkdir -p '$remote_context_path'" || return 1
        else
            echo "Error: Claude context directory does not exist on $remote_host"
            echo "Expected path: $remote_context_path"
            return 1
        fi
    else
        remote_context_exists=true
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

_cc_sync_remote_backup() {
    remote_host="$1"
    remote_context_dir="$2"

    timestamp=$(date +%Y%m%d-%H%M%S)
    remote_backup_dir='$HOME/.claude/backups/projects'
    remote_backup_file="\$HOME/.claude/backups/projects/${remote_context_dir}_${timestamp}.tar.gz"

    echo "Creating backup of remote context directory on $remote_host..."
    ssh "$remote_host" "mkdir -p $remote_backup_dir && tar czf '$remote_backup_file' -C '\$HOME/.claude/projects' './$remote_context_dir/'" || return 1

    echo "Remote backup created: ${remote_host}:${remote_backup_file#\$HOME/}"
}

_cc_sync_has_files_to_sync() {
    local count
    count=$(rsync -av --dry-run "$@" 2>/dev/null |
        grep -cvE '^(building file list|sending incremental file list|receiving incremental file list|Transfer starting|sent |total size|\./|$)')
    [ "$count" -gt 0 ]
}

_cc_sync_parse_sync_operation_args() {
    sync_mode=""
    rsync_options=()
    dry_run=false
    remote_spec=""

    while [[ $# -gt 0 ]]; do
        case $1 in
        pull | push)
            if [ -n "$sync_mode" ] && [ "$sync_mode" != "$1" ]; then
                echo "Error: multiple sync directions specified"
                return 1
            fi
            sync_mode="$1"
            shift
            ;;
        --dry-run | -n)
            dry_run=true
            rsync_options+=("$1")
            shift
            ;;
        --delete | -z | --compress)
            rsync_options+=("$1")
            shift
            ;;
        *)
            if [ -n "$remote_spec" ]; then
                echo "Error: expected exactly one remote host argument"
                return 1
            fi
            remote_spec="$1"
            shift
            ;;
        esac
    done

    if [ -z "$remote_spec" ]; then
        echo "Error: remote host argument is required"
        return 1
    fi
}

_cc_sync_parse_dispatch_args() {
    dispatch_command=""
    rsync_options=()
    dry_run=false
    remote_spec=""

    while [[ $# -gt 0 ]]; do
        case $1 in
        pull | push)
            if [ -n "$dispatch_command" ] && [ "$dispatch_command" != "$1" ]; then
                echo "Error: multiple subcommands specified"
                return 1
            fi
            dispatch_command="$1"
            shift
            ;;
        backup | restore | pop)
            if [ -n "$dispatch_command" ] && [ "$dispatch_command" != "$1" ]; then
                echo "Error: multiple subcommands specified"
                return 1
            fi
            dispatch_command="$1"
            shift
            ;;
        --dry-run | -n)
            dry_run=true
            rsync_options+=("$1")
            shift
            ;;
        --delete | -z | --compress)
            rsync_options+=("$1")
            shift
            ;;
        *)
            if [ -n "$remote_spec" ]; then
                echo "Error: expected exactly one remote host argument"
                return 1
            fi
            remote_spec="$1"
            shift
            ;;
        esac
    done
}

_cc_sync_set_remote_spec_vars() {
    if [ -z "$remote_spec" ]; then
        echo "Error: remote host argument is required"
        return 1
    fi

    if [[ "$remote_spec" == *:* ]]; then
        remote_host="${remote_spec%%:*}"
        relative_path="${remote_spec#*:}"
    else
        remote_host="$remote_spec"
        relative_path="${current_dir#$HOME/}"
    fi
}

_cc_sync_run_from() {
    _cc_sync_set_remote_context_path "$remote_host" "$relative_path" false || return 1

    sync_source="${remote_host}:${remote_context_path}/"
    sync_destination="${local_context_path}/"

    echo "Remote host: $remote_host"
    echo "Remote context directory: $remote_context_path"
    echo "Local context directory: $local_context_path"
    echo ""

    if [ "$dry_run" = false ] && _cc_sync_has_files_to_sync "${rsync_options[@]}" "$sync_source" "$sync_destination"; then
        if [ -d "$local_context_path" ]; then
            cc-backup
            echo ""
        fi
    fi

    if [ "$dry_run" = true ]; then
        echo "Previewing sync from $remote_host (dry run)..."
    else
        echo "Syncing from $remote_host..."
    fi
    rsync -av "${rsync_options[@]}" "$sync_source" "$sync_destination"
    echo "Done."
}

_cc_sync_run_to() {
    _cc_sync_set_remote_context_path "$remote_host" "$relative_path" true || return 1

    sync_source="${local_context_path}/"
    sync_destination="${remote_host}:${remote_context_path}/"

    echo "Remote host: $remote_host"
    echo "Remote context directory: $remote_context_path"
    echo "Local context directory: $local_context_path"
    echo ""

    if [ "$dry_run" = false ] && _cc_sync_has_files_to_sync "${rsync_options[@]}" "$sync_source" "$sync_destination"; then
        if [ "$remote_context_exists" = true ]; then
            _cc_sync_remote_backup "$remote_host" "$remote_context_dir" || return 1
            echo ""
        fi
    fi

    if [ "$dry_run" = true ]; then
        echo "Previewing sync to $remote_host (dry run)..."
    else
        echo "Syncing to $remote_host..."
    fi
    rsync -av "${rsync_options[@]}" "$sync_source" "$sync_destination"
    echo "Done."
}

cc-sync-from() {
    _cc_sync_set_vars || return 1
    _cc_sync_parse_sync_operation_args "$@" || {
        echo "Usage: cc-sync-from [rsync-options] <host[:path]>"
        return 1
    }
    _cc_sync_set_remote_spec_vars || return 1
    _cc_sync_run_from
}

cc-sync-to() {
    _cc_sync_set_vars || return 1
    _cc_sync_parse_sync_operation_args "$@" || {
        echo "Usage: cc-sync-to [rsync-options] <host[:path]>"
        return 1
    }
    _cc_sync_set_remote_spec_vars || return 1
    _cc_sync_run_to
}

cc-sync() {
    if [ $# -eq 0 ]; then
        echo "Usage: cc-sync [pull|push] [rsync-options] <host[:path]>"
        echo "       cc-sync [backup|restore|pop]"
        return 1
    fi

    _cc_sync_parse_dispatch_args "$@" || {
        echo "Usage: cc-sync [pull|push] [rsync-options] <host[:path]>"
        echo "       cc-sync [backup|restore|pop]"
        return 1
    }

    case $dispatch_command in
    backup | restore | pop)
        if [ "${#rsync_options[@]}" -gt 0 ]; then
            echo "Error: rsync options are only valid with pull and push"
            return 1
        fi
        if [ -n "$remote_spec" ]; then
            echo "Error: $dispatch_command does not accept a remote host argument"
            return 1
        fi
        case $dispatch_command in
        backup)
            cc-backup
            ;;
        restore)
            cc-restore
            ;;
        pop)
            cc-pop
            ;;
        esac
        ;;
    "" | pull | push)
        _cc_sync_set_vars || return 1
        sync_mode="$dispatch_command"
        if [ -z "$sync_mode" ]; then
            sync_mode="pull"
        fi
        if [ -z "$remote_spec" ]; then
            echo "Error: remote host argument is required"
            echo "Usage: cc-sync [pull|push] [rsync-options] <host[:path]>"
            return 1
        fi
        _cc_sync_set_remote_spec_vars || return 1
        case $sync_mode in
        pull)
            _cc_sync_run_from
            ;;
        push)
            _cc_sync_run_to
            ;;
        esac
        ;;
    *)
        echo "Error: invalid subcommand: $dispatch_command"
        return 1
        ;;
    esac
}
