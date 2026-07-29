execute_git_command() {
    local repo_info="$1"
    shift
    local git_args=("$@")

    IFS='|' read -r name path url <<< "$repo_info"
    local repo_path="${PROJECT_ROOT}/${path}"

    if [[ ! -d "$repo_path" ]]; then
        echo -e "${BOLD_YELLOW}  警告: 路径不存在 ${path} / Warning: path not found ${path}${NC}"
        return 1
    fi

    if [[ ! -d "${repo_path}/.git" ]] && [[ ! -f "${repo_path}/.git" ]]; then
        echo -e "${BOLD_YELLOW}  警告: 不是 Git 仓库 ${path} / Warning: not a Git repository ${path}${NC}"
        return 1
    fi

    cd "$repo_path" && git "${git_args[@]}" 2>&1
    return $?
}

# 判断 git 子命令是否是长耗时网络命令（需要流式输出避免"卡死"误判）
is_long_running_git_command() {
    local sub_cmd="${1:-}"
    case "$sub_cmd" in
        fetch|pull|push|clone)
            return 0
            ;;
        submodule)
            local sub_arg=""
            for sub_arg in "${@:2}"; do
                case "$sub_arg" in
                    update|sync|foreach) return 0 ;;
                esac
            done
            return 1
            ;;
    esac
    return 1
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
                    echo -e "  ${GREEN}${line} / No changes${NC}"
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
                echo -e "${BOLD_GREEN}  ${CHECK_MARK} 已创建并切换到分支 / Created and switched to branch: ${branch_name}${NC}"
            else
                echo -e "${BOLD_GREEN}  ${CHECK_MARK} 执行成功 / Succeeded${NC}"
            fi
        elif [[ "${git_args[0]}" == "checkout" ]] && [[ -n "${git_args[1]:-}" ]]; then
            local branch_name="${git_args[1]}"
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 已切换到分支 / Switched to branch: ${branch_name}${NC}"
        elif [[ "${git_args[0]}" == "commit" ]]; then
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 提交成功 / Committed successfully${NC}"
        elif [[ "${git_args[0]}" == "push" ]]; then
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 推送成功 / Pushed successfully${NC}"
        elif [[ "${git_args[0]}" == "pull" ]]; then
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 拉取成功 / Pulled successfully${NC}"
        elif [[ "${git_args[0]}" == "add" ]]; then
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 添加成功 / Added successfully${NC}"
        elif [[ "${git_args[0]}" == "merge" ]]; then
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 合并成功 / Merged successfully${NC}"
        elif [[ "${git_args[0]}" == "rebase" ]]; then
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 变基成功 / Rebased successfully${NC}"
        else
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} 执行成功 / Succeeded${NC}"
        fi
    else
        echo -e "${BOLD_RED}  ${CROSS_MARK} 执行失败 / Failed${NC}"
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
        if ! confirm_action true "检测到高风险 Git 操作: git ${git_args[*]}，是否继续 / High-risk Git operation detected: git ${git_args[*]}, continue?"; then
            echo_bi "$YELLOW" "已取消执行" "Cancelled"
            return 1
        fi
    fi

    local repos_array=()
    while IFS= read -r line; do
        repos_array+=("$line")
    done < <(get_selected_repositories)

    if [[ -z "${repos_array[*]-}" ]]; then
        echo_bi "$BOLD_RED" "错误: 没有匹配到任何仓库" "Error: no repositories matched"
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
        echo_bi "$BOLD_BLUE" "执行命令: git ${git_args[*]}" "Running: git ${git_args[*]}"
        echo_bi "$BOLD_BLUE" "仓库数量: ${total}" "Repository count: ${total}"
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
                echo -e "${YELLOW}  ⏭  跳过: 路径不存在 ${path} / Skipped: path not found ${path}${NC}"
                echo ""
            fi
            ((skipped_count++))
            skipped_repos+=("$name")
            json_add_result "$name" "skipped" "$path" "路径不存在 / Path not found"
            continue
        fi

        if ! is_git_repository_path "$repo_path"; then
            if ! is_json_output; then
                echo -e "${BOLD_BLUE}[${index}/${total}] ${name}${NC}"
                echo -e "${YELLOW}  ⏭  跳过: 不是 Git 仓库 ${path} / Skipped: not a Git repository ${path}${NC}"
                echo ""
            fi
            ((skipped_count++))
            skipped_repos+=("$name")
            json_add_result "$name" "skipped" "$path" "不是 Git 仓库 / Not a Git repository"
            continue
        fi

        if [[ "${git_args[0]}" == "commit" ]]; then
            if ! check_repo_has_changes "$repo_info" "commit" "${git_args[@]}"; then
                if ! is_json_output; then
                    echo -e "${BOLD_BLUE}[${index}/${total}] ${name}${NC}"
                    echo -e "${YELLOW}  ⏭  跳过: 没有需要提交的修改 / Skipped: nothing to commit${NC}"
                    echo ""
                fi
                ((skipped_count++))
                skipped_repos+=("$name")
                json_add_result "$name" "skipped" "$path" "没有需要提交的修改 / Nothing to commit"
                continue
            fi
        elif [[ "${git_args[0]}" == "diff" ]]; then
            local diff_probe_exit=0
            (cd "$repo_path" && git diff --quiet "${git_args[@]:1}" 2>/dev/null)
            diff_probe_exit=$?

            if [[ $diff_probe_exit -eq 0 ]]; then
                if ! is_json_output; then
                    echo -e "${BOLD_BLUE}[${index}/${total}] ${name}${NC}"
                    echo -e "${YELLOW}  ⏭  没有变化 / No changes${NC}"
                    echo ""
                fi
                ((skipped_count++))
                skipped_repos+=("$name")
                json_add_result "$name" "skipped" "$path" "没有变化 / No changes"
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
                echo -e "${YELLOW}  ⏭  dry-run: 未实际执行 / dry-run: not actually executed${NC}"
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

        local streamed=false
        if [[ "$status_clean" == "true" ]]; then
            output="没有变化"
            exit_code=0
        elif is_long_running_git_command "${git_args[@]}" && ! is_json_output; then
            # 长耗时网络命令: 实时流式输出，避免用户误判"卡死"
            echo -e "${BOLD_BLUE}[${index}/${total}] ${name}${NC}"
            echo -e "${YELLOW}  ⏳ 网络命令执行中（请耐心等待，不要中断）... / Network command running (please wait, do not interrupt)...${NC}"
            local _tmp_out
            _tmp_out=$(mktemp -t mt_git_out.XXXXXX 2>/dev/null) || _tmp_out="/tmp/mt_git_out.$$"
            # 用 tee 同时实时显示给用户 + 落盘以便后续 JSON / 失败回放
            set +o pipefail 2>/dev/null || true
            execute_git_command "$repo_info" "${git_args[@]}" 2>&1 \
                | awk '{ print "    " $0; fflush() }' \
                | tee "$_tmp_out"
            exit_code=${PIPESTATUS[0]:-0}
            # 因为已用 tee 实时显示，重新读 output 仅用于 JSON / 后续摘要
            output=$(cat "$_tmp_out" 2>/dev/null || echo "")
            rm -f "$_tmp_out" 2>/dev/null || true
            streamed=true
        else
            output=$(execute_git_command "$repo_info" "${git_args[@]}" 2>&1) || exit_code=$?
        fi

        if [[ ${exit_code:-0} -eq 0 ]]; then
            ((success_count++))
            json_add_result "$name" "success" "$path" "${output:-执行成功 / Succeeded}"
            if ! is_json_output; then
                if [[ "$streamed" == "true" ]]; then
                    # 流式分支已实时打印 output，只补一个成功摘要行
                    echo -e "${BOLD_GREEN}  ${CHECK_MARK} 执行成功 / Succeeded${NC}"
                    echo ""
                else
                    format_output "$index" "$total" "$name" "0" "$output" "${git_args[@]}"
                fi
            fi
        else
            failed_repos+=("$name")
            json_add_result "$name" "failed" "$path" "${output:-执行失败 / Failed}"
            if ! is_json_output; then
                if [[ "$streamed" == "true" ]]; then
                    echo -e "${BOLD_RED}  ${CROSS_MARK} 执行失败 / Failed${NC}"
                    echo ""
                else
                    format_output "$index" "$total" "$name" "1" "$output" "${git_args[@]}"
                fi
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
            json_print_results "${git_args[0]}" "false" "部分仓库执行失败 / Some repositories failed"
            return 1
        fi
        if [[ $planned_count -gt 0 ]]; then
            json_print_results "${git_args[0]}" "true" "dry-run 计划已生成 / dry-run plan generated"
            return 0
        fi
        json_print_results "${git_args[0]}" "true" "执行完成 / Completed"
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
            echo -e "${BOLD_GREEN}${CHECK_MARK} 所有需要处理的仓库执行成功 (${success_count}/${processed_count}) / All processed repositories succeeded (${success_count}/${processed_count})${NC}"
            echo -e "${YELLOW}  跳过仓库 / Skipped (${skipped_count}): ${skipped_repos[*]}${NC}"
        else
            echo -e "${BOLD_GREEN}${CHECK_MARK} 所有仓库执行成功 (${success_count}/${actual_total}) / All repositories succeeded (${success_count}/${actual_total})${NC}"
        fi
        return 0
    elif [[ $failed_count -gt 0 ]]; then
        echo -e "${BOLD_RED}${CROSS_MARK} 部分仓库执行失败 (成功: ${success_count}, 失败: ${failed_count}, 计划: ${planned_count}, 跳过: ${skipped_count}) / Some repositories failed (success: ${success_count}, failed: ${failed_count}, planned: ${planned_count}, skipped: ${skipped_count})${NC}"
        if [[ $failed_count -gt 0 ]]; then
            echo -e "${BOLD_RED}失败仓库 / Failed repositories: ${failed_repos[*]}${NC}"
        fi
        if [[ $planned_count -gt 0 ]]; then
            echo -e "${CYAN}计划执行仓库 / Planned repositories: ${planned_repos[*]}${NC}"
        fi
        if [[ $skipped_count -gt 0 ]]; then
            echo -e "${YELLOW}跳过仓库 / Skipped repositories: ${skipped_repos[*]}${NC}"
        fi
        return 1
    elif [[ $planned_count -gt 0 ]]; then
        echo -e "${CYAN}⏭  dry-run: 已为 ${planned_count} 个仓库生成执行计划 / dry-run: generated a plan for ${planned_count} repository(ies)${NC}"
        if [[ $planned_count -gt 0 ]]; then
            echo -e "${CYAN}计划执行仓库 / Planned repositories: ${planned_repos[*]}${NC}"
        fi
        if [[ $skipped_count -gt 0 ]]; then
            echo -e "${YELLOW}跳过仓库 / Skipped repositories: ${skipped_repos[*]}${NC}"
        fi
        return 0
    elif [[ $skipped_count -eq $total ]]; then
        echo -e "${YELLOW}⏭  所有仓库都没有修改，已跳过 / All repositories had no changes and were skipped${NC}"
        return 0
    else
        local actual_total=$((total - skipped_count))
        echo -e "${BOLD_GREEN}${CHECK_MARK} 所有仓库执行成功 (${success_count}/${actual_total}) / All repositories succeeded (${success_count}/${actual_total})${NC}"
        return 0
    fi
}

list_repositories() {
    local repos_array=()
    while IFS= read -r line; do
        repos_array+=("$line")
    done < <(get_selected_repositories)

    if [[ -z "${repos_array[*]-}" ]]; then
        echo -e "${RED}没有匹配到任何仓库 / No repositories matched${NC}"
        return 1
    fi

    json_reset

    if ! is_json_output; then
        echo_bi "$BLUE" "仓库列表（含默认 7 仓库）:" "Repository list (includes 7 default repositories):"
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
                git_repo="${YELLOW}非Git / Non-Git${NC}"
            fi
        else
            exists="${RED}${CROSS_MARK}${NC}"
            git_repo="${RED}不存在 / Missing${NC}"
        fi

        json_add_result "$name" "listed" "$path" "$git_repo" "\"url\":\"$(json_escape "$url")\""

        if ! is_json_output; then
            printf "  %-2s %-30s %-30s %-24s %s\n" \
                "$exists" \
                "$name" \
                "$path" \
                "$git_repo" \
                "$url"
        fi
    done

    if is_json_output; then
        json_print_results "list" "true" "仓库列表 / Repository list"
    fi
}

doctor() {
    json_reset

    local error_count=0
    local warning_count=0

    local brew_bin=""
    brew_bin=$(find_brew_bin 2>/dev/null || echo "")
    if [[ -n "$brew_bin" ]]; then
        json_add_result "Homebrew" "success" "$brew_bin" "已安装 / Installed"
    else
        json_add_result "Homebrew" "failed" "" "未安装 / Not installed"
        ((error_count++))
    fi

    local fvm_bin=""
    fvm_bin=$(find_fvm_bin "$brew_bin" 2>/dev/null || echo "")
    if [[ -n "$fvm_bin" ]]; then
        json_add_result "FVM" "success" "$fvm_bin" "已安装 / Installed"
    else
        json_add_result "FVM" "failed" "" "未安装 / Not installed"
        ((error_count++))
    fi

    if command -v fvm >/dev/null 2>&1; then
        json_add_result "fvm 命令" "success" "$(command -v fvm)" "当前 shell 可用 / Available in the current shell"
    elif [[ -n "$fvm_bin" ]]; then
        json_add_result "fvm 命令" "warning" "$fvm_bin" "已安装，但当前 shell 未生效 / Installed, but not yet active in the current shell"
        ((warning_count++))
    else
        json_add_result "fvm 命令" "failed" "" "不可用 / Not available"
        ((error_count++))
    fi

    local flutter_installed=false
    if [[ -n "$fvm_bin" ]]; then
        if "$fvm_bin" list 2>/dev/null | grep -Fq "$FVM_FLUTTER_VERSION"; then
            flutter_installed=true
            json_add_result "Flutter" "success" "$FVM_FLUTTER_VERSION" "已通过 FVM 安装 / Installed via FVM"
        else
            json_add_result "Flutter" "failed" "$FVM_FLUTTER_VERSION" "未检测到目标版本 / Target version not detected"
            ((error_count++))
        fi
    else
        json_add_result "Flutter" "skipped" "$FVM_FLUTTER_VERSION" "FVM 不可用，跳过检测 / FVM not available, skipping check"
        ((warning_count++))
    fi

    local flutter_cmd_path=""
    if command -v flutter >/dev/null 2>&1; then
        flutter_cmd_path="$(command -v flutter)"
        json_add_result "flutter 命令" "success" "$flutter_cmd_path" "当前 shell 可用 / Available in the current shell"
    elif [[ -x "${HOME}/.local/bin/flutter" ]]; then
        json_add_result "flutter 命令" "warning" "${HOME}/.local/bin/flutter" "入口已创建，但当前 shell 未生效 / Entry created, but not yet active in the current shell"
        ((warning_count++))
    elif [[ "$flutter_installed" == true ]]; then
        json_add_result "flutter 命令" "warning" "$FVM_FLUTTER_VERSION" "已安装 Flutter，但未创建命令入口 / Flutter installed, but no command entry created"
        ((warning_count++))
    else
        json_add_result "flutter 命令" "failed" "" "不可用 / Not available"
        ((error_count++))
    fi

    if command -v dart >/dev/null 2>&1; then
        json_add_result "dart 命令" "success" "$(command -v dart)" "当前 shell 可用 / Available in the current shell"
    elif [[ -x "${HOME}/.local/bin/dart" ]]; then
        json_add_result "dart 命令" "warning" "${HOME}/.local/bin/dart" "入口已创建，但当前 shell 未生效 / Entry created, but not yet active in the current shell"
        ((warning_count++))
    elif [[ "$flutter_installed" == true ]]; then
        json_add_result "dart 命令" "warning" "$FVM_FLUTTER_VERSION" "已安装 Flutter，但未创建命令入口 / Flutter installed, but no command entry created"
        ((warning_count++))
    else
        json_add_result "dart 命令" "failed" "" "不可用 / Not available"
        ((error_count++))
    fi

    if command -v git >/dev/null 2>&1; then
        json_add_result "Git" "success" "$(command -v git)" "已安装 / Installed"
    else
        json_add_result "Git" "failed" "" "未安装 Git / Git not installed"
        ((error_count++))
    fi

    if [[ -f "${PROJECT_ROOT}/github.token" ]]; then
        json_add_result "GitHub Token" "success" "${PROJECT_ROOT}/github.token" "已配置 / Configured"
    else
        json_add_result "GitHub Token" "warning" "${PROJECT_ROOT}/github.token" "未配置 / Not configured"
        ((warning_count++))
    fi

    if workspace_contains_main_repositories "$PROJECT_ROOT" || [[ -f "${PROJECT_ROOT}/github.token" ]]; then
        json_add_result "Workspace Root" "success" "$PROJECT_ROOT" "已自动识别 / Auto-detected"
    else
        json_add_result "Workspace Root" "warning" "$PROJECT_ROOT" "未检测到默认仓库目录，按当前目录处理 / No default repository directory detected; using the current directory"
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
                json_add_result "$name" "warning" "$path" "路径不存在 / Path not found"
                ((warning_count++))
            elif ! is_git_repository_path "$repo_path"; then
                json_add_result "$name" "warning" "$path" "不是 Git 仓库 / Not a Git repository"
                ((warning_count++))
            else
                json_add_result "$name" "success" "$path" "仓库可用 / Repository available"
            fi
        done
    else
        json_add_result "Workspace" "warning" "$PROJECT_ROOT" "未检测到默认仓库目录，跳过仓库状态检查 / No default repository directory detected, skipping repository status check"
        ((warning_count++))
    fi

    if is_json_output; then
        if [[ $error_count -gt 0 ]]; then
            json_print_results "doctor" "false" "检测完成，存在 ${error_count} 个错误和 ${warning_count} 个警告 / Check complete: ${error_count} error(s), ${warning_count} warning(s)"
            return 1
        fi
        json_print_results "doctor" "true" "检测完成，存在 ${warning_count} 个警告 / Check complete: ${warning_count} warning(s)"
        return 0
    fi

    echo -e "${BLUE}========================================${NC}"
    echo_bi "$BLUE" "  环境检查" "  Environment check"
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
        echo -e "${BOLD_RED}${CROSS_MARK} 检查完成：${error_count} 个错误，${warning_count} 个警告 / Check complete: ${error_count} error(s), ${warning_count} warning(s)${NC}"
        return 1
    fi
    echo -e "${BOLD_GREEN}${CHECK_MARK} 检查完成：0 个错误，${warning_count} 个警告 / Check complete: 0 errors, ${warning_count} warning(s)${NC}"
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
        echo_bi "$BOLD_YELLOW" "警告: 无法识别 shell 配置文件，跳过环境变量写入" "Warning: could not identify the shell config file; skipping environment setup"
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

    echo -e "${GREEN}${CHECK_MARK} 已写入 shell 环境 / Shell environment updated: ${config_file}${NC}"
    echo -e "${GREEN}${CHECK_MARK} 已创建命令入口 / Command entries created: ${local_bin_dir}/fvm, flutter, dart${NC}"
    echo_bi "$YELLOW" "请执行以下命令使当前终端生效:" "Run the following command to apply this in the current terminal:"
    echo -e "${CYAN}  source ${config_file}${NC}"
}

clone_plaud_app() {
    local target_dir="${1:-$PLAUD_APP_DEFAULT_DIR}"

    echo -e "${BLUE}========================================${NC}"
    echo_bi "$BLUE" "  开始克隆 Plaud-App 仓库" "  Cloning the Plaud-App repository"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo_bi "$CYAN" "仓库地址: ${PLAUD_APP_REPO_URL}" "Repository: ${PLAUD_APP_REPO_URL}"
    echo_bi "$CYAN" "目标目录: ${target_dir}" "Target directory: ${target_dir}"
    echo ""

    if [[ -d "$target_dir" ]]; then
        echo_bi "$BOLD_YELLOW" "警告: 目录 ${target_dir} 已存在" "Warning: directory ${target_dir} already exists"
        echo -e "${YELLOW}是否要继续 / Continue? (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo_bi "$YELLOW" "已取消" "Cancelled"
            return 0
        fi
    fi

    echo_bi "$BLUE" "[1/3] 克隆主仓库..." "[1/3] Cloning the main repository..."
    print_command "$(pwd)" git clone "$PLAUD_APP_REPO_URL" "$target_dir"

    if ! git clone "$PLAUD_APP_REPO_URL" "$target_dir" 2>&1; then
        echo -e "${BOLD_RED}${CROSS_MARK} 克隆失败 / Clone failed${NC}"
        return 1
    fi

    echo ""
    echo -e "${GREEN}${CHECK_MARK} 主仓库克隆成功 / Main repository cloned successfully${NC}"
    echo ""

    echo_bi "$BLUE" "[2/3] 初始化子模块..." "[2/3] Initializing submodules..."
    echo -e "${CYAN}执行 / Running: git submodule update --init --recursive${NC}"
    echo ""

    local submodule_output=""
    if ! submodule_output=$(cd "$target_dir" && git submodule update --init --recursive 2>&1); then
        echo -e "${BOLD_RED}${CROSS_MARK} 子模块初始化失败 / Submodule initialization failed${NC}"
        echo_bi "$YELLOW" "输出:" "Output:"
        echo "$submodule_output" | sed 's/^/  /'
        echo ""
        echo_bi "$BOLD_YELLOW" "警告: 主仓库已克隆成功，但子模块初始化失败" "Warning: the main repository was cloned, but submodule initialization failed"
        echo -e "${YELLOW}你可以稍后手动执行 / You can run this manually later: cd ${target_dir} && git submodule update --init --recursive${NC}"
        return 1
    fi

    if [[ -n "$submodule_output" ]]; then
        echo "$submodule_output" | sed 's/^/  /'
    fi

    echo ""
    echo -e "${GREEN}${CHECK_MARK} 子模块初始化成功 / Submodules initialized successfully${NC}"
    echo ""

    echo_bi "$BLUE" "[3/3] 克隆 Android 子仓库..." "[3/3] Cloning the Android sub-repository..."
    local android_subrepo_path="${target_dir}/plaud-android/nicebuildSDK"
    local android_subrepo_url="git@github.com:Plaud-AI/ble-sdk-android.git"

    if [[ ! -d "${target_dir}/plaud-android" ]]; then
        echo_bi "$BOLD_YELLOW" "警告: plaud-android 目录不存在，跳过 Android 子仓库克隆" "Warning: plaud-android directory not found, skipping the Android sub-repository clone"
    elif [[ -d "$android_subrepo_path" ]]; then
        echo -e "${YELLOW}  ⏭  跳过: nicebuildSDK 目录已存在 / Skipped: nicebuildSDK directory already exists${NC}"
    else
        echo -e "${CYAN}执行 / Running: git clone ${android_subrepo_url} ${android_subrepo_path}${NC}"
        echo ""

        if ! (cd "${target_dir}/plaud-android" && git clone "$android_subrepo_url" "nicebuildSDK" 2>&1); then
            echo_bi "$BOLD_YELLOW" "警告: Android 子仓库克隆失败" "Warning: the Android sub-repository clone failed"
            echo -e "${YELLOW}你可以稍后手动执行 / You can run this manually later: cd ${target_dir}/plaud-android && git clone ${android_subrepo_url} nicebuildSDK${NC}"
        else
            echo ""
            echo -e "${GREEN}${CHECK_MARK} Android 子仓库克隆成功 / Android sub-repository cloned successfully${NC}"
        fi
    fi

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}${CHECK_MARK} Plaud-App 仓库克隆完成 / Plaud-App repository clone complete${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo_bi "$CYAN" "下一步:" "Next steps:"
    echo -e "${CYAN}  cd ${target_dir}${NC}"
    echo -e "${CYAN}  mt list${NC}"

    return 0
}

bootstrap_environment_and_clone() {
    local target_dir="${1:-$PLAUD_APP_DEFAULT_DIR}"

    echo -e "${BLUE}========================================${NC}"
    echo_bi "$BLUE" "  初始化开发环境" "  Setting up the development environment"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    echo_bi "$BLUE" "[1/3] 检查 Homebrew..." "[1/3] Checking Homebrew..."
    local brew_bin=""
    brew_bin=$(find_brew_bin 2>/dev/null || echo "")
    if [[ -z "$brew_bin" ]]; then
        echo -e "${BOLD_RED}${CROSS_MARK} 未检测到 Homebrew / Homebrew not detected${NC}"
        echo_bi "$YELLOW" "请先安装 Homebrew，安装完成后重新执行 mt init" "Please install Homebrew first, then re-run mt init"
        echo -e "${CYAN}官网 / Website: https://brew.sh${NC}"
        echo_bi "$CYAN" "安装命令:" "Install command:"
        echo -e "${CYAN}  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
        return 1
    fi
    echo -e "${GREEN}${CHECK_MARK} Homebrew 已安装 / Homebrew is installed: ${brew_bin}${NC}"
    echo ""

    echo_bi "$BLUE" "[2/3] 检查 FVM 并安装 Flutter ${FVM_FLUTTER_VERSION}..." "[2/3] Checking FVM and installing Flutter ${FVM_FLUTTER_VERSION}..."
    local fvm_bin=""
    fvm_bin=$(find_fvm_bin "$brew_bin" 2>/dev/null || echo "")
    if [[ -z "$fvm_bin" ]]; then
        echo_bi "$YELLOW" "未检测到 FVM，正在通过 Homebrew 安装..." "FVM not detected, installing via Homebrew..."
        print_command "$(pwd)" "$brew_bin" tap "$FVM_BREW_TAP"
        if ! "$brew_bin" tap "$FVM_BREW_TAP" 2>&1; then
            echo -e "${BOLD_RED}${CROSS_MARK} Homebrew tap 失败 / Homebrew tap failed${NC}"
            return 1
        fi

        print_command "$(pwd)" "$brew_bin" install fvm
        if ! "$brew_bin" install fvm 2>&1; then
            echo -e "${BOLD_RED}${CROSS_MARK} FVM 安装失败 / FVM installation failed${NC}"
            return 1
        fi

        fvm_bin=$(find_fvm_bin "$brew_bin" 2>/dev/null || echo "")
        if [[ -z "$fvm_bin" ]]; then
            echo -e "${BOLD_RED}${CROSS_MARK} FVM 已安装，但当前终端无法找到 fvm 命令 / FVM installed, but the fvm command was not found in this terminal${NC}"
            echo_bi "$YELLOW" "请确认 Homebrew 的 bin 目录已加入 PATH 后重试" "Please confirm Homebrew's bin directory is on PATH and retry"
            return 1
        fi
        echo -e "${GREEN}${CHECK_MARK} FVM 安装成功 / FVM installed successfully: ${fvm_bin}${NC}"
    else
        echo -e "${GREEN}${CHECK_MARK} FVM 已安装 / FVM is installed: ${fvm_bin}${NC}"
    fi

    ensure_shell_env_for_fvm "$brew_bin" "$fvm_bin"

    print_command "$(pwd)" "$fvm_bin" install "$FVM_FLUTTER_VERSION"
    if ! "$fvm_bin" install "$FVM_FLUTTER_VERSION" 2>&1; then
        echo -e "${BOLD_RED}${CROSS_MARK} Flutter ${FVM_FLUTTER_VERSION} 安装失败 / Flutter ${FVM_FLUTTER_VERSION} installation failed${NC}"
        return 1
    fi

    print_command "$(pwd)" "$fvm_bin" global "$FVM_FLUTTER_VERSION"
    if ! "$fvm_bin" global "$FVM_FLUTTER_VERSION" 2>&1; then
        echo -e "${BOLD_RED}${CROSS_MARK} Flutter ${FVM_FLUTTER_VERSION} 全局配置失败 / Flutter ${FVM_FLUTTER_VERSION} global config failed${NC}"
        return 1
    fi

    if ! "${HOME}/.local/bin/flutter" --version >/dev/null 2>&1; then
        echo -e "${BOLD_RED}${CROSS_MARK} flutter 命令验证失败 / flutter command verification failed${NC}"
        echo_bi "$YELLOW" "请执行 source 你的 shell 配置后重试" "Please source your shell config and retry"
        return 1
    fi

    if ! "${HOME}/.local/bin/dart" --version >/dev/null 2>&1; then
        echo -e "${BOLD_RED}${CROSS_MARK} dart 命令验证失败 / dart command verification failed${NC}"
        echo_bi "$YELLOW" "请执行 source 你的 shell 配置后重试" "Please source your shell config and retry"
        return 1
    fi

    echo -e "${GREEN}${CHECK_MARK} Flutter ${FVM_FLUTTER_VERSION} 已准备完成 / Flutter ${FVM_FLUTTER_VERSION} is ready${NC}"
    echo ""

    echo_bi "$BLUE" "[3/3] 执行 mt clone..." "[3/3] Running mt clone..."
    local clone_exit_code=0
    capture_command_exit clone_exit_code clone_plaud_app "$target_dir"
    if [[ $clone_exit_code -ne 0 ]]; then
        print_composite_failure "init 命令" "init command" "clone 步骤失败" "clone step failed"
        return "$clone_exit_code"
    fi

    print_composite_success "init 命令" "init command"
    return 0
}

set_github_token() {
    local token="$1"

    if [[ -z "$token" ]]; then
        echo_bi "$BOLD_RED" "错误: 请提供 GitHub token" "Error: please provide a GitHub token"
        echo_bi "$YELLOW" "用法: mt set-github-token <your_token>" "Usage: mt set-github-token <your_token>"
        echo_bi "$CYAN" "获取 token: https://github.com/settings/tokens" "Get a token: https://github.com/settings/tokens"
        return 1
    fi

    local token_file="${PROJECT_ROOT}/github.token"
    echo "$token" > "$token_file"
    chmod 600 "$token_file"

    echo -e "${GREEN}${CHECK_MARK} GitHub token 已保存 / GitHub token saved${NC}"
    echo -e "${CYAN}Token 已保存到 / Token saved to: ${token_file}${NC}"
    echo -e "${YELLOW}提示: github.token 文件已添加到 .gitignore，不会被提交到 Git / Tip: github.token is already in .gitignore and will not be committed${NC}"

    return 0
}

upgrade_mt() {
    echo -e "${BLUE}========================================${NC}"
    echo_bi "$BLUE" "  升级 MT 工具" "  Upgrading the MT tool"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local mt_repo_dir
    mt_repo_dir="$(get_mt_dir)"

    if [[ ! -d "${mt_repo_dir}/.git" ]] && [[ ! -f "${mt_repo_dir}/.git" ]]; then
        echo_bi "$BOLD_RED" "错误: 无法找到 mt Git 仓库" "Error: could not find the mt Git repository"
        echo -e "${YELLOW}当前脚本路径 / Current script path: ${BASH_SOURCE[0]:-$0}${NC}"
        echo -e "${YELLOW}计算的 mt 目录 / Resolved mt directory: ${mt_repo_dir}${NC}"
        echo_bi "$YELLOW" "请确保 mt 工具是从 Git 仓库安装的" "Please make sure mt was installed from a Git repository"
        return 1
    fi

    local current_branch
    current_branch=$(cd "$MT_DIR" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [[ -z "$current_branch" ]]; then
        echo_bi "$BOLD_RED" "错误: 无法获取当前分支" "Error: could not resolve the current branch"
        return 1
    fi

    echo -e "${CYAN}当前分支 / Current branch: ${current_branch}${NC}"
    echo -e "${CYAN}mt 仓库目录 / mt repository directory: ${mt_repo_dir}${NC}"
    echo ""

    echo_bi "$BLUE" "[1/3] 获取远程更新..." "[1/3] Fetching remote updates..."
    print_command "$mt_repo_dir" git fetch origin

    (cd "$mt_repo_dir" && git fetch origin 2>&1) || {
        echo_bi "$BOLD_RED" "错误: 获取远程更新失败" "Error: failed to fetch remote updates"
        return 1
    }
    echo -e "${GREEN}${CHECK_MARK} 远程更新获取成功 / Fetched remote updates successfully${NC}"
    echo ""

    local target_branch="${current_branch:-main}"
    local local_commit
    local remote_commit
    local_commit=$(cd "$mt_repo_dir" && git rev-parse HEAD 2>/dev/null)
    remote_commit=$(cd "$mt_repo_dir" && git rev-parse "origin/${target_branch}" 2>/dev/null)

    if [[ "$local_commit" == "$remote_commit" ]]; then
        echo -e "${GREEN}${CHECK_MARK} 已是最新版本 / Already up to date${NC}"
        echo -e "${BLUE}========================================${NC}"
        return 0
    fi

    echo_bi "$BLUE" "[2/3] 检查更新..." "[2/3] Checking for updates..."
    local commit_count
    commit_count=$(cd "$mt_repo_dir" && git rev-list --count HEAD.."origin/${target_branch}" 2>/dev/null || echo "0")

    if [[ "$commit_count" -gt 0 ]]; then
        echo -e "${CYAN}发现 ${commit_count} 个新提交 / Found ${commit_count} new commit(s)${NC}"
        echo ""
        echo_bi "$CYAN" "最近的更新:" "Recent updates:"
        (cd "$mt_repo_dir" && git log --oneline HEAD.."origin/${target_branch}" | head -5)
        echo ""
    fi

    read -p "是否执行更新 / Proceed with update? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_bi "$BLUE" "取消更新" "Update cancelled"
        return 0
    fi

    echo_bi "$BLUE" "[3/3] 执行更新..." "[3/3] Applying update..."
    print_command "$mt_repo_dir" git pull origin "${target_branch}"

    (cd "$mt_repo_dir" && git pull origin "${target_branch}" 2>&1) || {
        echo_bi "$BOLD_RED" "错误: 更新失败" "Error: update failed"
        echo -e "${YELLOW}请手动执行 / Please run manually: cd ${mt_repo_dir} && git pull origin ${target_branch}${NC}"
        return 1
    }

    echo ""
    echo -e "${BOLD_GREEN}${CHECK_MARK} 更新成功！/ Update succeeded!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo_bi "$CYAN" "当前版本:" "Current version:"
    (cd "$mt_repo_dir" && git log --oneline -1)
    echo ""
    echo -e "${YELLOW}提示: 如果 mt 命令已安装，可能需要重新安装以使用新版本 / Tip: if mt is installed system-wide, you may need to reinstall to use the new version${NC}"
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
                echo_bi "$BOLD_RED" "错误: 未知参数: $1" "Error: unknown argument: $1"
                echo_bi "$YELLOW" "用法: mt delete [-a|--all]" "Usage: mt delete [-a|--all]"
                return 1
                ;;
        esac
    done

    if ! confirm_action true "delete 命令会批量删除分支，是否继续 / delete will bulk-remove branches, continue?"; then
        echo_bi "$YELLOW" "已取消删除" "Delete cancelled"
        return 1
    fi

    local repos_array=()
    while IFS= read -r line; do
        repos_array+=("$line")
    done < <(get_selected_repositories)

    if [[ -z "${repos_array[*]-}" ]]; then
        echo_bi "$BOLD_RED" "错误: 没有匹配到任何仓库" "Error: no repositories matched"
        return 1
    fi

    json_reset

    if ! is_json_output; then
        echo -e "${BLUE}========================================${NC}"
        echo_bi "$BLUE" "  删除本地分支" "  Deleting local branches"
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
                echo -e "${YELLOW}  ⏭  跳过: 路径不存在 ${path} / Skipped: path not found ${path}${NC}"
                echo ""
            fi
            ((skipped_count++))
            json_add_result "$name" "skipped" "$path" "路径不存在 / Path not found"
            continue
        fi

        if [[ ! -d "${repo_path}/.git" ]] && [[ ! -f "${repo_path}/.git" ]]; then
            if ! is_json_output; then
                echo -e "${YELLOW}  ⏭  跳过: 不是 Git 仓库 ${path} / Skipped: not a Git repository ${path}${NC}"
                echo ""
            fi
            ((skipped_count++))
            json_add_result "$name" "skipped" "$path" "不是 Git 仓库 / Not a Git repository"
            continue
        fi

        local current_branch
        current_branch=$(cd "$repo_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [[ -z "$current_branch" ]]; then
            if ! is_json_output; then
                echo -e "${YELLOW}  ⏭  跳过: 无法获取当前分支 / Skipped: could not resolve the current branch${NC}"
                echo ""
            fi
            ((skipped_count++))
            json_add_result "$name" "skipped" "$path" "无法获取当前分支 / Could not resolve current branch"
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
                echo -e "${YELLOW}  ⏭  跳过: 没有可删除的分支 / Skipped: no deletable branches${NC}"
                echo ""
            fi
            ((skipped_count++))
            json_add_result "$name" "skipped" "$path" "没有可删除的分支 / No deletable branches"
            continue
        fi

        if [[ "$delete_all" == true ]]; then
            if ! is_json_output; then
                echo -e "${CYAN}  当前分支 / Current branch: ${current_branch}${NC}"
                echo -e "${CYAN}  将删除 ${branch_count} 个分支 / Will delete ${branch_count} branch(es)${NC}"
                echo ""
            fi

            local deleted_count=0
            local failed_count=0

            for branch in "${branches[@]}"; do
                if [[ "$GLOBAL_DRY_RUN" == "true" ]]; then
                    if ! is_json_output; then
                        echo -e "${CYAN}    dry-run: 将删除分支 ${branch} / dry-run: would delete branch ${branch}${NC}"
                    fi
                    ((deleted_count++))
                else
                    if ! is_json_output; then
                        echo -e "${CYAN}    删除分支 / Deleting branch: ${branch}${NC}"
                    fi
                    if (cd "$repo_path" && git branch -D "$branch" 2>&1); then
                        if ! is_json_output; then
                            echo -e "${BOLD_GREEN}      ${CHECK_MARK} 删除成功 / Deleted successfully${NC}"
                        fi
                        ((deleted_count++))
                    else
                        if ! is_json_output; then
                            echo -e "${BOLD_RED}      ${CROSS_MARK} 删除失败 / Delete failed${NC}"
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
                    echo -e "${BOLD_GREEN}  ${CHECK_MARK} 成功删除 ${deleted_count} 个分支 / Deleted ${deleted_count} branch(es) successfully${NC}"
                fi
                ((success_count++))
                json_add_result "$name" "$([[ "$GLOBAL_DRY_RUN" == "true" ]] && echo "planned" || echo "success")" "$path" "处理 ${deleted_count} 个分支 / Processed ${deleted_count} branch(es)"
            fi
            if [[ $failed_count -gt 0 ]]; then
                if ! is_json_output; then
                    echo -e "${BOLD_RED}  ${CROSS_MARK} 删除失败 ${failed_count} 个分支 / Failed to delete ${failed_count} branch(es)${NC}"
                fi
                ((failure_count += failed_count))
                json_add_result "$name" "failed" "$path" "删除失败 ${failed_count} 个分支 / Failed to delete ${failed_count} branch(es)"
                if [[ "$GLOBAL_FAIL_FAST" == "true" ]]; then
                    break
                fi
            fi
        else
            if [[ $branch_count -lt 8 ]]; then
                if ! is_json_output; then
                    echo -e "${YELLOW}  ⏭  跳过: 分支数量 (${branch_count}) 小于 8，不执行删除 / Skipped: branch count (${branch_count}) is under 8, nothing to delete${NC}"
                    echo -e "${CYAN}    提示: 使用 -a 参数可以删除所有分支（除了当前分支和 main/master）/ Tip: use -a to delete all branches (except the current branch and main/master)${NC}"
                    echo ""
                fi
                ((skipped_count++))
                json_add_result "$name" "skipped" "$path" "分支数量不足 8 / Fewer than 8 branches"
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
                echo -e "${CYAN}  当前分支 / Current branch: ${current_branch}${NC}"
                echo -e "${CYAN}  分支总数 / Total branches: ${branch_count}${NC}"
                echo_bi "$CYAN" "  将删除最旧的 3 个分支:" "  Will delete the 3 oldest branches:"
                for branch in "${branches_to_delete[@]}"; do
                    local last_commit_date
                    last_commit_date=$(cd "$repo_path" && git log -1 --format="%ci" "$branch" 2>/dev/null || echo "未知 / Unknown")
                    echo -e "${CYAN}    - ${branch} (最后提交 / last commit: ${last_commit_date})${NC}"
                done
                echo ""
            fi

            local deleted_count=0
            local failed_count=0

            for branch in "${branches_to_delete[@]}"; do
                if [[ "$GLOBAL_DRY_RUN" == "true" ]]; then
                    if ! is_json_output; then
                        echo -e "${CYAN}    dry-run: 将删除分支 ${branch} / dry-run: would delete branch ${branch}${NC}"
                    fi
                    ((deleted_count++))
                else
                    if ! is_json_output; then
                        echo -e "${CYAN}    删除分支 / Deleting branch: ${branch}${NC}"
                    fi
                    if (cd "$repo_path" && git branch -D "$branch" 2>&1); then
                        if ! is_json_output; then
                            echo -e "${BOLD_GREEN}      ${CHECK_MARK} 删除成功 / Deleted successfully${NC}"
                        fi
                        ((deleted_count++))
                    else
                        if ! is_json_output; then
                            echo -e "${BOLD_RED}      ${CROSS_MARK} 删除失败 / Delete failed${NC}"
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
                    echo -e "${BOLD_GREEN}  ${CHECK_MARK} 成功删除 ${deleted_count} 个分支 / Deleted ${deleted_count} branch(es) successfully${NC}"
                fi
                ((success_count++))
                json_add_result "$name" "$([[ "$GLOBAL_DRY_RUN" == "true" ]] && echo "planned" || echo "success")" "$path" "处理 ${deleted_count} 个分支 / Processed ${deleted_count} branch(es)"
            fi
            if [[ $failed_count -gt 0 ]]; then
                if ! is_json_output; then
                    echo -e "${BOLD_RED}  ${CROSS_MARK} 删除失败 ${failed_count} 个分支 / Failed to delete ${failed_count} branch(es)${NC}"
                fi
                ((failure_count += failed_count))
                json_add_result "$name" "failed" "$path" "删除失败 ${failed_count} 个分支 / Failed to delete ${failed_count} branch(es)"
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
            json_print_results "delete" "false" "删除分支执行完成，存在失败项 / Delete complete, some failures"
            return 1
        fi
        json_print_results "delete" "true" "删除分支执行完成 / Delete complete"
        return 0
    fi

    echo -e "${BLUE}========================================${NC}"
    if [[ $success_count -gt 0 ]]; then
        echo -e "${GREEN}${CHECK_MARK} 成功处理 ${success_count} 个仓库 / Processed ${success_count} repository(ies) successfully${NC}"
    fi
    if [[ $skipped_count -gt 0 ]]; then
        echo -e "${YELLOW}⏭  跳过 ${skipped_count} 个仓库 / Skipped ${skipped_count} repository(ies)${NC}"
    fi
    if [[ $failure_count -gt 0 ]]; then
        echo -e "${BOLD_RED}${CROSS_MARK} 删除失败 ${failure_count} 个分支 / Failed to delete ${failure_count} branch(es)${NC}"
        echo -e "${BLUE}========================================${NC}"
        return 1
    fi
    echo -e "${BLUE}========================================${NC}"

    return 0
}

show_help() {
    cat << EOF
MT - Multi-repo Tool v${VERSION}
多仓库 Git 管理工具 / Multi-repo Git management tool

用法 / Usage:
  mt [全局选项] <git-command> [git-options]
  mt [global options] <git-command> [git-options]
  mt [全局选项] [工具命令]
  mt [global options] [tool command]

全局选项 / Global options:
  --current                    只作用于当前所在仓库
                                Act only on the current repository
  --all                        作用于匹配范围内的所有仓库（默认）
                                Act on all matched repositories (default)
  --main-only                  只作用于主仓库
                                Act only on main repositories
  --subrepos-only              只作用于子仓库
                                Act only on sub-repositories
  --only <repo>                只作用于指定仓库名或路径，可重复传入
                                Act only on the given repo name/path; repeatable
  --exclude <repo>             排除指定仓库名或路径，可重复传入
                                Exclude the given repo name/path; repeatable
  --dry-run                    只打印将执行的操作，不实际执行
                                Print the planned operation without executing it
  --json                       以 JSON 输出结果（当前支持 list/doctor/大多数多仓库 Git 命令/delete）
                                Output results as JSON (supported by list/doctor/most multi-repo Git commands/delete)
  --fail-fast                  遇到第一个失败立即停止
                                Stop at the first failure
  --continue-on-error          失败后继续执行其他仓库（默认）
                                Continue on other repositories after a failure (default)
  --confirm                    强制要求确认后再执行
                                Always require confirmation before executing
  --no-confirm                 跳过高风险命令确认
                                Skip confirmation for high-risk commands

Git 命令示例 / Git command examples:
  mt --current checkout -b <branch>  只在当前仓库创建并切换分支 / create and switch branch in the current repo only
  mt checkout -b <branch>     创建并切换分支（所有仓库）/ create and switch branch (all repos)
  mt checkout <branch>         切换分支（所有仓库）/ switch branch (all repos)
  mt commit -m "<message>"     提交代码（自动跳过没有暂存修改的仓库）/ commit (auto-skips repos with nothing staged)
  mt add <files>               添加文件 / add files
  mt push [remote] [branch]    推送代码（自动跳过没有代码变更的仓库）/ push (auto-skips repos with no changes)
    说明: 基于基线分支判断是否需要推送；如果分支相对切出的基线分支没有新增提交，则跳过
    Note: decides whether to push based on the base branch; skipped if there are no new commits relative to it
  mt pull [remote] [branch]    拉取代码 / pull
  mt status                    查看状态（所有仓库）/ show status (all repos)
  mt branch                    查看分支（所有仓库）/ show branches (all repos)
  mt diff                      查看差异（自动跳过没有变化的仓库）/ show diff (auto-skips repos with no changes)
  mt fetch                     获取更新 / fetch updates
  mt merge <branch>            合并分支（所有仓库）/ merge branch (all repos)
  mt rebase <branch>           变基（所有仓库）/ rebase (all repos)
  mt submodule [options]       子模块操作（所有仓库）/ submodule operations (all repos)
    示例 / Example: mt submodule update --init --recursive

Git 命令缩写支持 / Git command aliases:
  基础命令 / Basic commands:
    mt co <branch>               checkout 的缩写 / alias for checkout
    mt cob <branch>              checkout -b 的缩写（创建并切换分支）/ alias for checkout -b (create and switch branch)
    mt br                         branch 的缩写 / alias for branch
    mt bra                        branch -a 的缩写（显示所有分支）/ alias for branch -a (show all branches)
    mt ci [options]               commit 的缩写（也可用 cm）/ alias for commit (cm also works)
    mt cim "<message>"            commit -m 的缩写 / alias for commit -m
    mt ciam "<message>"           commit -am 的缩写 / alias for commit -am
    mt cane                       commit --amend --no-edit 的缩写 / alias for commit --amend --no-edit
    mt st                         status 的缩写 / alias for status
    mt ps [remote] [branch]       push 的缩写（也可用 ph）/ alias for push (ph also works)
    mt phf [remote] [branch]      push -f 的缩写 / alias for push -f
    mt pl [remote] [branch]       pull 的缩写 / alias for pull
    mt plro [branch]              pull --rebase origin 的缩写 / alias for pull --rebase origin
    mt m <branch>                 merge 的缩写 / alias for merge
    mt rb <branch>                rebase 的缩写 / alias for rebase
    mt rbi <branch>               rebase -i 的缩写（交互式变基）/ alias for rebase -i (interactive rebase)
    mt rba                        rebase --abort 的缩写 / alias for rebase --abort
    mt rbc                        rebase --continue 的缩写 / alias for rebase --continue
    mt sa                          stash 的缩写 / alias for stash
    mt shs [message]              stash save 的缩写 / alias for stash save
    mt sha [stash]                stash apply 的缩写 / alias for stash apply
    mt shp [stash]                stash pop 的缩写 / alias for stash pop
    mt shd [stash]                stash drop 的缩写 / alias for stash drop
    mt sw <branch>                switch 的缩写 / alias for switch
    mt cp <commit>                cherry-pick 的缩写 / alias for cherry-pick
    mt cpa                        cherry-pick --abort 的缩写 / alias for cherry-pick --abort
    mt cpc                        cherry-pick --continue 的缩写 / alias for cherry-pick --continue
    mt fe                          fetch 的缩写（也可用 ft）/ alias for fetch (ft also works)
    mt di                          diff 的缩写 / alias for diff
    mt lo                          log 的缩写 / alias for log
    mt rs [options]                reset 的缩写 / alias for reset
    mt rth [commit]               reset --hard 的缩写 / alias for reset --hard
    mt rts [commit]               reset --soft 的缩写 / alias for reset --soft
    mt rv <commit>                 revert 的缩写 / alias for revert
    mt sh <commit>                 show 的缩写 / alias for show
    mt ta [options]                tag 的缩写 / alias for tag
    mt ad <files>                  add 的缩写 / alias for add

工具命令 / Tool commands:
  mt list                      列出固定支持的仓库
                                List built-in repositories
  mt doctor                    检查开发环境、工作区和仓库状态
                                Check toolchain, workspace and repository status
  mt init [目录名]             【新人入职第一步】创建项目环境，安装并配置 Flutter ${FVM_FLUTTER_VERSION}，并克隆 Plaud-App
                                [First command for new hires] Set up the project, install and configure Flutter ${FVM_FLUTTER_VERSION}, and clone Plaud-App
                                  默认目录名 / default directory name: ${PLAUD_APP_DEFAULT_DIR}
  mt config                    兼容入口：当前版本无需 .mt-config.yaml
                                Compat entry: this version no longer needs .mt-config.yaml
  mt clone [目录名]             仅克隆 Plaud-App 仓库并初始化子模块
                                Clone the Plaud-App repository and init submodules only
                                  默认目录名 / default directory name: ${PLAUD_APP_DEFAULT_DIR}
                                  会自动执行 / automatically runs: git submodule update --init --recursive
  mt set-github-token <token>  设置 GitHub token（用于创建 PR）
                                Set the GitHub token (used to create PRs)
  mt delete [-a|--all]         删除本地分支
                                Delete local branches
                                  默认 / default: 删除最近没有使用的3个分支（分支数需>=8）/ delete the 3 least-recently-used branches (needs >=8 branches)
                                  -a: 删除所有分支（除了当前分支和 main/master）/ delete all branches (except current and main/master)
  mt clean [-a|-i|-f]           清除缓存
                                Clear caches
                                  默认 / default: 清除全部（Android + iOS + Flutter）/ clear everything (Android + iOS + Flutter)
                                  -a, --android: 只清除 Android 缓存 / clear Android cache only
                                  -i, --ios: 只清除 iOS 缓存 / clear iOS cache only
                                  -f, --flutter: 只清除 Flutter 缓存 / clear Flutter cache only
  mt upgrade                    更新 mt 工具到最新版本
                                Upgrade the mt tool to the latest version
  mt help                      显示帮助信息
                                Show help information
  mt --version                 显示版本号
                                Show the version number

Plaud 工具命令 / Plaud tool commands:
  mt plaud version -c <code> [-f]    版本号转换：versionCode → 版本字符串 / Convert versionCode to a version string
  mt plaud version -s <string>       版本号转换：版本字符串 → versionCode / Convert a version string to versionCode
  mt plaud log sync <file>           分析日志中的同步操作记录 / Analyze sync operations in a log file
  mt plaud log clean <file>         清理网络日志格式 / Clean up network log formatting
  mt plaud log time-diff <file>     分析同步时间差（支持 --min-diff 过滤）/ Analyze sync time gaps (supports --min-diff filter)
  mt plaud check opus <file>        检查 Opus 文件格式 / Check an Opus file's format
  mt plaud copy <file> [count]      批量复制文件（文件名自动递增）/ Batch-copy a file (auto-incrementing filenames)
  mt plaud decrypt <file> [-o <dir>]  解密 Plaud 加密文件 / Decrypt a Plaud encrypted file

PR 命令 / PR command:
  mt pr [options]
    为所有仓库创建 GitHub Pull Request
    Create a GitHub Pull Request across repositories
    选项 / Options:
      -b, --b, --base <branch>  目标分支（默认: main）/ Target branch (default: main)
      -t, --t, --title <title> PR 标题（默认: 使用当前分支名）/ PR title (default: current branch name)
      -d, --d, --description <text> PR 描述 / PR description
      -r, --ready               创建后将 PR 设为 Ready（非 Draft）/ Mark the PR as Ready (not Draft) after creation
    注意 / Notes:
      - 需要设置 GitHub token，使用 'mt set-github-token <token>' 命令 / Requires a GitHub token set via 'mt set-github-token <token>'
      - 新建 PR 默认创建为 Draft（WIP），并自动 / New PRs default to Draft (WIP) and automatically:
        * 请求 Copilot 作为 reviewer（最佳努力）/ request Copilot as reviewer (best-effort)
        * 添加 label：MT AUTO / add the label: MT AUTO
      - 已存在的 PR 不会修改状态、reviewer 或 label / Existing PRs are not modified (status, reviewer, or label)
      - 如果 PR 已存在，会返回已存在的 PR URL / If a PR already exists, its URL is returned
      - 会自动跳过没有代码变更的仓库 / Repositories with no code changes are skipped automatically
      - 如果有未提交的修改或本地分支未推送，会提示需要先提交/推送 / If there are uncommitted changes or unpushed commits, you'll be prompted to commit/push first

构建命令 / Build commands:
  mt prebuild                              执行 Flutter 预构建（build_all.sh / pub get / 多语言等）
                                            Run Flutter prebuild (build_all.sh / pub get / i18n, etc.)
  mt build [cn|global] [options]
    构建 Android 包（默认构建 global debug）
    Build the Android package (defaults to global debug)
    选项 / Options:
      -d, --d, --debug          构建 Debug 包（默认）/ Build a Debug package (default)
      -r, --r, --release        构建 Release 包 / Build a Release package
      -p, --p, --profile        构建 Profile 包（未来支持）/ Build a Profile package (future support)
      -c, --c, --channel <name> CN 版本指定渠道（official/huawei/xiaomi/oppo/vivo/honor/yingyongbao）/ CN channel (official/huawei/xiaomi/oppo/vivo/honor/yingyongbao)
      -a, --a, --all            CN 版本构建所有渠道（仅 release）/ Build all CN channels (release only)
    说明: build 命令不会执行 clean，直接构建以加快速度（如需 clean，请先执行 mt clean）
    Note: build does not run clean; it builds directly for speed (run mt clean first if needed)

  mt install [cn|global] [options]
    执行 Android 打包并安装到设备（参数与 build 命令相同）
    Build the Android package and install it on a device (same args as build)
    选项 / Options: 与 build 命令相同 / same as the build command
    注意: 需要设备已通过 USB 连接并启用 USB 调试
    Note: requires a device connected via USB with USB debugging enabled
    说明: install 命令不会执行 clean，直接构建以加快速度
    Note: install does not run clean; it builds directly for speed

  mt install ios [cn|global] [options]
  mt install:ios [cn|global] [options]
    执行 iOS 打包并安装到真机设备
    Build the iOS package and install it on a physical device
    选项 / Options:
      -d, --d, --debug          构建 Debug 包（默认）/ Build a Debug package (default)
      -r, --r, --release        构建 Release 包 / Build a Release package
    注意: 需要设备已通过 USB 连接并信任此计算机
    Note: requires a device connected via USB that trusts this computer
    说明: 多个设备时会提示选择；install 命令不会执行 clean，直接构建以加快速度
    Note: prompts for a choice when multiple devices are connected; install does not run clean

  mt go [cn|global] [options]
    新手推荐命令：执行 prebuild + install（快速开发流程）
    Recommended for beginners: runs prebuild + install (fast dev workflow)
    选项 / Options: 与 build 命令相同 / same as the build command
    说明: 默认执行 Android Global debug；先执行 prebuild，再构建并安装到设备
    Note: defaults to Android Global debug; runs prebuild, then builds and installs

  mt rebuild [cn|global] [options]
    清理缓存并重新构建（clean + go）
    Clean caches and rebuild (clean + go)
    选项 / Options: 与 build 命令相同 / same as the build command
    说明: 先执行 clean 清理所有缓存，然后执行 go 命令（prebuild + install）
    Note: runs clean to clear all caches, then runs go (prebuild + install)
    等同于 / Equivalent to: mt clean && mt go [cn|global] [options]

  mt build:check [-d|-r]
    编译检查：同时构建 CN 和 Global 版本（用于 push 前检查，默认 debug）
    Build check: builds both CN and Global (for pre-push checks, defaults to debug)

  mt build:ios [cn|global] [options]
    构建 iOS 包（使用 xcodebuild）
    Build the iOS package (via xcodebuild)
    选项 / Options:
      -d, --d, --debug          构建 Debug 包（默认）/ Build a Debug package (default)
      -r, --r, --release        构建 Release 包 / Build a Release package
    说明: build:ios 命令不会执行 clean，直接构建以加快速度（如需 clean，请先执行 mt clean）
    Note: build:ios does not run clean; it builds directly for speed (run mt clean first if needed)

构建示例 / Build examples:
  mt prebuild                              # Flutter 预构建（pub get / 多语言等）/ Flutter prebuild (pub get / i18n, etc.)
  mt build                                 # Global debug（默认）/ Global debug (default)
  mt build -r                              # Global release
  mt build cn                              # CN 官方渠道 debug（默认）/ CN official channel debug (default)
  mt build cn -r                           # CN 官方渠道 release / CN official channel release
  mt build cn -c huawei -r                 # CN 华为渠道 release / CN Huawei channel release
  mt build cn -a -r                        # CN 所有渠道 release / all CN channels release
  mt build global                          # Global debug
  mt build global -r                       # Global release
  mt install cn                            # 打包并安装 CN debug 包（Android）/ build and install CN debug (Android)
  mt install cn -r                        # 构建并安装 CN release 包（Android）/ build and install CN release (Android)
  mt install global                        # 打包并安装 Global debug 包（Android）/ build and install Global debug (Android)
  mt install global -r                    # 构建并安装 Global release 包（Android）/ build and install Global release (Android)
  mt install ios                           # 打包并安装 iOS Global debug 包（真机）/ build and install iOS Global debug (device)
  mt install ios -r                        # 构建并安装 iOS Global release 包（真机）/ build and install iOS Global release (device)
  mt install ios cn                        # 构建并安装 iOS CN debug 包（真机）/ build and install iOS CN debug (device)
  mt install ios cn -r                     # 构建并安装 iOS CN release 包（真机）/ build and install iOS CN release (device)
  mt install:ios                           # 同上（别名）/ same as above (alias)
  mt go                                    # 新手推荐：执行 prebuild + install（Global debug，Android）/ recommended: prebuild + install (Global debug, Android)
  mt go cn                                 # 执行 prebuild + install（CN debug，Android）/ prebuild + install (CN debug, Android)
  mt go cn -r                              # 执行 prebuild + install（CN release，Android）/ prebuild + install (CN release, Android)
  mt rebuild                                # 清理缓存并重新构建（Global debug，Android）/ clean and rebuild (Global debug, Android)
  mt rebuild cn                             # 清理缓存并重新构建（CN debug，Android）/ clean and rebuild (CN debug, Android)
  mt rebuild cn -r                          # 清理缓存并重新构建（CN release，Android）/ clean and rebuild (CN release, Android)
  mt clean                                  # 清理全部缓存（Android + iOS + Flutter）/ clear all caches (Android + iOS + Flutter)
  mt clean -a                               # 只清理 Android 缓存 / clear Android cache only
  mt clean -i                               # 只清理 iOS 缓存 / clear iOS cache only
  mt clean -f                               # 只清理 Flutter 缓存 / clear Flutter cache only
  mt build:check -r                        # 同时构建 CN 和 Global release（Android）/ build both CN and Global release (Android)
  mt build:ios                             # iOS Global debug（默认）/ iOS Global debug (default)
  mt build:ios -r                          # iOS Global release
  mt build:ios cn                         # iOS CN debug
  mt build:ios cn -r                      # iOS CN release

Plaud 工具示例 / Plaud tool examples:
  mt plaud version -c 66048                     # versionCode → 版本字符串 / versionCode to version string
  mt plaud version -c 66048 -f                  # 输出完整版本（包含修订号）/ output the full version (with revision)
  mt plaud version -s 1.0.0                     # 版本字符串 → versionCode / version string to versionCode
  mt plaud log sync app.log                      # 分析同步操作日志 / analyze sync operations in the log
  mt plaud log clean network.log                 # 清理网络日志格式 / clean up network log formatting
  mt plaud log time-diff app.log                 # 分析同步时间差 / analyze sync time gaps
  mt plaud log time-diff app.log --min-diff 0.1  # 只显示时间差 >= 0.1秒的记录 / only show gaps >= 0.1s
  mt plaud check opus data.txt                   # 检查 Opus 文件格式 / check the Opus file format
  mt plaud copy file.ogg                        # 复制文件50次（默认）/ copy the file 50 times (default)
  mt plaud copy file.ogg 100                     # 复制文件100次 / copy the file 100 times
  mt plaud decrypt encrypted.plaud                  # 解密 Plaud 文件（输出到默认目录）/ decrypt a Plaud file (default output dir)
  mt plaud decrypt encrypted.plaud -o ./output      # 指定输出目录 / specify the output directory

PR 示例 / PR examples:
  mt pr                                    # 为所有仓库创建 PR（目标分支: main）/ create PRs across repositories (target: main)
  mt pr -b develop                        # 目标分支为 develop / target branch is develop
  mt pr -t "Add new feature"              # 指定 PR 标题 / set the PR title
  mt pr -t "Fix bug" -d "修复了某个问题"   # 指定标题和描述 / set title and description
  mt pr -r                                # 创建后自动设置为 Ready / mark as Ready after creation

示例 / Examples:
  mt checkout -b feature/new-feature
  mt add .
  mt commit -m "Add new feature"
  mt push origin feature/new-feature
  mt status

更多信息 / More information:
  查看 mt/doc/README.md 获取详细文档
  See mt/doc/README.md for detailed documentation
EOF
}

# mt sync: 对每个仓库做 fetch + rebase origin/<base>，可选 push
# 用法: mt sync [base_branch] [--push]
#   - 默认 base = main
#   - 当前分支 == base：跳过 rebase，跑 pull --ff-only
#   - rebase 冲突: 自动 git rebase --abort，记录失败仓库，不影响其他仓库继续
#   - --push: rebase 完成后 push --force-with-lease 到当前分支远端
sync_repositories() {
    local base_branch="main"
    local do_push=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --push)
                do_push=true; shift ;;
            -h|--help)
                echo "用法 / Usage: mt sync [base_branch] [--push]"
                echo "  base_branch  上游基线分支，默认 main / upstream base branch, default main"
                echo "  --push       rebase 后 push --force-with-lease 到当前分支远端 / push --force-with-lease to the current branch's remote after rebase"
                return 0
                ;;
            -*)
                echo_bi "$BOLD_RED" "错误: 未知参数: $1" "Error: unknown argument: $1"
                return 1
                ;;
            *)
                base_branch="$1"; shift ;;
        esac
    done

    local repos_array=()
    while IFS= read -r line; do
        repos_array+=("$line")
    done < <(get_selected_repositories)

    if [[ -z "${repos_array[*]-}" ]]; then
        echo_bi "$BOLD_RED" "错误: 没有匹配到任何仓库" "Error: no repositories matched"
        return 1
    fi

    local total=${#repos_array[@]}
    local success_count=0
    local conflict_count=0
    local skipped_count=0
    local pushed_count=0
    local conflict_repos=()
    local skipped_repos=()
    local pushed_repos=()

    echo -e "${BOLD_BLUE}mt sync: 同步上游 origin/${base_branch} / syncing upstream origin/${base_branch}${NC}"
    echo -e "${BOLD_BLUE}仓库数量 / Repository count: ${total}${NC}"
    if [[ "$do_push" == "true" ]]; then
        echo -e "${YELLOW}已启用 --push: rebase 后将 push --force-with-lease / --push enabled: will push --force-with-lease after rebase${NC}"
    fi
    echo ""

    for i in "${!repos_array[@]}"; do
        local repo_info="${repos_array[$i]}"
        IFS='|' read -r name path url <<< "$repo_info"
        local index=$((i + 1))
        local repo_path="${PROJECT_ROOT}/${path}"

        echo -e "${BOLD_BLUE}[${index}/${total}] ${name}${NC}"

        if [[ ! -d "$repo_path" ]]; then
            echo -e "${YELLOW}  ⏭  跳过: 路径不存在 / Skipped: path not found${NC}"
            echo ""
            ((skipped_count++))
            skipped_repos+=("$name")
            continue
        fi

        if ! is_git_repository_path "$repo_path"; then
            echo -e "${YELLOW}  ⏭  跳过: 不是 Git 仓库 / Skipped: not a Git repository${NC}"
            echo ""
            ((skipped_count++))
            skipped_repos+=("$name")
            continue
        fi

        # 工作区不干净就跳过（避免破坏未提交修改）
        local porcelain
        porcelain=$(cd "$repo_path" && git status --porcelain 2>/dev/null)
        if [[ -n "$porcelain" ]]; then
            echo -e "${BOLD_YELLOW}  ⏭  跳过: 工作区有未提交修改，请先 commit/stash / Skipped: uncommitted changes, please commit/stash first${NC}"
            (cd "$repo_path" && git status --short 2>&1 | head -5 | awk '{ print "      " $0 }')
            echo ""
            ((skipped_count++))
            skipped_repos+=("$name (dirty)")
            continue
        fi

        local current_branch
        current_branch=$(cd "$repo_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [[ -z "$current_branch" ]] || [[ "$current_branch" == "HEAD" ]]; then
            echo -e "${BOLD_YELLOW}  ⏭  跳过: 处于 detached HEAD / Skipped: detached HEAD${NC}"
            echo ""
            ((skipped_count++))
            skipped_repos+=("$name (detached)")
            continue
        fi

        echo -e "${CYAN}  当前分支 / Current branch: ${current_branch}${NC}"

        # 1. fetch
        echo -e "${CYAN}  → git fetch origin ${base_branch}${NC}"
        if ! (cd "$repo_path" && git fetch origin "$base_branch" 2>&1 | awk '{ print "    " $0; fflush() }'); then
            echo -e "${BOLD_RED}  ${CROSS_MARK} fetch 失败 / fetch failed${NC}"
            echo ""
            ((conflict_count++))
            conflict_repos+=("$name (fetch failed)")
            continue
        fi

        # 2. rebase 或 ff
        if [[ "$current_branch" == "$base_branch" ]]; then
            echo -e "${CYAN}  → git pull --ff-only origin ${base_branch} (当前分支 == 基线，无需 rebase / current branch == base, rebase not needed)${NC}"
            if (cd "$repo_path" && git pull --ff-only origin "$base_branch" 2>&1 | awk '{ print "    " $0; fflush() }'); then
                echo -e "${BOLD_GREEN}  ${CHECK_MARK} 同步完成 / Sync complete${NC}"
                ((success_count++))
            else
                echo -e "${BOLD_RED}  ${CROSS_MARK} ff-only 失败（本地与远端已分叉）/ ff-only failed (local and remote have diverged)${NC}"
                ((conflict_count++))
                conflict_repos+=("$name (ff failed)")
                echo ""
                continue
            fi
        else
            echo -e "${CYAN}  → git rebase origin/${base_branch}${NC}"
            local rebase_output
            rebase_output=$(cd "$repo_path" && git rebase "origin/${base_branch}" 2>&1)
            local rebase_exit=$?
            echo "$rebase_output" | awk '{ print "    " $0 }'

            if [[ $rebase_exit -ne 0 ]]; then
                echo -e "${BOLD_RED}  ${CROSS_MARK} rebase 冲突，自动 abort / rebase conflict, auto-aborted${NC}"
                (cd "$repo_path" && git rebase --abort 2>/dev/null) || true
                ((conflict_count++))
                conflict_repos+=("$name (rebase conflict)")
                echo ""
                continue
            fi
            echo -e "${BOLD_GREEN}  ${CHECK_MARK} rebase 完成 / rebase complete${NC}"
            ((success_count++))
        fi

        # 3. 可选 push
        if [[ "$do_push" == "true" ]]; then
            echo -e "${CYAN}  → git push --force-with-lease origin ${current_branch}${NC}"
            if (cd "$repo_path" && git push --force-with-lease origin "$current_branch" 2>&1 | awk '{ print "    " $0; fflush() }'); then
                echo -e "${BOLD_GREEN}  ${CHECK_MARK} push 完成 / push complete${NC}"
                ((pushed_count++))
                pushed_repos+=("$name")
            else
                echo -e "${BOLD_RED}  ${CROSS_MARK} push 失败（远端可能已被他人更新，需手动处理）/ push failed (remote may have been updated by someone else; needs manual handling)${NC}"
            fi
        fi

        echo ""
    done

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BOLD_GREEN}${CHECK_MARK} 同步成功 / Synced: ${success_count}/${total}${NC}"
    if [[ $pushed_count -gt 0 ]]; then
        echo -e "${BOLD_GREEN}${CHECK_MARK} push 成功 / Pushed: ${pushed_count}${NC}"
    fi
    if [[ $skipped_count -gt 0 ]]; then
        echo -e "${YELLOW}⏭  跳过 / Skipped: ${skipped_count} (${skipped_repos[*]})${NC}"
    fi
    if [[ $conflict_count -gt 0 ]]; then
        echo -e "${BOLD_RED}${CROSS_MARK} 冲突/失败 / Conflicts/failures: ${conflict_count} (${conflict_repos[*]})${NC}"
        echo -e "${YELLOW}请到这些仓库手动解决（rebase 已自动 abort，工作区已恢复）/ Please resolve manually in these repos (rebase auto-aborted, workspace restored)${NC}"
    fi
    echo -e "${BLUE}========================================${NC}"

    if [[ $conflict_count -gt 0 ]]; then
        return 1
    fi
    return 0
}
