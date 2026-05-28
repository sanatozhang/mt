handle_list_command() {
    list_repositories "$@"
}

handle_doctor_command() {
    doctor "$@"
}

handle_init_command() {
    bootstrap_environment_and_clone "${1:-$PLAUD_APP_DEFAULT_DIR}"
}

handle_config_command() {
    echo -e "${YELLOW}mt 已不再使用 .mt-config.yaml，当前版本默认固定支持 7 个仓库${NC}"
    echo -e "${CYAN}可用入口:${NC}"
    echo -e "${CYAN}  mt list${NC}               查看内置仓库列表"
    echo -e "${CYAN}  mt doctor${NC}             检查工作区和仓库状态"
    echo -e "${CYAN}  mt set-github-token <token>${NC}  设置 GitHub token"
    return 0
}

handle_clone_command() {
    clone_plaud_app "${1:-$PLAUD_APP_DEFAULT_DIR}"
}

handle_set_github_token_command() {
    if [[ -z "${1:-}" ]]; then
        echo -e "${BOLD_RED}错误: 请提供 GitHub token${NC}"
        echo -e "${YELLOW}用法: mt set-github-token <your_token>${NC}"
        echo -e "${CYAN}获取 token: https://github.com/settings/tokens${NC}"
        return 1
    fi
    set_github_token "$1"
}

handle_upgrade_command() {
    upgrade_mt
}

handle_delete_command() {
    delete_branches "$@"
}

handle_sync_command() {
    sync_repositories "$@"
}

handle_clean_command() {
    local kind; kind=$(require_project_kind) || exit $?
    if [[ "$kind" == "native-app2" ]]; then
        _app2_clean_cache "$@"
    else
        clean_cache "$@"
    fi
}

handle_prebuild_command() {
    local kind; kind=$(require_project_kind) || exit $?
    if [[ "$kind" == "native-app2" ]]; then
        _app2_prebuild "$@"
    else
        prebuild
    fi
}

handle_build_command() {
    local kind; kind=$(require_project_kind) || exit $?
    if [[ "$kind" == "native-app2" ]]; then
        if [[ -z "${1:-}" ]] || [[ "${1}" =~ ^- ]]; then
            _app2_build_android "global" "$@"
        else
            _app2_build_android "$@"
        fi
        return $?
    fi
    if [[ -z "${1:-}" ]] || [[ "${1}" =~ ^- ]]; then
        build_android "global" "$@"
    else
        build_android "$@"
    fi
}

handle_build_check_command() {
    local kind; kind=$(require_project_kind) || exit $?
    if [[ "$kind" == "native-app2" ]]; then
        _app2_build_check "$@"
    else
        build_check "$@"
    fi
}

handle_build_ios_command() {
    local kind; kind=$(require_project_kind) || exit $?
    if [[ "$kind" == "native-app2" ]]; then
        _app2_build_ios "$@"
    else
        build_ios "$@"
    fi
}

handle_install_command() {
    local kind; kind=$(require_project_kind) || exit $?
    if [[ "$kind" == "native-app2" ]]; then
        if [[ "${1:-}" == "ios" ]]; then
            shift
            _app2_install_ios "$@"
        elif [[ -z "${1:-}" ]] || [[ "${1}" =~ ^- ]]; then
            _app2_install_android "global" "$@"
        else
            _app2_install_android "$@"
        fi
        return $?
    fi
    if [[ "${1:-}" == "ios" ]]; then
        shift
        install_ios "$@"
    elif [[ -z "${1:-}" ]] || [[ "${1}" =~ ^- ]]; then
        install_android "global" "$@"
    else
        install_android "$@"
    fi
}

handle_install_ios_command() {
    local kind; kind=$(require_project_kind) || exit $?
    if [[ "$kind" == "native-app2" ]]; then
        _app2_install_ios "$@"
    else
        install_ios "$@"
    fi
}

handle_go_command() {
    local kind; kind=$(require_project_kind) || exit $?
    if [[ "$kind" == "native-app2" ]]; then
        if [[ -z "${1:-}" ]] || [[ "${1}" =~ ^- ]]; then
            _app2_go_android "global" "$@"
        else
            _app2_go_android "$@"
        fi
        return $?
    fi
    if [[ -z "${1:-}" ]] || [[ "${1}" =~ ^- ]]; then
        go_android "global" "$@"
    else
        go_android "$@"
    fi
}

handle_rebuild_command() {
    local kind; kind=$(require_project_kind) || exit $?

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  执行 rebuild（清理缓存 + 重新构建）${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    echo -e "${CYAN}[1/2] 清理缓存...${NC}"
    echo ""
    local clean_exit_code=0
    if [[ "$kind" == "native-app2" ]]; then
        capture_command_exit clean_exit_code _app2_clean_cache
    else
        capture_command_exit clean_exit_code clean_cache
    fi
    if [[ $clean_exit_code -ne 0 ]]; then
        echo -e "${BOLD_RED}错误: 清理缓存失败${NC}"
        print_composite_failure "rebuild 命令" "clean 步骤失败"
        return "$clean_exit_code"
    fi
    echo ""

    echo -e "${CYAN}[2/2] 重新构建...${NC}"
    echo ""
    local go_exit_code=0
    if [[ "$kind" == "native-app2" ]]; then
        if [[ -z "${1:-}" ]] || [[ "${1}" =~ ^- ]]; then
            capture_command_exit go_exit_code _app2_go_android "global" "$@"
        else
            capture_command_exit go_exit_code _app2_go_android "$@"
        fi
    else
        if [[ -z "${1:-}" ]] || [[ "${1}" =~ ^- ]]; then
            capture_command_exit go_exit_code go_android "global" "$@"
        else
            capture_command_exit go_exit_code go_android "$@"
        fi
    fi

    if [[ $go_exit_code -ne 0 ]]; then
        print_composite_failure "rebuild 命令" "go 步骤失败"
        return "$go_exit_code"
    fi

    print_composite_success "rebuild 命令"
    return 0
}

handle_pr_command() {
    local target_branch="main"
    local title=""
    local description=""
    local ready_for_review=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--b|--base)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${BOLD_RED}错误: --base 需要指定目标分支${NC}"
                    return 1
                fi
                target_branch="$2"
                shift 2
                ;;
            -t|--t|--title)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${BOLD_RED}错误: --title 需要指定 PR 标题${NC}"
                    return 1
                fi
                title="$2"
                shift 2
                ;;
            -d|--d|--description)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${BOLD_RED}错误: --description 需要指定 PR 描述${NC}"
                    return 1
                fi
                description="$2"
                shift 2
                ;;
            -r|--ready)
                ready_for_review=true
                shift
                ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                echo -e "${YELLOW}用法: mt pr [-b <branch>] [-t <title>] [-d <description>] [-r]${NC}"
                return 1
                ;;
        esac
    done

    create_prs "$target_branch" "$title" "$description" "$ready_for_review"
}

handle_plaud_command() {
    case "${1:-}" in
        version)
            shift
            mt_plaud_version "$@"
            ;;
        log)
            shift
            case "${1:-}" in
                sync)
                    shift
                    mt_plaud_log_sync "$@"
                    ;;
                clean)
                    shift
                    mt_plaud_log_clean "$@"
                    ;;
                time-diff)
                    shift
                    mt_plaud_log_time_diff "$@"
                    ;;
                *)
                    echo -e "${BOLD_RED}错误: 未知的 plaud log 子命令: ${1:-}${NC}"
                    return 1
                    ;;
            esac
            ;;
        check)
            shift
            case "${1:-}" in
                opus)
                    shift
                    mt_plaud_check_opus "$@"
                    ;;
                *)
                    echo -e "${BOLD_RED}错误: 未知的 plaud check 子命令: ${1:-}${NC}"
                    return 1
                    ;;
            esac
            ;;
        copy)
            shift
            mt_plaud_copy "$@"
            ;;
        decrypt)
            shift
            mt_plaud_decrypt "$@"
            ;;
        *)
            echo -e "${BOLD_RED}错误: 未知的 plaud 子命令: ${1:-}${NC}"
            return 1
            ;;
    esac
}

handle_help_command() {
    show_help
}

handle_version_command() {
    echo "mt version ${VERSION}"
}

print_supported_command_overview() {
    local category=""
    for category in tool build plaud pr; do
        local label=""
        case "$category" in
            tool) label="工具命令" ;;
            build) label="构建命令" ;;
            plaud) label="Plaud 工具" ;;
            pr) label="PR 命令" ;;
        esac

        local names=()
        local definition=""
        for definition in "${REGISTERED_COMMANDS[@]}"; do
            IFS='|' read -r name handler cmd_category description <<< "$definition"
            if [[ "$cmd_category" == "$category" ]]; then
                names+=("$name")
            fi
        done

        if [[ -n "${names[*]-}" ]]; then
            echo -e "${CYAN}  ${label}: ${names[*]}${NC}"
        fi
    done
}

# 主函数
main() {
    check_version_update "${1:-}"

    if ! parse_global_options "$@"; then
        exit 1
    fi
    if [[ ${#PARSED_ARGS[@]} -gt 0 ]]; then
        set -- "${PARSED_ARGS[@]}"
    else
        set --
    fi

    local first_arg="${1:-help}"
    local handler=""
    handler=$(resolve_registered_command_handler "$first_arg" 2>/dev/null || echo "")
    if [[ -n "$handler" ]]; then
        shift || true
        "$handler" "$@"
        return $?
    fi

    local git_resolution=""
    git_resolution=$(resolve_git_command "$first_arg" 2>/dev/null || echo "")
    if [[ -n "$git_resolution" ]]; then
        shift || true
        IFS='|' read -r actual_cmd extra_args <<< "$git_resolution"
        local resolved_args=("$actual_cmd")
        if [[ -n "$extra_args" ]]; then
            read -ra extra_args_array <<< "$extra_args"
            resolved_args+=("${extra_args_array[@]}")
        fi
        resolved_args+=("$@")
        run_command "${resolved_args[@]}"
        return $?
    fi

    echo -e "${BOLD_RED}错误: 不支持的命令: ${first_arg}${NC}"
    echo ""
    echo -e "${YELLOW}支持的命令:${NC}"
    print_supported_command_overview
    echo -e "${CYAN}  Git 命令: ${SUPPORTED_GIT_COMMANDS[*]}${NC}"
    echo -e "${CYAN}  Git 缩写: $(get_git_alias_names)${NC}"
    echo ""
    echo -e "${YELLOW}使用 \"mt help\" 查看详细帮助信息${NC}"
    return 1
}
