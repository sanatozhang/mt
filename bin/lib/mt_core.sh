reset_global_options() {
    GLOBAL_SCOPE="all"
    GLOBAL_ONLY_REPOS=()
    GLOBAL_EXCLUDE_REPOS=()
    GLOBAL_OUTPUT_FORMAT="text"
    GLOBAL_DRY_RUN=false
    GLOBAL_FAIL_FAST=false
    GLOBAL_CONFIRM_MODE="auto"
    PARSED_ARGS=()
}

parse_global_options() {
    reset_global_options

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --current)
                GLOBAL_SCOPE="current"
                shift
                ;;
            --all)
                GLOBAL_SCOPE="all"
                shift
                ;;
            --main-only)
                GLOBAL_SCOPE="main"
                shift
                ;;
            --subrepos-only)
                GLOBAL_SCOPE="subrepos"
                shift
                ;;
            --only)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${BOLD_RED}错误: --only 需要指定仓库名或路径${NC}" >&2
                    return 1
                fi
                GLOBAL_ONLY_REPOS+=("$2")
                shift 2
                ;;
            --exclude)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${BOLD_RED}错误: --exclude 需要指定仓库名或路径${NC}" >&2
                    return 1
                fi
                GLOBAL_EXCLUDE_REPOS+=("$2")
                shift 2
                ;;
            --json)
                GLOBAL_OUTPUT_FORMAT="json"
                shift
                ;;
            --dry-run)
                GLOBAL_DRY_RUN=true
                shift
                ;;
            --fail-fast)
                GLOBAL_FAIL_FAST=true
                shift
                ;;
            --continue-on-error)
                GLOBAL_FAIL_FAST=false
                shift
                ;;
            --confirm)
                GLOBAL_CONFIRM_MODE="force"
                shift
                ;;
            --no-confirm)
                GLOBAL_CONFIRM_MODE="never"
                shift
                ;;
            --)
                shift
                break
                ;;
            --help|-h|--version|-v)
                break
                ;;
            -*)
                echo -e "${BOLD_RED}错误: 未知的全局参数: $1${NC}" >&2
                return 1
                ;;
            *)
                break
                ;;
        esac
    done

    PARSED_ARGS=("$@")
    return 0
}

is_json_output() {
    [[ "$GLOBAL_OUTPUT_FORMAT" == "json" ]]
}

json_reset() {
    JSON_RESULT_ITEMS=()
}

json_escape() {
    local value="${1:-}"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "$value"
}

json_add_result() {
    local name="${1:-}"
    local status="${2:-unknown}"
    local path="${3:-}"
    local message="${4:-}"
    local details="${5:-}"

    local json="{\"name\":\"$(json_escape "$name")\",\"status\":\"$(json_escape "$status")\",\"path\":\"$(json_escape "$path")\",\"message\":\"$(json_escape "$message")\""
    if [[ -n "$details" ]]; then
        json="${json},${details}"
    fi
    json="${json}}"
    JSON_RESULT_ITEMS+=("$json")
}

json_print_results() {
    local command_name="${1:-}"
    local success="${2:-true}"
    local summary="${3:-}"
    local items="[]"

    if [[ -n "${JSON_RESULT_ITEMS[*]-}" ]]; then
        items="[$(IFS=,; echo "${JSON_RESULT_ITEMS[*]}")]"
    fi

    printf '{"command":"%s","success":%s,"summary":"%s","results":%s}\n' \
        "$(json_escape "$command_name")" \
        "$success" \
        "$(json_escape "$summary")" \
        "$items"
}

is_subrepository_path() {
    local path="${1:-}"
    [[ "$path" == */* ]]
}

repo_matches_selector() {
    local repo_info="$1"
    local selector="$2"
    IFS='|' read -r name path url <<< "$repo_info"
    [[ "$name" == "$selector" || "$path" == "$selector" ]]
}

get_current_repo_info() {
    local repos=("$@")
    local current_dir
    current_dir="$(pwd)"

    local repo_info=""
    local best_match=""
    local best_length=0
    if [[ -n "${repos[*]-}" ]]; then
        for repo_info in "${repos[@]}"; do
            IFS='|' read -r name path url <<< "$repo_info"
            local repo_path="${PROJECT_ROOT}/${path}"
            if [[ "$current_dir" == "$repo_path" || "$current_dir" == "${repo_path}"/* ]]; then
                local match_length=${#repo_path}
                if [[ $match_length -gt $best_length ]]; then
                    best_match="$repo_info"
                    best_length=$match_length
                fi
            fi
        done
    fi

    if [[ -n "$best_match" ]]; then
        echo "$best_match"
        return 0
    fi

    return 1
}

filter_repositories() {
    local repos=("$@")
    local selected=()
    local current_repo=""

    if [[ "$GLOBAL_SCOPE" == "current" ]]; then
        current_repo=$(get_current_repo_info "${repos[@]}" 2>/dev/null || echo "")
        if [[ -z "$current_repo" ]]; then
            echo -e "${BOLD_RED}错误: 当前目录不在任何已知仓库内，无法使用 --current${NC}" >&2
            return 1
        fi
    fi

    local repo_info=""
    if [[ -n "${repos[*]-}" ]]; then
        for repo_info in "${repos[@]}"; do
            IFS='|' read -r name path url <<< "$repo_info"
            local include=true

            case "$GLOBAL_SCOPE" in
                current)
                    if [[ "$repo_info" != "$current_repo" ]]; then
                        include=false
                    fi
                    ;;
                main)
                    if is_subrepository_path "$path"; then
                        include=false
                    fi
                    ;;
                subrepos)
                    if ! is_subrepository_path "$path"; then
                        include=false
                    fi
                    ;;
            esac

            if [[ "$include" == true ]] && [[ ${#GLOBAL_ONLY_REPOS[@]} -gt 0 ]]; then
                include=false
                local selector=""
                for selector in "${GLOBAL_ONLY_REPOS[@]}"; do
                    if repo_matches_selector "$repo_info" "$selector"; then
                        include=true
                        break
                    fi
                done
            fi

            if [[ "$include" == true ]] && [[ ${#GLOBAL_EXCLUDE_REPOS[@]} -gt 0 ]]; then
                local selector=""
                for selector in "${GLOBAL_EXCLUDE_REPOS[@]}"; do
                    if repo_matches_selector "$repo_info" "$selector"; then
                        include=false
                        break
                    fi
                done
            fi

            if [[ "$include" == true ]]; then
                selected+=("$repo_info")
            fi
        done
    fi

    if [[ -n "${selected[*]-}" ]]; then
        printf '%s\n' "${selected[@]}"
    fi
}

get_selected_repositories() {
    local repos=()
    while IFS= read -r line; do
        repos+=("$line")
    done < <(get_repositories)

    if [[ -z "${repos[*]-}" ]]; then
        return 0
    fi

    filter_repositories "${repos[@]}"
}

should_confirm_action() {
    local risky="${1:-false}"
    case "$GLOBAL_CONFIRM_MODE" in
        never)
            return 1
            ;;
        force)
            return 0
            ;;
        *)
            [[ "$risky" == "true" ]]
            ;;
    esac
}

confirm_action() {
    local risky="${1:-false}"
    local message="${2:-是否继续?}"

    if ! should_confirm_action "$risky"; then
        return 0
    fi

    if is_json_output; then
        return 0
    fi

    read -p "${message} (y/N): " -n 1 -r
    echo
    [[ "$REPLY" =~ ^[Yy]$ ]]
}

is_high_risk_git_command() {
    local git_args=("$@")
    local cmd="${git_args[0]:-}"

    case "$cmd" in
        reset)
            return 0
            ;;
        clean)
            local arg=""
            for arg in "${git_args[@]:1}"; do
                if [[ "$arg" == *"f"* ]] || [[ "$arg" == "--force" ]]; then
                    return 0
                fi
            done
            ;;
        push)
            local arg=""
            for arg in "${git_args[@]:1}"; do
                if [[ "$arg" == "-f" ]] || [[ "$arg" == "--force" ]] || [[ "$arg" == "--force-with-lease" ]]; then
                    return 0
                fi
            done
            ;;
    esac

    return 1
}

resolve_registered_command_handler() {
    local command_name="${1:-}"
    local definition=""
    for definition in "${REGISTERED_COMMANDS[@]}"; do
        IFS='|' read -r name handler category description <<< "$definition"
        if [[ "$name" == "$command_name" ]]; then
            echo "$handler"
            return 0
        fi
    done
    return 1
}

resolve_git_command() {
    local command_name="${1:-}"
    local definition=""

    for definition in "${GIT_ALIAS_DEFINITIONS[@]}"; do
        IFS='|' read -r alias actual_cmd extra_args <<< "$definition"
        if [[ "$alias" == "$command_name" ]]; then
            echo "${actual_cmd}|${extra_args}"
            return 0
        fi
    done

    local cmd=""
    for cmd in "${SUPPORTED_GIT_COMMANDS[@]}"; do
        if [[ "$cmd" == "$command_name" ]]; then
            echo "${command_name}|"
            return 0
        fi
    done

    return 1
}

get_git_alias_names() {
    local aliases=()
    local definition=""
    for definition in "${GIT_ALIAS_DEFINITIONS[@]}"; do
        IFS='|' read -r alias actual_cmd extra_args <<< "$definition"
        aliases+=("$alias")
    done
    echo "${aliases[*]}"
}

check_version_update() {
    local skip_commands=("upgrade" "--version" "-v" "version" "help" "-h" "--help")
    local first_arg="${1:-}"
    for cmd in "${skip_commands[@]}"; do
        if [[ "$first_arg" == "$cmd" ]]; then
            return 0
        fi
    done

    if [[ -n "${CI:-}" ]] || [[ ! -t 1 ]]; then
        return 0
    fi

    local mt_repo_dir
    mt_repo_dir="$(get_mt_dir 2>/dev/null)" || return 0

    if [[ ! -d "${mt_repo_dir}/.git" ]] && [[ ! -f "${mt_repo_dir}/.git" ]]; then
        return 0
    fi

    local cache_dir="${HOME}/.cache/mt"
    local cache_file="${cache_dir}/version_check"

    if ! mkdir -p "$cache_dir" 2>/dev/null; then
        return 0
    fi

    local now
    now=$(date +%s)
    local last_check=0
    if [[ -f "$cache_file" ]]; then
        last_check=$(cat "$cache_file" 2>/dev/null || echo "0")
    fi

    local cache_duration=86400
    local time_diff=$((now - last_check))
    if [[ $time_diff -lt $cache_duration ]]; then
        return 0
    fi

    echo "$now" > "$cache_file" 2>/dev/null || true

    (
        local remote_commit
        local local_commit

        remote_commit=$(git ls-remote "git@github.com:${GITHUB_REPO}.git" "refs/heads/${GITHUB_BRANCH}" 2>/dev/null | cut -f1)

        if [[ -z "$remote_commit" ]]; then
            remote_commit=$(git ls-remote "https://github.com/${GITHUB_REPO}.git" "refs/heads/${GITHUB_BRANCH}" 2>/dev/null | cut -f1)
        fi

        if [[ -z "$remote_commit" ]]; then
            return 0
        fi

        local_commit=$(cd "$mt_repo_dir" && git rev-parse HEAD 2>/dev/null || echo "")
        if [[ -z "$local_commit" ]]; then
            return 0
        fi

        if [[ "$local_commit" != "$remote_commit" ]]; then
            local lock_file="${cache_dir}/version_prompt_lock"
            if [[ ! -f "$lock_file" ]] || [[ $(($(date +%s) - $(cat "$lock_file" 2>/dev/null || echo "0"))) -gt 3600 ]]; then
                echo "$(date +%s)" > "$lock_file" 2>/dev/null || true

                echo "" >&2
                echo -e "${BOLD_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
                echo -e "${BOLD_YELLOW}  ⚠  发现新版本！${NC}" >&2
                echo -e "${BOLD_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
                echo -e "${CYAN}  当前版本: ${local_commit:0:8}${NC}" >&2
                echo -e "${CYAN}  最新版本: ${remote_commit:0:8}${NC}" >&2
                echo "" >&2
                echo -e "${YELLOW}  运行以下命令更新到最新版本:${NC}" >&2
                echo -e "${BOLD_CYAN}    mt upgrade${NC}" >&2
                echo -e "${BOLD_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
                echo "" >&2
            fi
        fi
    ) &

    return 0
}

get_mt_dir() {
    local script_path="${BASH_SOURCE[0]:-$0}"

    if [[ -L "$script_path" ]] || [[ -L "$(dirname "$script_path")/$(basename "$script_path")" ]]; then
        if command -v readlink >/dev/null 2>&1; then
            if readlink -f "$script_path" >/dev/null 2>&1; then
                script_path=$(readlink -f "$script_path")
            elif readlink "$script_path" >/dev/null 2>&1; then
                local link_target
                link_target=$(readlink "$script_path")
                if [[ "$link_target" = /* ]]; then
                    script_path="$link_target"
                else
                    script_path="$(dirname "$script_path")/$link_target"
                fi
            fi
        fi
    fi

    local bin_dir
    bin_dir="$(cd "$(dirname "$script_path")" && pwd)"
    local mt_dir
    mt_dir="$(cd "${bin_dir}/.." && pwd)"

    if [[ ! -d "${mt_dir}/.git" ]] && [[ ! -f "${mt_dir}/.git" ]]; then
        local current_dir="$bin_dir"
        while [[ "$current_dir" != "/" ]]; do
            if [[ -d "${current_dir}/.git" ]] || [[ -f "${current_dir}/.git" ]]; then
                echo "$current_dir"
                return 0
            fi
            current_dir="$(dirname "$current_dir")"
        done

        echo "$mt_dir"
        return 0
    fi

    echo "$mt_dir"
}

BIN_DIR="${SCRIPT_BIN_DIR:-$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]:-$0}")")" && pwd)}"
MT_DIR="$(get_mt_dir)"

workspace_contains_main_repositories() {
    local candidate_dir="$1"
    local repo_info=""

    for repo_info in "${DEFAULT_REPOSITORIES[@]}"; do
        IFS='|' read -r name path url <<< "$repo_info"
        if [[ "$path" == */* ]]; then
            continue
        fi
        if [[ -d "${candidate_dir}/${path}" ]]; then
            return 0
        fi
    done

    return 1
}

directory_is_inside_known_repository() {
    local original_dir="$1"
    local candidate_dir="$2"
    local repo_info=""

    for repo_info in "${DEFAULT_REPOSITORIES[@]}"; do
        IFS='|' read -r name path url <<< "$repo_info"
        if [[ "$original_dir" == "${candidate_dir}/${path}" ]] || [[ "$original_dir" == "${candidate_dir}/${path}/"* ]]; then
            return 0
        fi
    done

    return 1
}

find_project_root() {
    local original_dir="$1"
    local current_dir="$1"
    local mt_dir="${MT_DIR}"

    while [[ "$current_dir" != "/" ]]; do
        if [[ "$current_dir" == "$mt_dir" ]]; then
            current_dir="$(dirname "$current_dir")"
            continue
        fi

        if [[ -f "${current_dir}/github.token" ]]; then
            echo "$current_dir"
            return 0
        fi

        if workspace_contains_main_repositories "$current_dir"; then
            echo "$current_dir"
            return 0
        fi

        if directory_is_inside_known_repository "$original_dir" "$current_dir"; then
            echo "$current_dir"
            return 0
        fi

        current_dir="$(dirname "$current_dir")"
    done

    echo "$original_dir"
}

PROJECT_ROOT="$(find_project_root "$(pwd)")"

get_repositories() {
    printf '%s\n' "${DEFAULT_REPOSITORIES[@]}"
}

is_git_repository_path() {
    local repo_path="$1"
    [[ -d "$repo_path" ]] && { [[ -d "${repo_path}/.git" ]] || [[ -f "${repo_path}/.git" ]]; }
}

print_command() {
    local work_dir="$1"
    shift
    local cmd_args=("$@")
    local cmd_str=""

    for arg in "${cmd_args[@]}"; do
        if [[ "$arg" =~ [[:space:]] ]] || [[ "$arg" =~ [\(\)\|\&\;\<\>] ]]; then
            cmd_str="${cmd_str} \"${arg}\""
        else
            cmd_str="${cmd_str} ${arg}"
        fi
    done
    cmd_str="${cmd_str# }"

    echo -e "${BOLD_CYAN}  → cd ${work_dir}${NC}"
    echo -e "${BOLD_CYAN}  → ${cmd_str}${NC}"
}

capture_command_exit() {
    local __result_var="$1"
    shift

    local exit_code=0
    local had_errexit=false
    case $- in
        *e*) had_errexit=true ;;
    esac

    set +e
    "$@"
    exit_code=$?
    if [[ "$had_errexit" == "true" ]]; then
        set -e
    fi

    printf -v "$__result_var" '%s' "$exit_code"
    return 0
}

capture_command_output() {
    local __output_var="$1"
    local __result_var="$2"
    shift 2

    local output=""
    local exit_code=0
    local had_errexit=false
    case $- in
        *e*) had_errexit=true ;;
    esac

    set +e
    output="$("$@")"
    exit_code=$?
    if [[ "$had_errexit" == "true" ]]; then
        set -e
    fi

    printf -v "$__output_var" '%s' "$output"
    printf -v "$__result_var" '%s' "$exit_code"
    return 0
}

print_composite_failure() {
    local command_name="$1"
    local reason="$2"

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BOLD_RED}${CROSS_MARK} ${command_name}失败: ${reason}${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_composite_success() {
    local command_name="$1"

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BOLD_GREEN}${CHECK_MARK} ${command_name}完成${NC}"
    echo -e "${BLUE}========================================${NC}"
}
