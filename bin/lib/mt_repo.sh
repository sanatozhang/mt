execute_git_command() {
    local repo_info="$1"
    shift
    local git_args=("$@")

    IFS='|' read -r name path url <<< "$repo_info"
    local repo_path="${PROJECT_ROOT}/${path}"

    if [[ ! -d "$repo_path" ]]; then
        echo -e "${BOLD_YELLOW}  警告: 路径不存在 ${path}${NC}"
        return 1
    fi

    if [[ ! -d "${repo_path}/.git" ]] && [[ ! -f "${repo_path}/.git" ]]; then
        echo -e "${BOLD_YELLOW}  警告: 不是 Git 仓库 ${path}${NC}"
        return 1
    fi

    cd "$repo_path" && git "${git_args[@]}" 2>&1
    return $?
}

format_output() {
    local index=$1
    local total=$2
    local name=$3
    local success=$4
    local output=$5
    shift 5
    local git_args=("$@")

    echo -e "${BOLD_BLUE}[${index}/${total}] ${name}${NC}"

    if [[ -n "$output" ]]; then
        if [[ "${git_args[0]}" == "status" ]] && [[ "$success" == "0" ]]; then
            while IFS= read -r line; do
                if [[ -z "$line" ]]; then
                    echo ""
                    continue
                fi

                if [[ "$line" == "没有变化" ]]; then
                    echo -e "  ${GREEN}${line}${NC}"
                elif [[ "$line" =~ ^On\ branch ]]; then
                    echo -e "  ${CYAN}${line}${NC}"
                elif [[ "$line" =~ ^Changes\ to\ be\ committed ]]; then
                    echo -e "  ${GREEN}${line}${NC}"
                elif [[ "$line" =~ ^Changes\ not\ staged\ for\ commit ]]; then
                    echo -e "  ${RED}${line}${NC}"
                elif [[ "$line" =~ ^Untracked\ files ]]; then
                    echo -e "  ${RED}${line}${NC}"
                elif [[ "$line" =~ ^Your\ branch ]]; then
                    echo -e "  ${YELLOW}${line}${NC}"
                elif [[ "$line" =~ ^nothing\ to\ commit ]]; then
                    echo -e "  ${GREEN}${line}${NC}"
                elif [[ "$line" =~ ^no\ changes\ added\ to\ commit ]]; then
                    echo -e "  ${YELLOW}${line}${NC}"
                elif [[ "$line" =~ ^[[:space:]]*\(use\ \"git ]]; then
                    echo -e "  ${YELLOW}${line}${NC}"
                elif [[ "$line" =~ ^[[:space:]]*modified: ]]; then
                    echo -e "  ${RED}${line}${NC}"
                elif [[ "$line" =~ ^[[:space:]]*new\ file: ]]; then
                    echo -e "  ${GREEN}${line}${NC}"
                elif [[ "$line" =~ ^[[:space:]]*deleted: ]]; then
                    echo -e "  ${RED}${line}${NC}"
                elif [[ "$line" =~ ^[[:space:]]*renamed: ]]; then
                    echo -e "  ${YELLOW}${line}${NC}"
                elif [[ "$line" =~ ^[[:space:]]*both\ modified: ]]; then
                    echo -e "  ${RED}${line}${NC}"
                elif [[ "$line" =~ ^[[:space:]]*\?\?[[:space:]]+ ]]; then
                    echo -e "  ${RED}${line}${NC}"
                elif [[ "$line" =~ ^[[:space:]]*[AMD][[:space:]]+[[:space:]]+[^[:space:]] ]] || [[ "$line" =~ ^[[:space:]]*[AMD][[:space:]]+[[:space:]]+$ ]]; then
                    echo -e "  ${GREEN}${line}${NC}"
                elif [[ "$line" =~ ^[[:space:]]*[[:space:]]+[MDU][[:space:]]+[^[:space:]] ]] || [[ "$line" =~ ^[[:space:]]*[[:space:]]+[MDU][[:space:]]+$ ]]; then
                    echo -e "  ${RED}${line}${NC}"
                elif [[ "$line" =~ ^[[:space:]]*R[[:space:]]+ ]]; then
                    echo -e "  ${YELLOW}${line}${NC}"
                elif [[ "$line" =~ ^[[:space:]]*[[:space:]]+R ]]; then
                    echo -e "  ${RED}${line}${NC}"
                elif [[ "$line" =~ ^[[:space:]]*[AMD][[:space:]]+[MDU][[:space:]]+ ]]; then
                    echo -e "  ${GREEN}${line}${NC}"
                else
                    echo -e "  ${GRAY}${line}${NC}"
                fi
            done <<< "$output"
        elif [[ "$success" == "0" ]]; then
            while IFS= read -r line; do
                echo -e "  ${GRAY}${line}${NC}"
            done <<< "$output"
        else
            while IFS= read -r line; do
                echo -e "  ${RED}${line}${NC}"
            done <<< "$output"
        fi
    fi

    if [[ "$success" == "0" ]]; then
        if [[ "${git_args[0]}" == "status" ]]; then
            :
        elif [[ "${git_args[0]}" == "checkout" ]] && [[ -n "${git_args[1]:-}" ]] && [[ "${git_args[1]}" == "-b" ]]; then
            local branch_name="${git_args[2]:-}"
            if [[ -n "$branch_name" ]]; then
                echo -e "${BOLD_GREEN}  ${CHECK_MARK} 已创建并切换到分支: ${branch_name}${NC}"
            else
                echo -e "${BOLD_GREEN}  ${CHECK_MARK} 执行成功${NC}"
            fi
        elif [[ "${git_args[0]}" == "checkout" ]] && [[ -n "${git_args[1]:-}" ]]; then
            local branch_name="${git_args[1]}"
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 已切换到分支: ${branch_name}${NC}"
        elif [[ "${git_args[0]}" == "commit" ]]; then
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 提交成功${NC}"
        elif [[ "${git_args[0]}" == "push" ]]; then
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 推送成功${NC}"
        elif [[ "${git_args[0]}" == "pull" ]]; then
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 拉取成功${NC}"
        elif [[ "${git_args[0]}" == "add" ]]; then
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 添加成功${NC}"
        elif [[ "${git_args[0]}" == "merge" ]]; then
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 合并成功${NC}"
        elif [[ "${git_args[0]}" == "rebase" ]]; then
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 变基成功${NC}"
        else
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 执行成功${NC}"
        fi
    else
        echo -e "${BOLD_RED}  ${CROSS_MARK} 执行失败${NC}"
    fi
    echo ""
}

is_branch_related_command() {
    local cmd="${1:-}"
    case "$cmd" in
        checkout|branch|merge|rebase|switch|cherry-pick)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

execute_subrepo_command() {
    local subrepo_path="$1"
    local subrepo_name="$2"
    shift 2
    local git_args=("$@")

    if [[ ! -d "$subrepo_path" ]]; then
        return 1
    fi

    if [[ ! -d "${subrepo_path}/.git" ]] && [[ ! -f "${subrepo_path}/.git" ]]; then
        return 1
    fi

    cd "$subrepo_path" && git "${git_args[@]}" 2>&1
    return $?
}

get_branch_base_ref() {
    local repo_path="$1"
    local branch="$2"

    local base_ref=""
    local created_from_line=""
    local created_commit=""

    created_from_line=$(
        cd "$repo_path" \
        && git reflog show --format='%H|%gs' "$branch" 2>/dev/null \
        | grep -E '\|branch: Created from ' \
        | tail -n 1 \
        || true
    )

    if [[ -n "$created_from_line" ]]; then
        created_commit="${created_from_line%%|*}"
        base_ref="${created_from_line#*|}"
        base_ref="${base_ref#branch: Created from }"

        if [[ "$base_ref" == "HEAD" ]]; then
            base_ref="$created_commit"
        fi
    fi

    if [[ -z "$base_ref" ]]; then
        base_ref=$(
            cd "$repo_path" \
            && git reflog show --format='%gs' HEAD 2>/dev/null \
            | grep -E "^checkout: moving from .* to ${branch}$" \
            | tail -n 1 \
            | sed -E "s/^checkout: moving from (.*) to ${branch}$/\1/" \
            || true
        )
    fi

    echo "$base_ref"
}

check_repo_has_changes() {
    local repo_info="$1"
    local command_type="$2"
    shift 2
    local git_args=("$@")
    IFS='|' read -r name path url <<< "$repo_info"
    local repo_path="${PROJECT_ROOT}/${path}"

    if [[ ! -d "${repo_path}/.git" ]] && [[ ! -f "${repo_path}/.git" ]]; then
        return 1
    fi

    if [[ "$command_type" == "commit" ]]; then
        cd "$repo_path" && git diff --cached --quiet 2>/dev/null
        local has_staged=$?
        if [[ $has_staged -ne 0 ]]; then
            return 0
        fi
        return 1
    elif [[ "$command_type" == "push" ]]; then
        local current_branch
        current_branch=$(cd "$repo_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [[ -z "$current_branch" ]]; then
            return 1
        fi

        local remotes
        remotes=$(cd "$repo_path" && git remote 2>/dev/null)
        if [[ -z "$remotes" ]]; then
            return 1
        fi

        local push_remote=""
        local push_branch=""
        local arg_index=0
        for arg in "${git_args[@]}"; do
            if [[ "$arg" == "push" ]]; then
                ((arg_index++))
                continue
            fi
            if [[ "$arg" =~ ^- ]]; then
                ((arg_index++))
                continue
            fi
            if [[ -z "$push_remote" ]]; then
                push_remote="$arg"
                ((arg_index++))
                continue
            fi
            if [[ -z "$push_branch" ]]; then
                push_branch="$arg"
                break
            fi
        done

        if [[ -z "$push_remote" ]]; then
            push_remote="origin"
            if ! (cd "$repo_path" && git remote | grep -q "^${push_remote}$" 2>/dev/null); then
                push_remote=$(cd "$repo_path" && git remote | head -1)
            fi
        fi

        if [[ -z "$push_branch" ]]; then
            push_branch="$current_branch"
        fi

        (cd "$repo_path" && git fetch "$push_remote" "$push_branch" 2>/dev/null || true)

        if ! (cd "$repo_path" && git rev-parse --verify "$current_branch" >/dev/null 2>&1); then
            return 1
        fi

        local remote_branch_exists
        remote_branch_exists=$(cd "$repo_path" && git ls-remote --heads "$push_remote" "$push_branch" 2>/dev/null | grep -q "$push_branch" && echo "yes" || echo "no")

        if [[ "$remote_branch_exists" == "no" ]]; then
            local base_ref
            base_ref=$(get_branch_base_ref "$repo_path" "$current_branch")

            if [[ -n "$base_ref" ]]; then
                if ! (cd "$repo_path" && git rev-parse --verify "$base_ref" >/dev/null 2>&1); then
                    if (cd "$repo_path" && git rev-parse --verify "${push_remote}/${base_ref}" >/dev/null 2>&1); then
                        base_ref="${push_remote}/${base_ref}"
                    fi
                fi
            fi

            if [[ -n "$base_ref" ]] && (cd "$repo_path" && git rev-parse --verify "$base_ref" >/dev/null 2>&1); then
                local ahead_from_base
                ahead_from_base=$(cd "$repo_path" && git rev-list --count "${base_ref}..${current_branch}" 2>/dev/null || echo "0")

                if [[ "$ahead_from_base" -gt 0 ]]; then
                    return 0
                fi
                return 1
            fi

            if (cd "$repo_path" && git branch -r --contains HEAD 2>/dev/null | grep -E "^[[:space:]]*${push_remote}/" -q); then
                return 1
            fi

            local local_commits
            local_commits=$(cd "$repo_path" && git rev-list --count "$current_branch" 2>/dev/null || echo "0")
            if [[ "$local_commits" -gt 0 ]]; then
                return 0
            fi

            return 1
        fi

        (cd "$repo_path" && git fetch "$push_remote" "$push_branch" 2>/dev/null || true)

        local common_base
        common_base=$(cd "$repo_path" && git merge-base "$current_branch" "${push_remote}/${push_branch}" 2>/dev/null || echo "")

        if [[ -z "$common_base" ]]; then
            local local_commits
            local_commits=$(cd "$repo_path" && git rev-list --count "$current_branch" 2>/dev/null || echo "0")
            if [[ "$local_commits" -gt 0 ]]; then
                return 0
            fi
            return 1
        fi

        local ahead_count
        ahead_count=$(cd "$repo_path" && git rev-list --count "${push_remote}/${push_branch}..${current_branch}" 2>/dev/null || echo "0")
        if [[ "$ahead_count" -gt 0 ]]; then
            return 0
        fi

        local has_diff
        has_diff=$(cd "$repo_path" && git diff --quiet "${push_remote}/${push_branch}..${current_branch}" 2>/dev/null && echo "no" || echo "yes")
        if [[ "$has_diff" == "yes" ]]; then
            return 0
        fi

        return 1
    fi

    return 1
}

run_command() {
    local git_args=("$@")

    if is_high_risk_git_command "${git_args[@]}"; then
        if ! confirm_action true "检测到高风险 Git 操作: git ${git_args[*]}，是否继续"; then
            echo -e "${YELLOW}已取消执行${NC}"
            return 1
        fi
    fi

    local repos_array=()
    while IFS= read -r line; do
        repos_array+=("$line")
    done < <(get_selected_repositories)

    if [[ -z "${repos_array[*]-}" ]]; then
        echo -e "${BOLD_RED}错误: 没有匹配到任何仓库${NC}"
        return 1
    fi

    local total=${#repos_array[@]}
    local success_count=0
    local skipped_count=0
    local planned_count=0
    local failed_repos=()
    local skipped_repos=()
    local planned_repos=()
    json_reset

    if ! is_json_output; then
        echo -e "${BOLD_BLUE}执行命令: git ${git_args[*]}${NC}"
        echo -e "${BOLD_BLUE}仓库数量: ${total}${NC}"
        echo ""
    fi

    for i in "${!repos_array[@]}"; do
        local repo_info="${repos_array[$i]}"
        IFS='|' read -r name path url <<< "$repo_info"

        local index=$((i + 1))
        local output
        local exit_code
        local repo_path="${PROJECT_ROOT}/$(echo "$repo_info" | cut -d'|' -f2)"

        if [[ ! -d "$repo_path" ]]; then
            if ! is_json_output; then
                echo -e "${BOLD_BLUE}[${index}/${total}] ${name}${NC}"
                echo -e "${YELLOW}  ⏭  跳过: 路径不存在 ${path}${NC}"
                echo ""
            fi
            ((skipped_count++))
            skipped_repos+=("$name")
            json_add_result "$name" "skipped" "$path" "路径不存在"
            continue
        fi

        if ! is_git_repository_path "$repo_path"; then
            if ! is_json_output; then
                echo -e "${BOLD_BLUE}[${index}/${total}] ${name}${NC}"
                echo -e "${YELLOW}  ⏭  跳过: 不是 Git 仓库 ${path}${NC}"
                echo ""
            fi
            ((skipped_count++))
            skipped_repos+=("$name")
            json_add_result "$name" "skipped" "$path" "不是 Git 仓库"
            continue
        fi

        if [[ "${git_args[0]}" == "commit" ]]; then
            if ! check_repo_has_changes "$repo_info" "commit" "${git_args[@]}"; then
                if ! is_json_output; then
                    echo -e "${BOLD_BLUE}[${index}/${total}] ${name}${NC}"
                    echo -e "${YELLOW}  ⏭  跳过: 没有需要提交的修改${NC}"
                    echo ""
                fi
                ((skipped_count++))
                skipped_repos+=("$name")
                json_add_result "$name" "skipped" "$path" "没有需要提交的修改"
                continue
            fi
        elif [[ "${git_args[0]}" == "diff" ]]; then
            local diff_probe_exit=0
            (cd "$repo_path" && git diff --quiet "${git_args[@]:1}" 2>/dev/null)
            diff_probe_exit=$?

            if [[ $diff_probe_exit -eq 0 ]]; then
                if ! is_json_output; then
                    echo -e "${BOLD_BLUE}[${index}/${total}] ${name}${NC}"
                    echo -e "${YELLOW}  ⏭  没有变化${NC}"
                    echo ""
                fi
                ((skipped_count++))
                skipped_repos+=("$name")
                json_add_result "$name" "skipped" "$path" "没有变化"
                continue
            fi
        fi

        local status_clean=false
        if [[ "${git_args[0]}" == "status" ]]; then
            if [[ -d "$repo_path" ]] && { [[ -d "${repo_path}/.git" ]] || [[ -f "${repo_path}/.git" ]]; }; then
                local status_porcelain
                status_porcelain=$(cd "$repo_path" && git status --porcelain 2>/dev/null)
                if [[ -z "$status_porcelain" ]]; then
                    status_clean=true
                fi
            fi
        fi

        if [[ "$GLOBAL_DRY_RUN" == "true" ]]; then
            if ! is_json_output; then
                echo -e "${BOLD_BLUE}[${index}/${total}] ${name}${NC}"
                print_command "$repo_path" git "${git_args[@]}"
                echo -e "${YELLOW}  ⏭  dry-run: 未实际执行${NC}"
                echo ""
            fi
            ((planned_count++))
            planned_repos+=("$name")
            json_add_result "$name" "planned" "$path" "dry-run"
            continue
        fi

        if ! is_json_output; then
            print_command "$repo_path" git "${git_args[@]}"
        fi

        if [[ "$status_clean" == "true" ]]; then
            output="没有变化"
            exit_code=0
        else
            output=$(execute_git_command "$repo_info" "${git_args[@]}" 2>&1) || exit_code=$?
        fi

        if [[ ${exit_code:-0} -eq 0 ]]; then
            ((success_count++))
            json_add_result "$name" "success" "$path" "${output:-执行成功}"
            if ! is_json_output; then
                format_output "$index" "$total" "$name" "0" "$output" "${git_args[@]}"
            fi
        else
            failed_repos+=("$name")
            json_add_result "$name" "failed" "$path" "${output:-执行失败}"
            if ! is_json_output; then
                format_output "$index" "$total" "$name" "1" "$output" "${git_args[@]}"
            fi
            if [[ "$GLOBAL_FAIL_FAST" == "true" ]]; then
                break
            fi
        fi

        unset exit_code
    done

    local actual_total=$((total - skipped_count - planned_count))

    if is_json_output; then
        if [[ -n "${failed_repos[*]-}" ]]; then
            json_print_results "${git_args[0]}" "false" "部分仓库执行失败"
            return 1
        fi
        if [[ $planned_count -gt 0 ]]; then
            json_print_results "${git_args[0]}" "true" "dry-run 计划已生成"
            return 0
        fi
        json_print_results "${git_args[0]}" "true" "执行完成"
        return 0
    fi

    echo ""
    local failed_count=0
    if [[ -n "${failed_repos[*]-}" ]]; then
        failed_count=${#failed_repos[@]}
    fi
    local processed_count=$((success_count + failed_count))
    if [[ $success_count -eq $processed_count ]] && [[ $processed_count -gt 0 ]]; then
        if [[ $skipped_count -gt 0 ]]; then
            echo -e "${BOLD_GREEN}${CHECK_MARK} 所有需要处理的仓库执行成功 (${success_count}/${processed_count})${NC}"
            echo -e "${YELLOW}  跳过仓库 (${skipped_count}): ${skipped_repos[*]}${NC}"
        else
            echo -e "${BOLD_GREEN}${CHECK_MARK} 所有仓库执行成功 (${success_count}/${actual_total})${NC}"
        fi
        return 0
    elif [[ $failed_count -gt 0 ]]; then
        echo -e "${BOLD_RED}${CROSS_MARK} 部分仓库执行失败 (成功: ${success_count}, 失败: ${failed_count}, 计划: ${planned_count}, 跳过: ${skipped_count})${NC}"
        if [[ $failed_count -gt 0 ]]; then
            echo -e "${BOLD_RED}失败仓库: ${failed_repos[*]}${NC}"
        fi
        if [[ $planned_count -gt 0 ]]; then
            echo -e "${CYAN}计划执行仓库: ${planned_repos[*]}${NC}"
        fi
        if [[ $skipped_count -gt 0 ]]; then
            echo -e "${YELLOW}跳过仓库: ${skipped_repos[*]}${NC}"
        fi
        return 1
    elif [[ $planned_count -gt 0 ]]; then
        echo -e "${CYAN}⏭  dry-run: 已为 ${planned_count} 个仓库生成执行计划${NC}"
        if [[ $planned_count -gt 0 ]]; then
            echo -e "${CYAN}计划执行仓库: ${planned_repos[*]}${NC}"
        fi
        if [[ $skipped_count -gt 0 ]]; then
            echo -e "${YELLOW}跳过仓库: ${skipped_repos[*]}${NC}"
        fi
        return 0
    elif [[ $skipped_count -eq $total ]]; then
        echo -e "${YELLOW}⏭  所有仓库都没有修改，已跳过${NC}"
        return 0
    else
        local actual_total=$((total - skipped_count))
        echo -e "${BOLD_GREEN}${CHECK_MARK} 所有仓库执行成功 (${success_count}/${actual_total})${NC}"
        return 0
    fi
}

list_repositories() {
    local repos_array=()
    while IFS= read -r line; do
        repos_array+=("$line")
    done < <(get_selected_repositories)

    if [[ -z "${repos_array[*]-}" ]]; then
        echo -e "${RED}没有匹配到任何仓库${NC}"
        return 1
    fi

    json_reset

    if ! is_json_output; then
        echo -e "${BLUE}仓库列表（含默认 7 仓库）:${NC}"
        echo ""
    fi

    for i in "${!repos_array[@]}"; do
        local repo_info="${repos_array[$i]}"
        IFS='|' read -r name path url <<< "$repo_info"

        local repo_path="${PROJECT_ROOT}/${path}"
        local exists=""
        local git_repo=""

        if [[ -d "$repo_path" ]]; then
            exists="${GREEN}${CHECK_MARK}${NC}"
            if [[ -d "${repo_path}/.git" ]] || [[ -f "${repo_path}/.git" ]]; then
                git_repo="${GREEN}Git${NC}"
            else
                git_repo="${YELLOW}非Git${NC}"
            fi
        else
            exists="${RED}${CROSS_MARK}${NC}"
            git_repo="${RED}不存在${NC}"
        fi

        json_add_result "$name" "listed" "$path" "$git_repo" "\"url\":\"$(json_escape "$url")\""

        if ! is_json_output; then
            printf "  %-2s %-30s %-30s %-15s %s\n" \
                "$exists" \
                "$name" \
                "$path" \
                "$git_repo" \
                "$url"
        fi
    done

    if is_json_output; then
        json_print_results "list" "true" "仓库列表"
    fi
}

doctor() {
    json_reset

    local error_count=0
    local warning_count=0

    local brew_bin=""
    brew_bin=$(find_brew_bin 2>/dev/null || echo "")
    if [[ -n "$brew_bin" ]]; then
        json_add_result "Homebrew" "success" "$brew_bin" "已安装"
    else
        json_add_result "Homebrew" "failed" "" "未安装"
        ((error_count++))
    fi

    local fvm_bin=""
    fvm_bin=$(find_fvm_bin "$brew_bin" 2>/dev/null || echo "")
    if [[ -n "$fvm_bin" ]]; then
        json_add_result "FVM" "success" "$fvm_bin" "已安装"
    else
        json_add_result "FVM" "failed" "" "未安装"
        ((error_count++))
    fi

    if command -v fvm >/dev/null 2>&1; then
        json_add_result "fvm 命令" "success" "$(command -v fvm)" "当前 shell 可用"
    elif [[ -n "$fvm_bin" ]]; then
        json_add_result "fvm 命令" "warning" "$fvm_bin" "已安装，但当前 shell 未生效"
        ((warning_count++))
    else
        json_add_result "fvm 命令" "failed" "" "不可用"
        ((error_count++))
    fi

    local flutter_installed=false
    if [[ -n "$fvm_bin" ]]; then
        if "$fvm_bin" list 2>/dev/null | grep -Fq "$FVM_FLUTTER_VERSION"; then
            flutter_installed=true
            json_add_result "Flutter" "success" "$FVM_FLUTTER_VERSION" "已通过 FVM 安装"
        else
            json_add_result "Flutter" "failed" "$FVM_FLUTTER_VERSION" "未检测到目标版本"
            ((error_count++))
        fi
    else
        json_add_result "Flutter" "skipped" "$FVM_FLUTTER_VERSION" "FVM 不可用，跳过检测"
        ((warning_count++))
    fi

    local flutter_cmd_path=""
    if command -v flutter >/dev/null 2>&1; then
        flutter_cmd_path="$(command -v flutter)"
        json_add_result "flutter 命令" "success" "$flutter_cmd_path" "当前 shell 可用"
    elif [[ -x "${HOME}/.local/bin/flutter" ]]; then
        json_add_result "flutter 命令" "warning" "${HOME}/.local/bin/flutter" "入口已创建，但当前 shell 未生效"
        ((warning_count++))
    elif [[ "$flutter_installed" == true ]]; then
        json_add_result "flutter 命令" "warning" "$FVM_FLUTTER_VERSION" "已安装 Flutter，但未创建命令入口"
        ((warning_count++))
    else
        json_add_result "flutter 命令" "failed" "" "不可用"
        ((error_count++))
    fi

    if command -v dart >/dev/null 2>&1; then
        json_add_result "dart 命令" "success" "$(command -v dart)" "当前 shell 可用"
    elif [[ -x "${HOME}/.local/bin/dart" ]]; then
        json_add_result "dart 命令" "warning" "${HOME}/.local/bin/dart" "入口已创建，但当前 shell 未生效"
        ((warning_count++))
    elif [[ "$flutter_installed" == true ]]; then
        json_add_result "dart 命令" "warning" "$FVM_FLUTTER_VERSION" "已安装 Flutter，但未创建命令入口"
        ((warning_count++))
    else
        json_add_result "dart 命令" "failed" "" "不可用"
        ((error_count++))
    fi

    if command -v git >/dev/null 2>&1; then
        json_add_result "Git" "success" "$(command -v git)" "已安装"
    else
        json_add_result "Git" "failed" "" "未安装 Git"
        ((error_count++))
    fi

    if [[ -f "${PROJECT_ROOT}/github.token" ]]; then
        json_add_result "GitHub Token" "success" "${PROJECT_ROOT}/github.token" "已配置"
    else
        json_add_result "GitHub Token" "warning" "${PROJECT_ROOT}/github.token" "未配置"
        ((warning_count++))
    fi

    if workspace_contains_main_repositories "$PROJECT_ROOT" || [[ -f "${PROJECT_ROOT}/github.token" ]]; then
        json_add_result "Workspace Root" "success" "$PROJECT_ROOT" "已自动识别"
    else
        json_add_result "Workspace Root" "warning" "$PROJECT_ROOT" "未检测到默认仓库目录，按当前目录处理"
        ((warning_count++))
    fi

    local repos_array=()
    while IFS= read -r line; do
        repos_array+=("$line")
    done < <(get_selected_repositories 2>/dev/null || true)
    if [[ -z "${repos_array[*]-}" ]]; then
        while IFS= read -r line; do
            repos_array+=("$line")
        done < <(get_repositories 2>/dev/null || true)
    fi

    local repo_info=""
    if [[ -n "${repos_array[*]-}" ]]; then
        for repo_info in "${repos_array[@]}"; do
            IFS='|' read -r name path url <<< "$repo_info"
            local repo_path="${PROJECT_ROOT}/${path}"
            if [[ ! -d "$repo_path" ]]; then
                json_add_result "$name" "warning" "$path" "路径不存在"
                ((warning_count++))
            elif ! is_git_repository_path "$repo_path"; then
                json_add_result "$name" "warning" "$path" "不是 Git 仓库"
                ((warning_count++))
            else
                json_add_result "$name" "success" "$path" "仓库可用"
            fi
        done
    else
        json_add_result "Workspace" "warning" "$PROJECT_ROOT" "未检测到默认仓库目录，跳过仓库状态检查"
        ((warning_count++))
    fi

    if is_json_output; then
        if [[ $error_count -gt 0 ]]; then
            json_print_results "doctor" "false" "检测完成，存在 ${error_count} 个错误和 ${warning_count} 个警告"
            return 1
        fi
        json_print_results "doctor" "true" "检测完成，存在 ${warning_count} 个警告"
        return 0
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  环境检查${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local item=""
    for item in "${JSON_RESULT_ITEMS[@]}"; do
        local name
        local status
        local path
        local message
        name=$(echo "$item" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
        status=$(echo "$item" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')
        path=$(echo "$item" | sed -n 's/.*"path":"\([^"]*\)".*/\1/p')
        message=$(echo "$item" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')

        case "$status" in
            success)
                echo -e "${GREEN}${CHECK_MARK} ${name}${NC}: ${message}${path:+ (${path})}"
                ;;
            warning|skipped)
                echo -e "${YELLOW}⏭ ${name}${NC}: ${message}${path:+ (${path})}"
                ;;
            *)
                echo -e "${BOLD_RED}${CROSS_MARK} ${name}${NC}: ${message}${path:+ (${path})}"
                ;;
        esac
    done

    echo ""
    if [[ $error_count -gt 0 ]]; then
        echo -e "${BOLD_RED}${CROSS_MARK} 检查完成：${error_count} 个错误，${warning_count} 个警告${NC}"
        return 1
    fi
    echo -e "${BOLD_GREEN}${CHECK_MARK} 检查完成：0 个错误，${warning_count} 个警告${NC}"
    return 0
}

find_brew_bin() {
    if command -v brew >/dev/null 2>&1; then
        command -v brew
        return 0
    fi

    local candidates=(
        "/opt/homebrew/bin/brew"
        "/usr/local/bin/brew"
        "/home/linuxbrew/.linuxbrew/bin/brew"
    )

    local candidate=""
    for candidate in "${candidates[@]}"; do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

find_fvm_bin() {
    local brew_bin="${1:-}"

    if command -v fvm >/dev/null 2>&1; then
        command -v fvm
        return 0
    fi

    if [[ -n "$brew_bin" ]]; then
        local brew_prefix=""
        brew_prefix=$("$brew_bin" --prefix 2>/dev/null || echo "")
        if [[ -n "$brew_prefix" ]] && [[ -x "${brew_prefix}/bin/fvm" ]]; then
            echo "${brew_prefix}/bin/fvm"
            return 0
        fi
    fi

    local candidates=(
        "/opt/homebrew/bin/fvm"
        "/usr/local/bin/fvm"
        "/home/linuxbrew/.linuxbrew/bin/fvm"
    )

    local candidate=""
    for candidate in "${candidates[@]}"; do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

detect_login_shell_type() {
    local shell_name="${SHELL##*/}"
    case "$shell_name" in
        zsh)
            echo "zsh"
            ;;
        bash)
            echo "bash"
            ;;
        *)
            if [[ -n "${ZSH_VERSION:-}" ]]; then
                echo "zsh"
            elif [[ -n "${BASH_VERSION:-}" ]]; then
                echo "bash"
            else
                echo "zsh"
            fi
            ;;
    esac
}

get_shell_config_file() {
    local shell_type="${1:-}"
    case "$shell_type" in
        zsh)
            echo "${HOME}/.zshrc"
            ;;
        bash)
            echo "${HOME}/.bashrc"
            ;;
        *)
            return 1
            ;;
    esac
}

append_line_if_missing() {
    local file_path="$1"
    local line="$2"

    mkdir -p "$(dirname "$file_path")"
    touch "$file_path"

    if grep -Fqx "$line" "$file_path" 2>/dev/null; then
        return 0
    fi

    printf '%s\n' "$line" >> "$file_path"
}

ensure_shell_env_for_fvm() {
    local brew_bin="$1"
    local fvm_bin="$2"

    local shell_type
    shell_type=$(detect_login_shell_type)

    local config_file=""
    config_file=$(get_shell_config_file "$shell_type" 2>/dev/null || echo "")
    if [[ -z "$config_file" ]]; then
        echo -e "${BOLD_YELLOW}警告: 无法识别 shell 配置文件，跳过环境变量写入${NC}"
        return 0
    fi

    local brew_dir=""
    brew_dir="$(dirname "$brew_bin")"
    local local_bin_dir="${HOME}/.local/bin"

    mkdir -p "$local_bin_dir"

    append_line_if_missing "$config_file" ""
    append_line_if_missing "$config_file" "# MT runtime"
    append_line_if_missing "$config_file" "export PATH=\"${brew_dir}:\$HOME/.local/bin:\$PATH\""

    if [[ ":$PATH:" != *":${brew_dir}:"* ]]; then
        export PATH="${brew_dir}:$PATH"
    fi
    if [[ ":$PATH:" != *":${local_bin_dir}:"* ]]; then
        export PATH="${local_bin_dir}:$PATH"
    fi

    ln -sf "$fvm_bin" "${local_bin_dir}/fvm"

    cat > "${local_bin_dir}/flutter" <<'EOF'
#!/bin/bash
exec "${HOME}/.local/bin/fvm" flutter "$@"
EOF
    chmod +x "${local_bin_dir}/flutter"

    cat > "${local_bin_dir}/dart" <<'EOF'
#!/bin/bash
exec "${HOME}/.local/bin/fvm" dart "$@"
EOF
    chmod +x "${local_bin_dir}/dart"

    echo -e "${GREEN}${CHECK_MARK} 已写入 shell 环境: ${config_file}${NC}"
    echo -e "${GREEN}${CHECK_MARK} 已创建命令入口: ${local_bin_dir}/fvm, flutter, dart${NC}"
    echo -e "${YELLOW}请执行以下命令使当前终端生效:${NC}"
    echo -e "${CYAN}  source ${config_file}${NC}"
}

clone_plaud_app() {
    local target_dir="${1:-$PLAUD_APP_DEFAULT_DIR}"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  开始克隆 Plaud-App 仓库${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${CYAN}仓库地址: ${PLAUD_APP_REPO_URL}${NC}"
    echo -e "${CYAN}目标目录: ${target_dir}${NC}"
    echo ""

    if [[ -d "$target_dir" ]]; then
        echo -e "${BOLD_YELLOW}警告: 目录 ${target_dir} 已存在${NC}"
        echo -e "${YELLOW}是否要继续？(y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}已取消${NC}"
            return 0
        fi
    fi

    echo -e "${BLUE}[1/3] 克隆主仓库...${NC}"
    print_command "$(pwd)" git clone "$PLAUD_APP_REPO_URL" "$target_dir"

    if ! git clone "$PLAUD_APP_REPO_URL" "$target_dir" 2>&1; then
        echo -e "${BOLD_RED}${CROSS_MARK} 克隆失败${NC}"
        return 1
    fi

    echo ""
    echo -e "${GREEN}${CHECK_MARK} 主仓库克隆成功${NC}"
    echo ""

    echo -e "${BLUE}[2/3] 初始化子模块...${NC}"
    echo -e "${CYAN}执行: git submodule update --init --recursive${NC}"
    echo ""

    local submodule_output=""
    if ! submodule_output=$(cd "$target_dir" && git submodule update --init --recursive 2>&1); then
        echo -e "${BOLD_RED}${CROSS_MARK} 子模块初始化失败${NC}"
        echo -e "${YELLOW}输出:${NC}"
        echo "$submodule_output" | sed 's/^/  /'
        echo ""
        echo -e "${BOLD_YELLOW}警告: 主仓库已克隆成功，但子模块初始化失败${NC}"
        echo -e "${YELLOW}你可以稍后手动执行: cd ${target_dir} && git submodule update --init --recursive${NC}"
        return 1
    fi

    if [[ -n "$submodule_output" ]]; then
        echo "$submodule_output" | sed 's/^/  /'
    fi

    echo ""
    echo -e "${GREEN}${CHECK_MARK} 子模块初始化成功${NC}"
    echo ""

    echo -e "${BLUE}[3/3] 克隆 Android 子仓库...${NC}"
    local android_subrepo_path="${target_dir}/plaud-android/nicebuildSDK"
    local android_subrepo_url="git@github.com:Plaud-AI/ble-sdk-android.git"

    if [[ ! -d "${target_dir}/plaud-android" ]]; then
        echo -e "${BOLD_YELLOW}警告: plaud-android 目录不存在，跳过 Android 子仓库克隆${NC}"
    elif [[ -d "$android_subrepo_path" ]]; then
        echo -e "${YELLOW}  ⏭  跳过: nicebuildSDK 目录已存在${NC}"
    else
        echo -e "${CYAN}执行: git clone ${android_subrepo_url} ${android_subrepo_path}${NC}"
        echo ""

        if ! (cd "${target_dir}/plaud-android" && git clone "$android_subrepo_url" "nicebuildSDK" 2>&1); then
            echo -e "${BOLD_YELLOW}警告: Android 子仓库克隆失败${NC}"
            echo -e "${YELLOW}你可以稍后手动执行: cd ${target_dir}/plaud-android && git clone ${android_subrepo_url} nicebuildSDK${NC}"
        else
            echo ""
            echo -e "${GREEN}${CHECK_MARK} Android 子仓库克隆成功${NC}"
        fi
    fi

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}${CHECK_MARK} Plaud-App 仓库克隆完成${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${CYAN}下一步:${NC}"
    echo -e "${CYAN}  cd ${target_dir}${NC}"
    echo -e "${CYAN}  mt list${NC}"

    return 0
}

bootstrap_environment_and_clone() {
    local target_dir="${1:-$PLAUD_APP_DEFAULT_DIR}"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  初始化开发环境${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    echo -e "${BLUE}[1/3] 检查 Homebrew...${NC}"
    local brew_bin=""
    brew_bin=$(find_brew_bin 2>/dev/null || echo "")
    if [[ -z "$brew_bin" ]]; then
        echo -e "${BOLD_RED}${CROSS_MARK} 未检测到 Homebrew${NC}"
        echo -e "${YELLOW}请先安装 Homebrew，安装完成后重新执行 mt init${NC}"
        echo -e "${CYAN}官网: https://brew.sh${NC}"
        echo -e "${CYAN}安装命令:${NC}"
        echo -e "${CYAN}  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
        return 1
    fi
    echo -e "${GREEN}${CHECK_MARK} Homebrew 已安装: ${brew_bin}${NC}"
    echo ""

    echo -e "${BLUE}[2/3] 检查 FVM 并安装 Flutter ${FVM_FLUTTER_VERSION}...${NC}"
    local fvm_bin=""
    fvm_bin=$(find_fvm_bin "$brew_bin" 2>/dev/null || echo "")
    if [[ -z "$fvm_bin" ]]; then
        echo -e "${YELLOW}未检测到 FVM，正在通过 Homebrew 安装...${NC}"
        print_command "$(pwd)" "$brew_bin" tap "$FVM_BREW_TAP"
        if ! "$brew_bin" tap "$FVM_BREW_TAP" 2>&1; then
            echo -e "${BOLD_RED}${CROSS_MARK} Homebrew tap 失败${NC}"
            return 1
        fi

        print_command "$(pwd)" "$brew_bin" install fvm
        if ! "$brew_bin" install fvm 2>&1; then
            echo -e "${BOLD_RED}${CROSS_MARK} FVM 安装失败${NC}"
            return 1
        fi

        fvm_bin=$(find_fvm_bin "$brew_bin" 2>/dev/null || echo "")
        if [[ -z "$fvm_bin" ]]; then
            echo -e "${BOLD_RED}${CROSS_MARK} FVM 已安装，但当前终端无法找到 fvm 命令${NC}"
            echo -e "${YELLOW}请确认 Homebrew 的 bin 目录已加入 PATH 后重试${NC}"
            return 1
        fi
        echo -e "${GREEN}${CHECK_MARK} FVM 安装成功: ${fvm_bin}${NC}"
    else
        echo -e "${GREEN}${CHECK_MARK} FVM 已安装: ${fvm_bin}${NC}"
    fi

    ensure_shell_env_for_fvm "$brew_bin" "$fvm_bin"

    print_command "$(pwd)" "$fvm_bin" install "$FVM_FLUTTER_VERSION"
    if ! "$fvm_bin" install "$FVM_FLUTTER_VERSION" 2>&1; then
        echo -e "${BOLD_RED}${CROSS_MARK} Flutter ${FVM_FLUTTER_VERSION} 安装失败${NC}"
        return 1
    fi

    print_command "$(pwd)" "$fvm_bin" global "$FVM_FLUTTER_VERSION"
    if ! "$fvm_bin" global "$FVM_FLUTTER_VERSION" 2>&1; then
        echo -e "${BOLD_RED}${CROSS_MARK} Flutter ${FVM_FLUTTER_VERSION} 全局配置失败${NC}"
        return 1
    fi

    if ! "${HOME}/.local/bin/flutter" --version >/dev/null 2>&1; then
        echo -e "${BOLD_RED}${CROSS_MARK} flutter 命令验证失败${NC}"
        echo -e "${YELLOW}请执行 source 你的 shell 配置后重试${NC}"
        return 1
    fi

    if ! "${HOME}/.local/bin/dart" --version >/dev/null 2>&1; then
        echo -e "${BOLD_RED}${CROSS_MARK} dart 命令验证失败${NC}"
        echo -e "${YELLOW}请执行 source 你的 shell 配置后重试${NC}"
        return 1
    fi

    echo -e "${GREEN}${CHECK_MARK} Flutter ${FVM_FLUTTER_VERSION} 已准备完成${NC}"
    echo ""

    echo -e "${BLUE}[3/3] 执行 mt clone...${NC}"
    local clone_exit_code=0
    capture_command_exit clone_exit_code clone_plaud_app "$target_dir"
    if [[ $clone_exit_code -ne 0 ]]; then
        print_composite_failure "init 命令" "clone 步骤失败"
        return "$clone_exit_code"
    fi

    print_composite_success "init 命令"
    return 0
}

set_github_token() {
    local token="$1"

    if [[ -z "$token" ]]; then
        echo -e "${BOLD_RED}错误: 请提供 GitHub token${NC}"
        echo -e "${YELLOW}用法: mt set-github-token <your_token>${NC}"
        echo -e "${CYAN}获取 token: https://github.com/settings/tokens${NC}"
        return 1
    fi

    local token_file="${PROJECT_ROOT}/github.token"
    echo "$token" > "$token_file"
    chmod 600 "$token_file"

    echo -e "${GREEN}${CHECK_MARK} GitHub token 已保存${NC}"
    echo -e "${CYAN}Token 已保存到: ${token_file}${NC}"
    echo -e "${YELLOW}提示: github.token 文件已添加到 .gitignore，不会被提交到 Git${NC}"

    return 0
}

upgrade_mt() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  升级 MT 工具${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local mt_repo_dir
    mt_repo_dir="$(get_mt_dir)"

    if [[ ! -d "${mt_repo_dir}/.git" ]] && [[ ! -f "${mt_repo_dir}/.git" ]]; then
        echo -e "${BOLD_RED}错误: 无法找到 mt Git 仓库${NC}"
        echo -e "${YELLOW}当前脚本路径: ${BASH_SOURCE[0]:-$0}${NC}"
        echo -e "${YELLOW}计算的 mt 目录: ${mt_repo_dir}${NC}"
        echo -e "${YELLOW}请确保 mt 工具是从 Git 仓库安装的${NC}"
        return 1
    fi

    local current_branch
    current_branch=$(cd "$MT_DIR" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [[ -z "$current_branch" ]]; then
        echo -e "${BOLD_RED}错误: 无法获取当前分支${NC}"
        return 1
    fi

    echo -e "${CYAN}当前分支: ${current_branch}${NC}"
    echo -e "${CYAN}mt 仓库目录: ${mt_repo_dir}${NC}"
    echo ""

    echo -e "${BLUE}[1/3] 获取远程更新...${NC}"
    print_command "$mt_repo_dir" git fetch origin

    (cd "$mt_repo_dir" && git fetch origin 2>&1) || {
        echo -e "${BOLD_RED}错误: 获取远程更新失败${NC}"
        return 1
    }
    echo -e "${GREEN}${CHECK_MARK} 远程更新获取成功${NC}"
    echo ""

    local target_branch="${current_branch:-main}"
    local local_commit
    local remote_commit
    local_commit=$(cd "$mt_repo_dir" && git rev-parse HEAD 2>/dev/null)
    remote_commit=$(cd "$mt_repo_dir" && git rev-parse "origin/${target_branch}" 2>/dev/null)

    if [[ "$local_commit" == "$remote_commit" ]]; then
        echo -e "${GREEN}${CHECK_MARK} 已是最新版本${NC}"
        echo -e "${BLUE}========================================${NC}"
        return 0
    fi

    echo -e "${BLUE}[2/3] 检查更新...${NC}"
    local commit_count
    commit_count=$(cd "$mt_repo_dir" && git rev-list --count HEAD.."origin/${target_branch}" 2>/dev/null || echo "0")

    if [[ "$commit_count" -gt 0 ]]; then
        echo -e "${CYAN}发现 ${commit_count} 个新提交${NC}"
        echo ""
        echo -e "${CYAN}最近的更新:${NC}"
        (cd "$mt_repo_dir" && git log --oneline HEAD.."origin/${target_branch}" | head -5)
        echo ""
    fi

    read -p "是否执行更新? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消更新${NC}"
        return 0
    fi

    echo -e "${BLUE}[3/3] 执行更新...${NC}"
    print_command "$mt_repo_dir" git pull origin "${target_branch}"

    (cd "$mt_repo_dir" && git pull origin "${target_branch}" 2>&1) || {
        echo -e "${BOLD_RED}错误: 更新失败${NC}"
        echo -e "${YELLOW}请手动执行: cd ${mt_repo_dir} && git pull origin ${target_branch}${NC}"
        return 1
    }

    echo ""
    echo -e "${BOLD_GREEN}${CHECK_MARK} 更新成功！${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${CYAN}当前版本:${NC}"
    (cd "$mt_repo_dir" && git log --oneline -1)
    echo ""
    echo -e "${YELLOW}提示: 如果 mt 命令已安装，可能需要重新安装以使用新版本${NC}"
    return 0
}

delete_branches() {
    local delete_all=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--a|--all)
                delete_all=true
                shift
                ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                echo -e "${YELLOW}用法: mt delete [-a|--all]${NC}"
                return 1
                ;;
        esac
    done

    if ! confirm_action true "delete 命令会批量删除分支，是否继续"; then
        echo -e "${YELLOW}已取消删除${NC}"
        return 1
    fi

    local repos_array=()
    while IFS= read -r line; do
        repos_array+=("$line")
    done < <(get_selected_repositories)

    if [[ -z "${repos_array[*]-}" ]]; then
        echo -e "${BOLD_RED}错误: 没有匹配到任何仓库${NC}"
        return 1
    fi

    json_reset

    if ! is_json_output; then
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  删除本地分支${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""
    fi

    local total=${#repos_array[@]}
    local success_count=0
    local skipped_count=0
    local failure_count=0

    for i in "${!repos_array[@]}"; do
        local repo_info="${repos_array[$i]}"
        IFS='|' read -r name path url <<< "$repo_info"

        local repo_path="${PROJECT_ROOT}/${path}"
        local index=$((i + 1))

        if ! is_json_output; then
            echo -e "${CYAN}[${index}/${total}] ${name}${NC}"
        fi

        if [[ ! -d "$repo_path" ]]; then
            if ! is_json_output; then
                echo -e "${YELLOW}  ⏭  跳过: 路径不存在 ${path}${NC}"
                echo ""
            fi
            ((skipped_count++))
            json_add_result "$name" "skipped" "$path" "路径不存在"
            continue
        fi

        if [[ ! -d "${repo_path}/.git" ]] && [[ ! -f "${repo_path}/.git" ]]; then
            if ! is_json_output; then
                echo -e "${YELLOW}  ⏭  跳过: 不是 Git 仓库 ${path}${NC}"
                echo ""
            fi
            ((skipped_count++))
            json_add_result "$name" "skipped" "$path" "不是 Git 仓库"
            continue
        fi

        local current_branch
        current_branch=$(cd "$repo_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [[ -z "$current_branch" ]]; then
            if ! is_json_output; then
                echo -e "${YELLOW}  ⏭  跳过: 无法获取当前分支${NC}"
                echo ""
            fi
            ((skipped_count++))
            json_add_result "$name" "skipped" "$path" "无法获取当前分支"
            continue
        fi

        local branches=()
        while IFS= read -r branch; do
            branch=$(echo "$branch" | sed 's/^[* ]*//')
            if [[ "$branch" != "$current_branch" ]] && [[ "$branch" != "main" ]] && [[ "$branch" != "master" ]]; then
                branches+=("$branch")
            fi
        done < <(cd "$repo_path" && git branch 2>/dev/null)

        local branch_count=${#branches[@]}
        if [[ $branch_count -eq 0 ]]; then
            if ! is_json_output; then
                echo -e "${YELLOW}  ⏭  跳过: 没有可删除的分支${NC}"
                echo ""
            fi
            ((skipped_count++))
            json_add_result "$name" "skipped" "$path" "没有可删除的分支"
            continue
        fi

        if [[ "$delete_all" == true ]]; then
            if ! is_json_output; then
                echo -e "${CYAN}  当前分支: ${current_branch}${NC}"
                echo -e "${CYAN}  将删除 ${branch_count} 个分支${NC}"
                echo ""
            fi

            local deleted_count=0
            local failed_count=0

            for branch in "${branches[@]}"; do
                if [[ "$GLOBAL_DRY_RUN" == "true" ]]; then
                    if ! is_json_output; then
                        echo -e "${CYAN}    dry-run: 将删除分支 ${branch}${NC}"
                    fi
                    ((deleted_count++))
                else
                    if ! is_json_output; then
                        echo -e "${CYAN}    删除分支: ${branch}${NC}"
                    fi
                    if (cd "$repo_path" && git branch -D "$branch" 2>&1); then
                        if ! is_json_output; then
                            echo -e "${BOLD_GREEN}      ${CHECK_MARK} 删除成功${NC}"
                        fi
                        ((deleted_count++))
                    else
                        if ! is_json_output; then
                            echo -e "${BOLD_RED}      ${CROSS_MARK} 删除失败${NC}"
                        fi
                        ((failed_count++))
                    fi
                fi
            done

            if ! is_json_output; then
                echo ""
            fi
            if [[ $deleted_count -gt 0 ]]; then
                if ! is_json_output; then
                    echo -e "${BOLD_GREEN}  ${CHECK_MARK} 成功删除 ${deleted_count} 个分支${NC}"
                fi
                ((success_count++))
                json_add_result "$name" "$([[ "$GLOBAL_DRY_RUN" == "true" ]] && echo "planned" || echo "success")" "$path" "处理 ${deleted_count} 个分支"
            fi
            if [[ $failed_count -gt 0 ]]; then
                if ! is_json_output; then
                    echo -e "${BOLD_RED}  ${CROSS_MARK} 删除失败 ${failed_count} 个分支${NC}"
                fi
                ((failure_count += failed_count))
                json_add_result "$name" "failed" "$path" "删除失败 ${failed_count} 个分支"
                if [[ "$GLOBAL_FAIL_FAST" == "true" ]]; then
                    break
                fi
            fi
        else
            if [[ $branch_count -lt 8 ]]; then
                if ! is_json_output; then
                    echo -e "${YELLOW}  ⏭  跳过: 分支数量 (${branch_count}) 小于 8，不执行删除${NC}"
                    echo -e "${CYAN}    提示: 使用 -a 参数可以删除所有分支（除了当前分支和 main/master）${NC}"
                    echo ""
                fi
                ((skipped_count++))
                json_add_result "$name" "skipped" "$path" "分支数量不足 8"
                continue
            fi

            local branches_with_date=()
            for branch in "${branches[@]}"; do
                local last_commit_date
                last_commit_date=$(cd "$repo_path" && git log -1 --format="%ct" "$branch" 2>/dev/null || echo "0")
                branches_with_date+=("${last_commit_date}|${branch}")
            done

            local sorted_branches_str
            sorted_branches_str=$(printf '%s\n' "${branches_with_date[@]}" | sort -t'|' -k1 -n)
            local sorted_branches=()
            while IFS= read -r sorted_branch; do
                sorted_branches+=("$sorted_branch")
            done <<< "$sorted_branches_str"

            local branches_to_delete=()
            local count=0
            for branch_info in "${sorted_branches[@]}"; do
                if [[ $count -ge 3 ]]; then
                    break
                fi
                local branch_name
                branch_name=$(echo "$branch_info" | cut -d'|' -f2)
                branches_to_delete+=("$branch_name")
                ((count++))
            done

            if ! is_json_output; then
                echo -e "${CYAN}  当前分支: ${current_branch}${NC}"
                echo -e "${CYAN}  分支总数: ${branch_count}${NC}"
                echo -e "${CYAN}  将删除最旧的 3 个分支:${NC}"
                for branch in "${branches_to_delete[@]}"; do
                    local last_commit_date
                    last_commit_date=$(cd "$repo_path" && git log -1 --format="%ci" "$branch" 2>/dev/null || echo "未知")
                    echo -e "${CYAN}    - ${branch} (最后提交: ${last_commit_date})${NC}"
                done
                echo ""
            fi

            local deleted_count=0
            local failed_count=0

            for branch in "${branches_to_delete[@]}"; do
                if [[ "$GLOBAL_DRY_RUN" == "true" ]]; then
                    if ! is_json_output; then
                        echo -e "${CYAN}    dry-run: 将删除分支 ${branch}${NC}"
                    fi
                    ((deleted_count++))
                else
                    if ! is_json_output; then
                        echo -e "${CYAN}    删除分支: ${branch}${NC}"
                    fi
                    if (cd "$repo_path" && git branch -D "$branch" 2>&1); then
                        if ! is_json_output; then
                            echo -e "${BOLD_GREEN}      ${CHECK_MARK} 删除成功${NC}"
                        fi
                        ((deleted_count++))
                    else
                        if ! is_json_output; then
                            echo -e "${BOLD_RED}      ${CROSS_MARK} 删除失败${NC}"
                        fi
                        ((failed_count++))
                    fi
                fi
            done

            if ! is_json_output; then
                echo ""
            fi
            if [[ $deleted_count -gt 0 ]]; then
                if ! is_json_output; then
                    echo -e "${BOLD_GREEN}  ${CHECK_MARK} 成功删除 ${deleted_count} 个分支${NC}"
                fi
                ((success_count++))
                json_add_result "$name" "$([[ "$GLOBAL_DRY_RUN" == "true" ]] && echo "planned" || echo "success")" "$path" "处理 ${deleted_count} 个分支"
            fi
            if [[ $failed_count -gt 0 ]]; then
                if ! is_json_output; then
                    echo -e "${BOLD_RED}  ${CROSS_MARK} 删除失败 ${failed_count} 个分支${NC}"
                fi
                ((failure_count += failed_count))
                json_add_result "$name" "failed" "$path" "删除失败 ${failed_count} 个分支"
                if [[ "$GLOBAL_FAIL_FAST" == "true" ]]; then
                    break
                fi
            fi
        fi
        if ! is_json_output; then
            echo ""
        fi
    done

    if is_json_output; then
        if [[ $failure_count -gt 0 ]]; then
            json_print_results "delete" "false" "删除分支执行完成，存在失败项"
            return 1
        fi
        json_print_results "delete" "true" "删除分支执行完成"
        return 0
    fi

    echo -e "${BLUE}========================================${NC}"
    if [[ $success_count -gt 0 ]]; then
        echo -e "${GREEN}${CHECK_MARK} 成功处理 ${success_count} 个仓库${NC}"
    fi
    if [[ $skipped_count -gt 0 ]]; then
        echo -e "${YELLOW}⏭  跳过 ${skipped_count} 个仓库${NC}"
    fi
    if [[ $failure_count -gt 0 ]]; then
        echo -e "${BOLD_RED}${CROSS_MARK} 删除失败 ${failure_count} 个分支${NC}"
        echo -e "${BLUE}========================================${NC}"
        return 1
    fi
    echo -e "${BLUE}========================================${NC}"

    return 0
}

show_help() {
    cat << EOF
MT - Multi-repo Tool v${VERSION}
多仓库 Git 管理工具

用法:
  mt [全局选项] <git-command> [git-options]
  mt [全局选项] [工具命令]

全局选项:
  --current                    只作用于当前所在仓库
  --all                        作用于匹配范围内的所有仓库（默认）
  --main-only                  只作用于主仓库
  --subrepos-only              只作用于子仓库
  --only <repo>                只作用于指定仓库名或路径，可重复传入
  --exclude <repo>             排除指定仓库名或路径，可重复传入
  --dry-run                    只打印将执行的操作，不实际执行
  --json                       以 JSON 输出结果（当前支持 list/doctor/大多数多仓库 Git 命令/delete）
  --fail-fast                  遇到第一个失败立即停止
  --continue-on-error          失败后继续执行其他仓库（默认）
  --confirm                    强制要求确认后再执行
  --no-confirm                 跳过高风险命令确认

Git 命令示例:
  mt --current checkout -b <branch>  只在当前仓库创建并切换分支
  mt checkout -b <branch>     创建并切换分支（所有仓库）
  mt checkout <branch>         切换分支（所有仓库）
  mt commit -m "<message>"     提交代码（自动跳过没有暂存修改的仓库）
  mt add <files>               添加文件
  mt push [remote] [branch]    推送代码（自动跳过没有代码变更的仓库）
    说明: 基于基线分支判断是否需要推送；如果分支相对切出的基线分支没有新增提交，则跳过
  mt pull [remote] [branch]    拉取代码
  mt status                    查看状态（所有仓库）
  mt branch                    查看分支（所有仓库）
  mt diff                      查看差异（自动跳过没有变化的仓库）
  mt fetch                     获取更新
  mt merge <branch>            合并分支（所有仓库）
  mt rebase <branch>           变基（所有仓库）
  mt submodule [options]       子模块操作（所有仓库）
    示例: mt submodule update --init --recursive

Git 命令缩写支持:
  基础命令:
    mt co <branch>               checkout 的缩写
    mt cob <branch>              checkout -b 的缩写（创建并切换分支）
    mt br                         branch 的缩写
    mt bra                        branch -a 的缩写（显示所有分支）
    mt ci [options]               commit 的缩写（也可用 cm）
    mt cim "<message>"            commit -m 的缩写
    mt ciam "<message>"           commit -am 的缩写
    mt cane                       commit --amend --no-edit 的缩写
    mt st                         status 的缩写
    mt ps [remote] [branch]       push 的缩写（也可用 ph）
    mt phf [remote] [branch]      push -f 的缩写
    mt pl [remote] [branch]       pull 的缩写
    mt plro [branch]              pull --rebase origin 的缩写
    mt m <branch>                 merge 的缩写
    mt rb <branch>                rebase 的缩写
    mt rbi <branch>               rebase -i 的缩写（交互式变基）
    mt rba                        rebase --abort 的缩写
    mt rbc                        rebase --continue 的缩写
    mt sa                          stash 的缩写
    mt shs [message]              stash save 的缩写
    mt sha [stash]                stash apply 的缩写
    mt shp [stash]                stash pop 的缩写
    mt shd [stash]                stash drop 的缩写
    mt sw <branch>                switch 的缩写
    mt cp <commit>                cherry-pick 的缩写
    mt cpa                        cherry-pick --abort 的缩写
    mt cpc                        cherry-pick --continue 的缩写
    mt fe                          fetch 的缩写（也可用 ft）
    mt di                          diff 的缩写
    mt lo                          log 的缩写
    mt rs [options]                reset 的缩写
    mt rth [commit]               reset --hard 的缩写
    mt rts [commit]               reset --soft 的缩写
    mt rv <commit>                 revert 的缩写
    mt sh <commit>                 show 的缩写
    mt ta [options]                tag 的缩写
    mt ad <files>                  add 的缩写

工具命令:
  mt list                      列出固定支持的仓库
  mt doctor                    检查开发环境、工作区和仓库状态
  mt init [目录名]             创建项目环境，安装并配置 Flutter ${FVM_FLUTTER_VERSION}，并克隆 Plaud-App
                                  默认目录名: ${PLAUD_APP_DEFAULT_DIR}
  mt config                    兼容入口：当前版本无需 .mt-config.yaml
  mt clone [目录名]             仅克隆 Plaud-App 仓库并初始化子模块
                                  默认目录名: ${PLAUD_APP_DEFAULT_DIR}
                                  会自动执行 git submodule update --init --recursive
  mt set-github-token <token>  设置 GitHub token（用于创建 PR）
  mt delete [-a|--all]         删除本地分支
                                  默认: 删除最近没有使用的3个分支（分支数需>=8）
                                  -a: 删除所有分支（除了当前分支和 main/master）
  mt clean [-a|-i|-f]           清除缓存
                                  默认: 清除全部（Android + iOS + Flutter）
                                  -a, --android: 只清除 Android 缓存
                                  -i, --ios: 只清除 iOS 缓存
                                  -f, --flutter: 只清除 Flutter 缓存
  mt upgrade                    更新 mt 工具到最新版本
  mt help                      显示帮助信息
  mt --version                 显示版本号

Plaud 工具命令:
  mt plaud version -c <code> [-f]    版本号转换：versionCode → 版本字符串
  mt plaud version -s <string>       版本号转换：版本字符串 → versionCode
  mt plaud log sync <file>           分析日志中的同步操作记录
  mt plaud log clean <file>         清理网络日志格式
  mt plaud log time-diff <file>     分析同步时间差（支持 --min-diff 过滤）
  mt plaud check opus <file>        检查 Opus 文件格式
  mt plaud copy <file> [count]      批量复制文件（文件名自动递增）
  mt plaud decrypt <file> [-o <dir>]  解密 Plaud 加密文件

PR 命令:
  mt pr [options]
    为所有仓库创建 GitHub Pull Request
    选项:
      -b, --b, --base <branch>  目标分支（默认: main）
      -t, --t, --title <title> PR 标题（默认: 使用当前分支名）
      -d, --d, --description <text> PR 描述
      -r, --ready               创建后将 PR 设为 Ready（非 Draft）
    注意:
      - 需要设置 GitHub token，使用 'mt set-github-token <token>' 命令
      - 新建 PR 默认创建为 Draft（WIP），并自动：
        * 请求 Copilot 作为 reviewer（最佳努力）
        * 添加 label：MT AUTO
      - 已存在的 PR 不会修改状态、reviewer 或 label
      - 如果 PR 已存在，会返回已存在的 PR URL
      - 会自动跳过没有代码变更的仓库
      - 如果有未提交的修改或本地分支未推送，会提示需要先提交/推送

构建命令:
  mt prebuild                              执行 Flutter 预构建（build_all.sh / pub get / 多语言等）
  mt build [cn|global] [options]
    构建 Android 包（默认构建 global debug）
    选项:
      -d, --d, --debug          构建 Debug 包（默认）
      -r, --r, --release        构建 Release 包
      -p, --p, --profile        构建 Profile 包（未来支持）
      -c, --c, --channel <name> CN 版本指定渠道（official/huawei/xiaomi/oppo/vivo/honor/yingyongbao）
      -a, --a, --all            CN 版本构建所有渠道（仅 release）
    说明: build 命令不会执行 clean，直接构建以加快速度（如需 clean，请先执行 mt clean）

  mt install [cn|global] [options]
    执行 Android 打包并安装到设备（参数与 build 命令相同）
    选项: 与 build 命令相同
    注意: 需要设备已通过 USB 连接并启用 USB 调试
    说明: install 命令不会执行 clean，直接构建以加快速度

  mt install ios [cn|global] [options]
  mt install:ios [cn|global] [options]
    执行 iOS 打包并安装到真机设备
    选项:
      -d, --d, --debug          构建 Debug 包（默认）
      -r, --r, --release        构建 Release 包
    注意: 需要设备已通过 USB 连接并信任此计算机
    说明: 多个设备时会提示选择；install 命令不会执行 clean，直接构建以加快速度

  mt go [cn|global] [options]
    新手推荐命令：执行 prebuild + install（快速开发流程）
    选项: 与 build 命令相同
    说明: 默认执行 Android Global debug；先执行 prebuild，再构建并安装到设备

  mt rebuild [cn|global] [options]
    清理缓存并重新构建（clean + go）
    选项: 与 build 命令相同
    说明: 先执行 clean 清理所有缓存，然后执行 go 命令（prebuild + install）
    等同于: mt clean && mt go [cn|global] [options]

  mt build:check [-d|-r]
    编译检查：同时构建 CN 和 Global 版本（用于 push 前检查，默认 debug）

  mt build:ios [cn|global] [options]
    构建 iOS 包（使用 xcodebuild）
    选项:
      -d, --d, --debug          构建 Debug 包（默认）
      -r, --r, --release        构建 Release 包
    说明: build:ios 命令不会执行 clean，直接构建以加快速度（如需 clean，请先执行 mt clean）

构建示例:
  mt prebuild                              # Flutter 预构建（pub get / 多语言等）
  mt build                                 # Global debug（默认）
  mt build -r                              # Global release
  mt build cn                              # CN 官方渠道 debug（默认）
  mt build cn -r                           # CN 官方渠道 release
  mt build cn -c huawei -r                 # CN 华为渠道 release
  mt build cn -a -r                        # CN 所有渠道 release
  mt build global                          # Global debug
  mt build global -r                       # Global release
  mt install cn                            # 打包并安装 CN debug 包（Android）
  mt install cn -r                        # 构建并安装 CN release 包（Android）
  mt install global                        # 打包并安装 Global debug 包（Android）
  mt install global -r                    # 构建并安装 Global release 包（Android）
  mt install ios                           # 打包并安装 iOS Global debug 包（真机）
  mt install ios -r                        # 构建并安装 iOS Global release 包（真机）
  mt install ios cn                        # 构建并安装 iOS CN debug 包（真机）
  mt install ios cn -r                     # 构建并安装 iOS CN release 包（真机）
  mt install:ios                           # 同上（别名）
  mt go                                    # 新手推荐：执行 prebuild + install（Global debug，Android）
  mt go cn                                 # 执行 prebuild + install（CN debug，Android）
  mt go cn -r                              # 执行 prebuild + install（CN release，Android）
  mt rebuild                                # 清理缓存并重新构建（Global debug，Android）
  mt rebuild cn                             # 清理缓存并重新构建（CN debug，Android）
  mt rebuild cn -r                          # 清理缓存并重新构建（CN release，Android）
  mt clean                                  # 清理全部缓存（Android + iOS + Flutter）
  mt clean -a                               # 只清理 Android 缓存
  mt clean -i                               # 只清理 iOS 缓存
  mt clean -f                               # 只清理 Flutter 缓存
  mt build:check -r                        # 同时构建 CN 和 Global release（Android）
  mt build:ios                             # iOS Global debug（默认）
  mt build:ios -r                          # iOS Global release
  mt build:ios cn                         # iOS CN debug
  mt build:ios cn -r                      # iOS CN release

Plaud 工具示例:
  mt plaud version -c 66048                     # versionCode → 版本字符串
  mt plaud version -c 66048 -f                  # 输出完整版本（包含修订号）
  mt plaud version -s 1.0.0                     # 版本字符串 → versionCode
  mt plaud log sync app.log                      # 分析同步操作日志
  mt plaud log clean network.log                 # 清理网络日志格式
  mt plaud log time-diff app.log                 # 分析同步时间差
  mt plaud log time-diff app.log --min-diff 0.1  # 只显示时间差 >= 0.1秒的记录
  mt plaud check opus data.txt                   # 检查 Opus 文件格式
  mt plaud copy file.ogg                        # 复制文件50次（默认）
  mt plaud copy file.ogg 100                     # 复制文件100次
  mt plaud decrypt encrypted.plaud                  # 解密 Plaud 文件（输出到默认目录）
  mt plaud decrypt encrypted.plaud -o ./output      # 指定输出目录

PR 示例:
  mt pr                                    # 为所有仓库创建 PR（目标分支: main）
  mt pr -b develop                        # 目标分支为 develop
  mt pr -t "Add new feature"              # 指定 PR 标题
  mt pr -t "Fix bug" -d "修复了某个问题"   # 指定标题和描述
  mt pr -r                                # 创建后自动设置为 Ready

示例:
  mt checkout -b feature/new-feature
  mt add .
  mt commit -m "Add new feature"
  mt push origin feature/new-feature
  mt status

更多信息:
  查看 mt/doc/README.md 获取详细文档
EOF
}
