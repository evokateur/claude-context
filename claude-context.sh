_cc_sync_context_dir_for_path() {
    echo "$1" | sed 's/\//-/g'
}

_cc_sync_set_vars() {
    if [ ! -d "$HOME/.claude/projects" ]; then
        echo "Missing $HOME/.claude/projects directory."
        return 1
    fi

    backup_dir="$HOME/.claude/backups/projects"
    current_dir=$(pwd)

    case "$current_dir" in
    "$HOME" | "$HOME"/*) ;;
    *)
        echo "The local CWD must be within \$HOME."
        return 1
        ;;
    esac

    local_context_dir=$(_cc_sync_context_dir_for_path "$current_dir")
    local_context_path="$HOME/.claude/projects/$local_context_dir"
}

_cc_sync_set_remote_context_vars() {
    local remote_home remote_full_path

    remote_host="$1"
    relative_path="$2"

    echo "Checking SSH connectivity to $remote_host..."
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$remote_host" exit 2>/dev/null; then
        echo "Cannot establish SSH connection to $remote_host."
        return 1
    fi

    echo "Detecting remote home directory..."
    remote_home=$(ssh "$remote_host" "echo \$HOME" 2>/dev/null)
    if [ -z "$remote_home" ]; then
        echo "Could not determine remote home directory."
        return 1
    fi

    remote_full_path="${remote_home}/${relative_path}"
    remote_context_dir=$(_cc_sync_context_dir_for_path "$remote_full_path")
    remote_context_path="${remote_home}/.claude/projects/$remote_context_dir"
}

_cc_sync_remote_context_exists() {
    local remote_host="$1"
    local remote_context_path="$2"

    ssh "$remote_host" "test -d '$remote_context_path'" 2>/dev/null
}

_cc_sync_create_remote_context_path() {
    local remote_host="$1"
    local remote_context_path="$2"

    echo "Creating Claude context directory on $remote_host..."
    ssh "$remote_host" "mkdir -p '$remote_context_path'"
}

_cc_sync_list_local() {
    local local_context_path="$1"

    if [ ! -d "$local_context_path" ]; then
        echo "$local_context_path does not exist on this machine"
        return 1
    fi

    echo "Local context directory: $local_context_path"
    ls -l -t "$local_context_path"
}

_cc_sync_list_remote() {
    local remote_host="$1"
    local relative_path="$2"

    _cc_sync_set_remote_context_vars "$remote_host" "$relative_path" || return 1

    echo "Checking if Claude context directory exists on $remote_host..."
    if ! _cc_sync_remote_context_exists "$remote_host" "$remote_context_path"; then
        echo "$remote_context_path does not exist on $remote_host"
        return 1
    fi

    echo "Remote context directory: $remote_context_path"
    ssh "$remote_host" "ls -l -t '$remote_context_path'"
}

_cc_sync_backup() {
    local local_context_path="$1"
    local local_context_dir="$2"
    local backup_dir="$3"
    local timestamp backup_file

    if [ ! -d "$local_context_path" ]; then
        echo "$local_context_path does not exist on this machine"
        return 1
    fi

    mkdir -p "$backup_dir"

    timestamp=$(date +%Y%m%d-%H%M%S)
    backup_file="${backup_dir}/${local_context_dir}_${timestamp}.tar.gz"

    echo "Creating backup of local context directory..."
    (cd "$HOME/.claude/projects" && tar czf "$backup_file" "./$local_context_dir/")

    echo "Backup created: $backup_file"
}

_cc_sync_pop() {
    local local_context_path="$1"
    local local_context_dir="$2"
    local backup_dir="$3"
    local delete_backup="${4:-true}"
    local latest_backup

    latest_backup=$(ls -1 "$backup_dir/${local_context_dir}_"*.tar.gz 2>/dev/null | sort -r | head -1)

    if [ -z "$latest_backup" ]; then
        echo "No backups found for $local_context_dir"
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

_cc_sync_remote_backup() {
    local remote_host="$1"
    local remote_context_dir="$2"
    local timestamp remote_backup_dir remote_backup_file

    timestamp=$(date +%Y%m%d-%H%M%S)
    remote_backup_dir="\$HOME/.claude/backups/projects"
    remote_backup_file="\$HOME/.claude/backups/projects/${remote_context_dir}_${timestamp}.tar.gz"

    echo "Creating backup of remote context directory on $remote_host..."
    ssh "$remote_host" "mkdir -p \"$remote_backup_dir\" && tar czf \"$remote_backup_file\" -C \"\$HOME/.claude/projects\" './$remote_context_dir/'" || return 1

    echo "Remote backup created: ${remote_host}:${remote_backup_file#\$HOME/}"
}

_cc_sync_has_files_to_sync() {
    local count
    count=$(rsync -av --dry-run "$@" 2>/dev/null |
        grep -cvE '^(building file list|sending incremental file list|receiving incremental file list|Transfer starting|sent |total size|\./|$)')
    [ "$count" -gt 0 ]
}

_cc_sync_validate_modified_within_days() {
    case "$1" in
    '' | *[!0-9]*)
        echo "--modified-within requires a positive integer."
        return 1
        ;;
    0)
        echo "--modified-within requires a positive integer."
        return 1
        ;;
    esac
}

_cc_sync_normalize_list_file() {
    local input_path="$1"
    local output_path="$2"
    local base_path="${3:-}"
    local relative_path

    : >"$output_path"

    while IFS= read -r relative_path; do
        relative_path="${relative_path#./}"

        if [ -z "$relative_path" ]; then
            continue
        fi

        if [ -n "$base_path" ] && [ ! -f "$base_path/$relative_path" ]; then
            continue
        fi

        printf '%s\n' "$relative_path" >>"$output_path"
    done <"$input_path"
}

_cc_sync_write_local_list_file() {
    local context_path="$1"
    local output_path="$2"
    local find_args="$3"
    local raw_output_path

    raw_output_path=$(mktemp "${TMPDIR:-/tmp}/cc-sync-local-find.XXXXXX") || return 1

    (
        cd "$context_path" || exit 1
        eval "find . ${find_args}"
    ) >"$raw_output_path" || {
        rm -f "$raw_output_path"
        return 1
    }

    _cc_sync_normalize_list_file "$raw_output_path" "$output_path" "$context_path"
    rm -f "$raw_output_path"
}

_cc_sync_write_remote_list_file() {
    local remote_host="$1"
    local remote_context_path="$2"
    local output_path="$3"
    local find_args="$4"
    local raw_output_path
    local quoted_context_path quoted_find_args

    raw_output_path=$(mktemp "${TMPDIR:-/tmp}/cc-sync-remote-find.XXXXXX") || return 1

    quoted_context_path=$(printf '%q' "$remote_context_path")
    quoted_find_args=$(printf '%q' "$find_args")

    ssh "$remote_host" "sh -s -- $quoted_context_path $quoted_find_args" <<'EOF' >"$raw_output_path" || {
context_path="$1"
find_args="$2"
raw_output_path=$(mktemp "${TMPDIR:-/tmp}/cc-sync-remote-find.XXXXXX") || exit 1

cd "$context_path" || exit 1

eval "find . ${find_args}" > "$raw_output_path"

while IFS= read -r relative_path; do
    relative_path="${relative_path#./}"

    if [ -z "$relative_path" ]; then
        continue
    fi

    if [ ! -f "$relative_path" ]; then
        continue
    fi

    printf '%s\n' "$relative_path"
done < "$raw_output_path"

rm -f "$raw_output_path"
EOF
        rm -f "$raw_output_path"
        return 1
    }

    _cc_sync_normalize_list_file "$raw_output_path" "$output_path"
    rm -f "$raw_output_path"
}

_cc_sync_prepare_list_file() {
    local direction="$1"
    local local_context_path="$2"
    local remote_host="$3"
    local remote_context_path="$4"
    local find_args="$5"
    local file_count

    list_file_path=$(mktemp "${TMPDIR:-/tmp}/cc-sync-list-file.XXXXXX") || return 1

    case "$direction" in
    to)
        _cc_sync_write_local_list_file "$local_context_path" "$list_file_path" "$find_args" || {
            rm -f "$list_file_path"
            list_file_path=""
            return 1
        }
        ;;
    from)
        _cc_sync_write_remote_list_file "$remote_host" "$remote_context_path" "$list_file_path" "$find_args" || {
            rm -f "$list_file_path"
            list_file_path=""
            return 1
        }
        ;;
    *)
        echo "Unsupported sync direction: $direction"
        rm -f "$list_file_path"
        list_file_path=""
        return 1
        ;;
    esac

    file_count=$(wc -l <"$list_file_path")
    file_count="${file_count//[[:space:]]/}"

    echo "Selected ${file_count} files:"
    cat "$list_file_path"

    if [ "$file_count" -eq 0 ]; then
        echo "Nothing matched. Nothing to sync."
        rm -f "$list_file_path"
        list_file_path=""
        return 2
    fi
}

_cc_sync_cleanup_list_file() {
    if [ -n "$list_file_path" ]; then
        rm -f "$list_file_path"
        list_file_path=""
    fi
}

_cc_sync_parse_dispatch_args() {
    dispatch_command=""
    rsync_options=()
    dry_run=false
    remote_spec=""
    find_args=""

    while [[ $# -gt 0 ]]; do
        case $1 in
        from | to)
            if [ -n "$dispatch_command" ] && [ "$dispatch_command" != "$1" ]; then
                echo "Multiple subcommands specified."
                return 1
            fi
            dispatch_command="$1"
            shift
            ;;
        list | ls)
            if [ -n "$dispatch_command" ] && [ "$dispatch_command" != "$1" ]; then
                echo "Multiple subcommands specified."
                return 1
            fi
            dispatch_command="$1"
            shift
            ;;
        backup | restore | pop)
            if [ -n "$dispatch_command" ] && [ "$dispatch_command" != "$1" ]; then
                echo "Multiple subcommands specified."
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
        --modified-within)
            if [ -n "$find_args" ]; then
                echo "Only one file selection option may be specified."
                return 1
            fi
            if [ $# -lt 2 ]; then
                echo "--modified-within requires a value."
                return 1
            fi
            _cc_sync_validate_modified_within_days "$2" || return 1
            find_args="-type f -mtime -$2"
            shift 2
            ;;
        --find-args)
            if [ -n "$find_args" ]; then
                echo "Only one file selection option may be specified."
                return 1
            fi
            if [ $# -lt 2 ]; then
                echo "--find-args requires a value."
                return 1
            fi
            find_args="$2"
            shift 2
            ;;
        *)
            if [ -n "$remote_spec" ]; then
                echo "Expected exactly one remote host argument."
                return 1
            fi
            remote_spec="$1"
            shift
            ;;
        esac
    done
}

_cc_sync_set_remote_spec_vars() {
    local current_dir="$1"

    if [ -z "$remote_spec" ]; then
        echo "Remote host argument is required."
        return 1
    fi

    if [[ "$remote_spec" == *:* ]]; then
        remote_host="${remote_spec%%:*}"
        relative_path="${remote_spec#*:}"

        case "$relative_path" in
        /*)
            echo "Remote path must be relative to \$HOME."
            return 1
            ;;
        esac
    else
        remote_host="$remote_spec"
        relative_path="${current_dir#$HOME/}"
    fi
}

_cc_sync_run_from() {
    local remote_host="$1"
    local relative_path="$2"
    local local_context_path="$3"
    local local_context_dir="$4"
    local backup_dir="$5"
    local dry_run="$6"
    shift 6
    local rsync_options=("$@")
    local remote_context_dir remote_context_path sync_source sync_destination
    local result

    _cc_sync_set_remote_context_vars "$remote_host" "$relative_path" || return 1

    echo "Checking if Claude context directory exists on $remote_host..."
    if ! _cc_sync_remote_context_exists "$remote_host" "$remote_context_path"; then
        echo "$remote_context_path does not exist on $remote_host"
        return 1
    fi

    sync_source="${remote_host}:${remote_context_path}/"
    sync_destination="${local_context_path}/"

    echo "Remote context directory: $remote_context_path"
    echo "Local context directory: $local_context_path"
    echo ""

    if [ -n "$find_args" ]; then
        _cc_sync_prepare_list_file from "$local_context_path" "$remote_host" "$remote_context_path" "$find_args"
        result=$?

        case "$result" in
        0)
            rsync_options+=("--files-from=$list_file_path")
            ;;
        2)
            return 0
            ;;
        *)
            return 1
            ;;
        esac
    fi

    if [ "$dry_run" = false ] && _cc_sync_has_files_to_sync "${rsync_options[@]}" "$sync_source" "$sync_destination"; then
        if [ -d "$local_context_path" ]; then
            _cc_sync_backup "$local_context_path" "$local_context_dir" "$backup_dir" || {
                _cc_sync_cleanup_list_file
                return 1
            }
            echo ""
        fi
    fi

    if [ "$dry_run" = true ]; then
        echo "Previewing sync from $remote_host (dry run)..."
    else
        echo "Syncing from $remote_host..."
    fi
    rsync -av "${rsync_options[@]}" "$sync_source" "$sync_destination"
    local rsync_status=$?
    _cc_sync_cleanup_list_file
    [ "$rsync_status" -eq 0 ] || return "$rsync_status"
    echo "Done."
}

_cc_sync_run_to() {
    local remote_host="$1"
    local relative_path="$2"
    local local_context_path="$3"
    local local_context_dir="$4"
    local backup_dir="$5"
    local dry_run="$6"
    shift 6
    local rsync_options=("$@")
    local remote_context_dir remote_context_path sync_source sync_destination
    local remote_context_exists=false
    local result

    if [ ! -d "$local_context_path" ]; then
        echo "$local_context_path does not exist on this machine"
        return 1
    fi

    _cc_sync_set_remote_context_vars "$remote_host" "$relative_path" || return 1

    echo "Checking if Claude context directory exists on $remote_host..."
    if _cc_sync_remote_context_exists "$remote_host" "$remote_context_path"; then
        remote_context_exists=true
    else
        _cc_sync_create_remote_context_path "$remote_host" "$remote_context_path" || return 1
    fi

    sync_source="${local_context_path}/"
    sync_destination="${remote_host}:${remote_context_path}/"

    echo "Remote host: $remote_host"
    echo "Remote context directory: $remote_context_path"
    echo "Local context directory: $local_context_path"
    echo ""

    if [ -n "$find_args" ]; then
        _cc_sync_prepare_list_file to "$local_context_path" "$remote_host" "$remote_context_path" "$find_args"
        result=$?

        case "$result" in
        0)
            rsync_options+=("--files-from=$list_file_path")
            ;;
        2)
            return 0
            ;;
        *)
            return 1
            ;;
        esac
    fi

    if [ "$dry_run" = false ] && _cc_sync_has_files_to_sync "${rsync_options[@]}" "$sync_source" "$sync_destination"; then
        if [ "$remote_context_exists" = true ]; then
            _cc_sync_remote_backup "$remote_host" "$remote_context_dir" || {
                _cc_sync_cleanup_list_file
                return 1
            }
            echo ""
        fi
    fi

    if [ "$dry_run" = true ]; then
        echo "Previewing sync to $remote_host (dry run)..."
    else
        echo "Syncing to $remote_host..."
    fi
    rsync -av "${rsync_options[@]}" "$sync_source" "$sync_destination"
    local rsync_status=$?
    _cc_sync_cleanup_list_file
    [ "$rsync_status" -eq 0 ] || return "$rsync_status"
    echo "Done."
}

cc-sync() {
    local dispatch_command rsync_options dry_run remote_spec
    local find_args list_file_path
    local backup_dir current_dir local_context_dir local_context_path
    local sync_mode remote_host relative_path

    if [ $# -eq 0 ]; then
        echo "Usage: cc-sync [from|to] [rsync-options] <host[:path]>"
        echo "       cc-sync [backup|restore|pop]"
        echo "       cc-sync [list|ls] [host[:path]]"
        return 1
    fi

    _cc_sync_parse_dispatch_args "$@" || {
        echo "Usage: cc-sync [from|to] [rsync-options] <host[:path]>"
        echo "       cc-sync [backup|restore|pop]"
        echo "       cc-sync [list|ls] [host[:path]]"
        return 1
    }

    case $dispatch_command in
    backup | restore | pop)
        if [ -n "$find_args" ]; then
            echo "File selection is only supported for sync operations."
            return 1
        fi
        if [ "${#rsync_options[@]}" -gt 0 ]; then
            echo "Unexpected rsync option."
            return 1
        fi
        if [ -n "$remote_spec" ]; then
            echo "Unexpected remote host argument."
            return 1
        fi
        _cc_sync_set_vars || return 1
        case $dispatch_command in
        backup)
            _cc_sync_backup "$local_context_path" "$local_context_dir" "$backup_dir"
            ;;
        restore)
            _cc_sync_pop "$local_context_path" "$local_context_dir" "$backup_dir" false
            ;;
        pop)
            _cc_sync_pop "$local_context_path" "$local_context_dir" "$backup_dir" true
            ;;
        esac
        ;;
    list | ls)
        if [ -n "$find_args" ]; then
            echo "File selection is only supported for sync operations."
            return 1
        fi
        if [ "${#rsync_options[@]}" -gt 0 ]; then
            echo "Unexpected rsync option."
            return 1
        fi
        _cc_sync_set_vars || return 1
        if [ -z "$remote_spec" ]; then
            _cc_sync_list_local "$local_context_path"
        else
            _cc_sync_set_remote_spec_vars "$current_dir" || return 1
            _cc_sync_list_remote "$remote_host" "$relative_path"
        fi
        ;;
    "" | from | to)
        _cc_sync_set_vars || return 1
        sync_mode="$dispatch_command"
        if [ -z "$sync_mode" ]; then
            sync_mode="from"
        fi
        if [ -z "$remote_spec" ]; then
            echo "Remote host argument is required"
            echo "Usage: cc-sync [from|to] [rsync-options] <host[:path]>"
            echo "       cc-sync [list|ls] [host[:path]]"
            return 1
        fi
        _cc_sync_set_remote_spec_vars "$current_dir" || return 1
        case $sync_mode in
        from)
            _cc_sync_run_from "$remote_host" "$relative_path" "$local_context_path" "$local_context_dir" "$backup_dir" "$dry_run" "${rsync_options[@]}"
            ;;
        to)
            _cc_sync_run_to "$remote_host" "$relative_path" "$local_context_path" "$local_context_dir" "$backup_dir" "$dry_run" "${rsync_options[@]}"
            ;;
        esac
        ;;
    *)
        echo "Invalid subcommand: $dispatch_command"
        return 1
        ;;
    esac
}
