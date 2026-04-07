# GitHub PR 相关函数

github_api_curl() {
    local connect_timeout="${MT_GITHUB_API_CONNECT_TIMEOUT:-10}"
    local max_time="${MT_GITHUB_API_MAX_TIME:-30}"
    curl --connect-timeout "$connect_timeout" --max-time "$max_time" "$@"
}

# 获取 GitHub token
get_github_token() {
    local token_file="${PROJECT_ROOT}/github.token"
    if [[ -f "$token_file" ]]; then
        local token
        token=$(cat "$token_file" 2>/dev/null | tr -d '\n' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$token" ]]; then
            echo "$token"
            return 0
        fi
    fi

    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        echo "$GITHUB_TOKEN"
        return 0
    fi

    return 1
}

# 从 git remote 获取仓库信息
get_repo_info() {
    local repo_path="$1"
    local remote_url

    if [[ ! -d "${repo_path}/.git" ]] && [[ ! -f "${repo_path}/.git" ]]; then
        return 1
    fi

    remote_url=$(cd "$repo_path" && git remote get-url origin 2>/dev/null || echo "")
    if [[ -z "$remote_url" ]]; then
        return 1
    fi

    if [[ "$remote_url" =~ git@github\.com:(.+)\.git$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$remote_url" =~ https://github\.com/(.+)\.git$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$remote_url" =~ https://github\.com/(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        return 1
    fi
}

# 从 GitHub API JSON 响应中提取第一个 html_url
extract_first_html_url() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import sys, json
s = sys.stdin.read()
try:
    data = json.loads(s)
except Exception:
    sys.exit(0)
def find(x):
    if isinstance(x, dict):
        v = x.get("html_url")
        if isinstance(v, str) and v:
            return v
        for vv in x.values():
            r = find(vv)
            if r:
                return r
    elif isinstance(x, list):
        for i in x:
            r = find(i)
            if r:
                return r
    return None
r = find(data)
if r:
    sys.stdout.write(r)
' 2>/dev/null
        return 0
    fi

    sed -nE 's/.*"html_url"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -n 1
}

# 从 GitHub API JSON 响应中提取 PR number
extract_pr_number() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import sys, json
s = sys.stdin.read()
try:
    data = json.loads(s)
except Exception:
    sys.exit(0)
if isinstance(data, dict):
    n = data.get("number")
    if isinstance(n, int):
        sys.stdout.write(str(n))
' 2>/dev/null
        return 0
    fi

    sed -nE 's/.*"number"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p' | head -n 1
}

# 从 PR URL 提取 PR number
extract_pr_number_from_url() {
    local pr_url="$1"
    if [[ -z "$pr_url" ]]; then
        return 1
    fi
    echo "$pr_url" | grep -oE '/pull/[0-9]+' | grep -oE '[0-9]+' | head -n 1
}

# 从 GitHub API 的 /user 响应中提取展示名（优先 name，其次 login）
extract_github_user_display() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import sys, json
s = sys.stdin.read()
try:
    data = json.loads(s)
except Exception:
    sys.exit(0)
if isinstance(data, dict):
    name = data.get("name")
    login = data.get("login")
    if isinstance(name, str) and name.strip():
        sys.stdout.write(name.strip())
    elif isinstance(login, str) and login.strip():
        sys.stdout.write(login.strip())
' 2>/dev/null
        return 0
    fi

    local name
    name=$(sed -nE 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -n 1)
    if [[ -n "$name" ]]; then
        echo "$name"
        return 0
    fi

    sed -nE 's/.*"login"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -n 1
}

# 获取当前 GitHub token 对应的作者展示名
get_github_user_display_name() {
    local github_token="$1"
    if [[ -z "$github_token" ]]; then
        return 1
    fi

    local response
    response=$(github_api_curl -s -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token ${github_token}" \
        "https://api.github.com/user" 2>/dev/null || true)

    local display
    display=$(echo "$response" | extract_github_user_display)
    if [[ -n "$display" ]]; then
        echo "$display"
        return 0
    fi

    local local_name
    local_name=$(git -C "$PROJECT_ROOT" config user.name 2>/dev/null || true)
    if [[ -n "$local_name" ]]; then
        echo "$local_name"
        return 0
    fi

    return 1
}

# 为 PR 添加 label（仅用于新建 PR）
add_label_to_pr() {
    local repo_full_name="$1"
    local pr_number="$2"
    local label_name="$3"
    local github_token="$4"

    if [[ -z "$repo_full_name" ]] || [[ -z "$pr_number" ]] || [[ -z "$label_name" ]] || [[ -z "$github_token" ]]; then
        return 1
    fi

    local api_url="https://api.github.com/repos/${repo_full_name}/issues/${pr_number}/labels"
    local json_data
    json_data=$(cat <<EOF
{
  "labels": ["${label_name}"]
}
EOF
)

    local response
    response=$(github_api_curl -s -w "\n%{http_code}" -X POST "$api_url" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token ${github_token}" \
        -H "Content-Type: application/json" \
        -d "$json_data" 2>/dev/null || true)

    local http_code
    http_code=$(echo "$response" | tail -n1)

    if [[ "$http_code" =~ ^20[0-9]$ ]]; then
        return 0
    fi

    return 1
}

# 确保 label 存在（不存在则创建）
ensure_label_exists() {
    local repo_full_name="$1"
    local label_name="$2"
    local github_token="$3"
    local label_color="${4:-1D76DB}"

    if [[ -z "$repo_full_name" ]] || [[ -z "$label_name" ]] || [[ -z "$github_token" ]]; then
        return 1
    fi

    local api_url="https://api.github.com/repos/${repo_full_name}/labels"
    local json_data
    json_data=$(cat <<EOF
{
  "name": "${label_name}",
  "color": "${label_color}",
  "description": "Created by mt pr"
}
EOF
)

    local response
    response=$(github_api_curl -s -w "\n%{http_code}" -X POST "$api_url" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token ${github_token}" \
        -H "Content-Type: application/json" \
        -d "$json_data" 2>/dev/null || true)

    local http_code
    http_code=$(echo "$response" | tail -n1)

    if [[ "$http_code" == "201" ]] || [[ "$http_code" == "422" ]]; then
        return 0
    fi

    return 1
}

# 请求 Copilot 作为 PR reviewer（仅用于新建 PR）
request_copilot_review() {
    local repo_full_name="$1"
    local pr_number="$2"
    local github_token="$3"

    if [[ -z "$repo_full_name" ]] || [[ -z "$pr_number" ]] || [[ -z "$github_token" ]]; then
        return 1
    fi

    local api_url="https://api.github.com/repos/${repo_full_name}/pulls/${pr_number}/requested_reviewers"
    local reviewer_login="${MT_COPILOT_REVIEWER:-copilot}"
    local candidates=("$reviewer_login" "github-copilot[bot]" "Copilot")

    for reviewer_login in "${candidates[@]}"; do
        if [[ -z "$reviewer_login" ]]; then
            continue
        fi

        local json_data
        json_data=$(cat <<EOF
{
  "reviewers": ["${reviewer_login}"]
}
EOF
)

        local response
        response=$(github_api_curl -s -w "\n%{http_code}" -X POST "$api_url" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Authorization: token ${github_token}" \
            -H "Content-Type: application/json" \
            -d "$json_data" 2>/dev/null || true)

        local http_code
        http_code=$(echo "$response" | tail -n1)

        if [[ "$http_code" =~ ^20[0-9]$ ]]; then
            return 0
        fi
    done

    return 1
}

build_pull_request_head_candidates() {
    local repo_full_name="$1"
    local source_branch="$2"

    if [[ -z "$repo_full_name" ]] || [[ -z "$source_branch" ]]; then
        return 1
    fi

    local repo_owner="${repo_full_name%%/*}"

    if [[ "$source_branch" == *":"* ]]; then
        printf '%s\n' "$source_branch"
        return 0
    fi

    printf '%s\n' "${repo_owner}:${source_branch}"
    if [[ "$source_branch" == */* ]]; then
        local maybe_owner="${source_branch%%/*}"
        local maybe_branch="${source_branch#*/}"
        printf '%s\n' "${maybe_owner}:${maybe_branch}"
    fi
}

extract_first_pull_request_record() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import sys, json
s = sys.stdin.read()
try:
    data = json.loads(s)
except Exception:
    sys.exit(0)
if isinstance(data, dict):
    items = [data]
elif isinstance(data, list):
    items = data
else:
    items = []
for item in items:
    if not isinstance(item, dict):
        continue
    url = item.get("html_url")
    if not isinstance(url, str) or not url:
        continue
    number = item.get("number")
    state = item.get("state") or ""
    merged = "true" if item.get("merged_at") else "false"
    number_str = "" if number is None else str(number)
    sys.stdout.write(f"{number_str}|{state}|{merged}|{url}")
    break
' 2>/dev/null
        return 0
    fi

    local pr_url
    pr_url=$(extract_first_html_url)
    if [[ -n "$pr_url" ]]; then
        printf '||false|%s' "$pr_url"
    fi
}

get_pull_request_record_by_state() {
    local repo_full_name="$1"
    local source_branch="$2"
    local target_branch="$3"
    local github_token="$4"
    local pr_state="${5:-open}"

    if [[ -z "$repo_full_name" ]] || [[ -z "$source_branch" ]] || [[ -z "$github_token" ]]; then
        return 1
    fi

    local api_url="https://api.github.com/repos/${repo_full_name}/pulls"
    local head_param=""
    local response=""
    local pr_record=""

    while IFS= read -r head_param; do
        [[ -z "$head_param" ]] && continue

        if [[ -n "$target_branch" ]]; then
            response=$(github_api_curl -s -G "$api_url" \
                --data-urlencode "head=${head_param}" \
                --data-urlencode "base=${target_branch}" \
                --data-urlencode "state=${pr_state}" \
                --data-urlencode "per_page=1" \
                -H "Accept: application/vnd.github.v3+json" \
                -H "Authorization: token ${github_token}" 2>/dev/null || true)
            pr_record=$(echo "$response" | extract_first_pull_request_record)
            if [[ -n "$pr_record" ]]; then
                echo "$pr_record"
                return 0
            fi
        fi

        response=$(github_api_curl -s -G "$api_url" \
            --data-urlencode "head=${head_param}" \
            --data-urlencode "state=${pr_state}" \
            --data-urlencode "per_page=1" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Authorization: token ${github_token}" 2>/dev/null || true)
        pr_record=$(echo "$response" | extract_first_pull_request_record)
        if [[ -n "$pr_record" ]]; then
            echo "$pr_record"
            return 0
        fi
    done < <(build_pull_request_head_candidates "$repo_full_name" "$source_branch")

    return 1
}

get_open_pull_request_record_with_retry() {
    local repo_full_name="$1"
    local source_branch="$2"
    local target_branch="$3"
    local github_token="$4"
    local max_attempts="${5:-3}"
    local sleep_seconds="${6:-1}"

    local attempt=1
    local pr_record=""
    while [[ $attempt -le $max_attempts ]]; do
        pr_record=$(get_pull_request_record_by_state "$repo_full_name" "$source_branch" "$target_branch" "$github_token" "open" 2>/dev/null || echo "")
        if [[ -n "$pr_record" ]]; then
            echo "$pr_record"
            return 0
        fi

        ((attempt++))
        if [[ $attempt -le $max_attempts ]]; then
            sleep "$sleep_seconds"
        fi
    done

    return 1
}

# 获取已存在的 open PR URL
get_existing_pr_url() {
    local repo_full_name="$1"
    local source_branch="$2"
    local target_branch="$3"
    local github_token="$4"

    local pr_record=""
    pr_record=$(get_pull_request_record_by_state "$repo_full_name" "$source_branch" "$target_branch" "$github_token" "open" 2>/dev/null || echo "")
    if [[ -z "$pr_record" ]]; then
        return 1
    fi

    local pr_number=""
    local pr_state=""
    local pr_merged=""
    local pr_url=""
    IFS='|' read -r pr_number pr_state pr_merged pr_url <<< "$pr_record"
    if [[ -n "$pr_url" ]]; then
        echo "$pr_url"
        return 0
    fi

    return 1
}

# 获取当前分支
get_current_branch() {
    local repo_path="$1"
    (cd "$repo_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null) || return 1
}

# 获取最新的 commit message
get_latest_commit_message() {
    local repo_path="$1"
    (cd "$repo_path" && git log -1 --pretty=%B 2>/dev/null | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') || return 1
}

# 检查仓库相对于目标分支是否有修改（用于 PR）
check_repo_has_changes_for_pr() {
    local repo_path="$1"
    local target_branch="$2"

    if [[ ! -d "${repo_path}/.git" ]] && [[ ! -f "${repo_path}/.git" ]]; then
        return 1
    fi

    local current_branch
    current_branch=$(cd "$repo_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ -z "$current_branch" ]]; then
        return 1
    fi

    if [[ "$current_branch" == "$target_branch" ]]; then
        return 1
    fi

    (cd "$repo_path" && git fetch origin "$target_branch" "$current_branch" 2>/dev/null || true)

    local remote_branch_exists
    remote_branch_exists=$(cd "$repo_path" && git ls-remote --heads origin "$current_branch" 2>/dev/null | grep -q "$current_branch" && echo "yes" || echo "no")
    if [[ "$remote_branch_exists" == "no" ]]; then
        return 1
    fi

    local common_base
    common_base=$(cd "$repo_path" && git merge-base "origin/${target_branch}" "origin/${current_branch}" 2>/dev/null || echo "")
    if [[ -z "$common_base" ]]; then
        return 1
    fi

    local has_diff
    has_diff=$(cd "$repo_path" && git diff --quiet "origin/${target_branch}..origin/${current_branch}" 2>/dev/null && echo "no" || echo "yes")

    if [[ "$has_diff" == "no" ]]; then
        return 1
    fi

    return 0
}

# 创建 GitHub PR
create_github_pr() {
    local repo_path="$1"
    local repo_info="$2"
    local source_branch="$3"
    local target_branch="${4:-main}"
    local title="$5"
    local description="$6"
    local github_token="$7"

    IFS='|' read -r name path url <<< "$repo_info"

    local repo_full_name=""
    local repo_info_exit_code=0
    capture_command_output repo_full_name repo_info_exit_code get_repo_info "$repo_path"
    if [[ -z "$repo_full_name" ]]; then
        echo -e "${BOLD_RED}错误: 无法获取仓库信息: ${path}${NC}"
        return 1
    fi

    (cd "$repo_path" && git fetch origin "$target_branch" "$source_branch" 2>/dev/null || true)

    local branch_exists
    branch_exists=$(cd "$repo_path" && git ls-remote --heads origin "$source_branch" 2>/dev/null | grep -q "$source_branch" && echo "yes" || echo "no")
    if [[ "$branch_exists" == "no" ]]; then
        echo -e "${BOLD_YELLOW}警告: 分支 ${source_branch} 不存在于远程${NC}" >&2
        echo -e "${YELLOW}请先推送分支: git push origin ${source_branch}${NC}" >&2
        return 1
    fi

    local existing_pr_url
    existing_pr_url=$(get_existing_pr_url "$repo_full_name" "$source_branch" "$target_branch" "$github_token" 2>/dev/null || echo "")
    if [[ -n "$existing_pr_url" ]]; then
        echo "$existing_pr_url"
        return 0
    fi

    local common_base
    common_base=$(cd "$repo_path" && git merge-base "origin/${target_branch}" "origin/${source_branch}" 2>/dev/null || echo "")
    if [[ -z "$common_base" ]]; then
        echo -e "${BOLD_YELLOW}警告: 分支 ${source_branch} 和 ${target_branch} 没有共同历史${NC}" >&2
        echo -e "${YELLOW}这可能是因为分支是从不同的提交创建的${NC}" >&2
        echo -e "${YELLOW}解决方案:${NC}" >&2
        echo -e "${CYAN}  1. 确保分支是从 ${target_branch} 创建的${NC}" >&2
        echo -e "${CYAN}  2. 或者先合并 ${target_branch} 到 ${source_branch}:${NC}" >&2
        echo -e "${CYAN}     git checkout ${source_branch}${NC}" >&2
        echo -e "${CYAN}     git merge origin/${target_branch}${NC}" >&2
        echo -e "${CYAN}     git push origin ${source_branch}${NC}" >&2
        return 1
    fi

    local ahead
    ahead=$(cd "$repo_path" && git rev-list --count "${common_base}..origin/${source_branch}" 2>/dev/null || echo "0")
    if [[ "$ahead" -eq 0 ]]; then
        echo -e "${BOLD_YELLOW}警告: 分支 ${source_branch} 没有相对于 ${target_branch} 的新提交${NC}" >&2
        return 1
    fi

    local title_escaped
    title_escaped=$(echo "$title" | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
    local desc_escaped
    desc_escaped=$(echo "$description" | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

    local api_url="https://api.github.com/repos/${repo_full_name}/pulls"
    local json_data
    json_data=$(cat <<EOF
{
  "title": "${title_escaped}",
  "body": "${desc_escaped}",
  "head": "${source_branch}",
  "base": "${target_branch}",
  "draft": true
}
EOF
)

    local response
    response=$(github_api_curl -s -w "\n%{http_code}" -X POST "$api_url" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token ${github_token}" \
        -H "Content-Type: application/json" \
        -d "$json_data" 2>&1 || true)

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" == "201" ]]; then
        local pr_url
        pr_url=$(echo "$body" | extract_first_html_url)
        local pr_number
        pr_number=$(echo "$body" | extract_pr_number)

        if [[ -n "$pr_number" ]]; then
            local auto_label="MT AUTO"

            if ! add_label_to_pr "$repo_full_name" "$pr_number" "$auto_label" "$github_token"; then
                if ensure_label_exists "$repo_full_name" "$auto_label" "$github_token" "1D76DB"; then
                    add_label_to_pr "$repo_full_name" "$pr_number" "$auto_label" "$github_token" || true
                fi
            fi

            request_copilot_review "$repo_full_name" "$pr_number" "$github_token" || true
        fi

        echo "$pr_url"
        return 0
    elif [[ "$http_code" == "422" ]]; then
        if echo "$body" | grep -q "already exists" || echo "$body" | grep -q "A pull request already exists"; then
            local open_pr_record=""
            open_pr_record=$(get_open_pull_request_record_with_retry "$repo_full_name" "$source_branch" "$target_branch" "$github_token" 3 1 2>/dev/null || echo "")

            if [[ -n "$open_pr_record" ]]; then
                local open_pr_number=""
                local open_pr_state=""
                local open_pr_merged=""
                local open_pr_url=""
                IFS='|' read -r open_pr_number open_pr_state open_pr_merged open_pr_url <<< "$open_pr_record"
                if [[ -n "$open_pr_url" ]]; then
                    echo "$open_pr_url"
                    return 0
                fi
            fi

            local historical_pr_record=""
            historical_pr_record=$(get_pull_request_record_by_state "$repo_full_name" "$source_branch" "$target_branch" "$github_token" "all" 2>/dev/null || echo "")
            if [[ -n "$historical_pr_record" ]]; then
                local historical_pr_number=""
                local historical_pr_state=""
                local historical_pr_merged=""
                local historical_pr_url=""
                IFS='|' read -r historical_pr_number historical_pr_state historical_pr_merged historical_pr_url <<< "$historical_pr_record"

                if [[ -n "$historical_pr_url" ]]; then
                    if [[ "$historical_pr_state" == "open" ]]; then
                        echo "$historical_pr_url"
                        return 0
                    fi

                    if [[ "$historical_pr_merged" == "true" ]]; then
                        echo -e "${BOLD_YELLOW}警告: 检测到历史 PR 已合并，当前仓库不会自动复用旧 PR${NC}" >&2
                    else
                        echo -e "${BOLD_YELLOW}警告: 检测到历史 PR 已关闭，请检查是否需要 reopen${NC}" >&2
                    fi
                    echo -e "${CYAN}历史 PR: ${historical_pr_url}${NC}" >&2
                    echo "$historical_pr_url"
                    return 2
                fi
            fi

            echo -e "${BOLD_YELLOW}警告: GitHub 返回 PR 已存在，但未能查询到对应 PR 链接${NC}" >&2
            return 2
        fi

        echo -e "${BOLD_RED}错误: 创建 PR 失败 (HTTP ${http_code})${NC}" >&2
        echo -e "${RED}仓库: ${name}${NC}" >&2

        if echo "$body" | grep -q "no history in common"; then
            echo -e "${YELLOW}原因: 分支 ${source_branch} 和 ${target_branch} 没有共同历史${NC}" >&2
            echo -e "${YELLOW}解决方案:${NC}" >&2
            echo -e "${CYAN}  1. 确保分支已推送到远程: git push origin ${source_branch}${NC}" >&2
            echo -e "${CYAN}  2. 如果分支是从其他分支创建的，需要先合并 ${target_branch}:${NC}" >&2
            echo -e "${CYAN}     git checkout ${source_branch}${NC}" >&2
            echo -e "${CYAN}     git merge ${target_branch}${NC}" >&2
            echo -e "${CYAN}     git push origin ${source_branch}${NC}" >&2
        elif echo "$body" | grep -q "Validation Failed"; then
            echo -e "${YELLOW}GitHub API 验证失败:${NC}" >&2
            local error_msg
            error_msg=$(echo "$body" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)
            if [[ -n "$error_msg" ]]; then
                echo -e "${RED}  错误消息: ${error_msg}${NC}" >&2
            fi
            local errors
            errors=$(echo "$body" | grep -o '"errors":\[[^\]]*\]' | head -1)
            if [[ -n "$errors" ]]; then
                echo -e "${YELLOW}  详细错误:${NC}" >&2
                echo -e "${RED}  ${errors}${NC}" >&2
            fi
            echo -e "${YELLOW}  完整响应:${NC}" >&2
            echo -e "${CYAN}  ${body}${NC}" >&2
        else
            echo -e "${YELLOW}错误详情:${NC}" >&2
            echo -e "${RED}  ${body}${NC}" >&2
        fi
        return 1
    else
        echo -e "${BOLD_RED}错误: 创建 PR 失败 (HTTP ${http_code})${NC}" >&2
        echo -e "${RED}仓库: ${name}${NC}" >&2

        case "$http_code" in
            401)
                echo -e "${YELLOW}原因: 未授权，GitHub token 无效或已过期${NC}" >&2
                echo -e "${YELLOW}解决方案:${NC}" >&2
                echo -e "${CYAN}  请使用 'mt set-github-token <your_token>' 重新设置 token${NC}" >&2
                echo -e "${CYAN}  获取新 token: https://github.com/settings/tokens${NC}" >&2
                ;;
            403)
                echo -e "${YELLOW}原因: 禁止访问，可能是 token 权限不足或仓库访问受限${NC}" >&2
                echo -e "${YELLOW}解决方案:${NC}" >&2
                echo -e "${CYAN}  1. 检查 token 是否有 'repo' 权限${NC}" >&2
                echo -e "${CYAN}  2. 确认你有该仓库的访问权限${NC}" >&2
                ;;
            404)
                echo -e "${YELLOW}原因: 仓库或分支不存在${NC}" >&2
                echo -e "${YELLOW}解决方案:${NC}" >&2
                echo -e "${CYAN}  1. 确认仓库路径正确: ${repo_full_name}${NC}" >&2
                echo -e "${CYAN}  2. 确认分支已推送到远程: git push origin ${source_branch}${NC}" >&2
                ;;
            500|502|503|504)
                echo -e "${YELLOW}原因: GitHub 服务器错误 (HTTP ${http_code})${NC}" >&2
                echo -e "${YELLOW}解决方案:${NC}" >&2
                echo -e "${CYAN}  请稍后重试${NC}" >&2
                ;;
            *)
                echo -e "${YELLOW}未知错误 (HTTP ${http_code})${NC}" >&2
                ;;
        esac

        if [[ -n "$body" ]]; then
            echo -e "${YELLOW}响应内容:${NC}" >&2
            local error_msg
            error_msg=$(echo "$body" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)
            if [[ -n "$error_msg" ]]; then
                echo -e "${RED}  ${error_msg}${NC}" >&2
            else
                echo -e "${CYAN}  ${body}${NC}" >&2
            fi
        fi

        return 1
    fi
}

# 更新 PR 描述
update_pr_description() {
    local repo_path="$1"
    local repo_info="$2"
    local pr_url="$3"
    local new_description="$4"
    local github_token="$5"

    IFS='|' read -r name path url <<< "$repo_info"

    local repo_full_name=""
    local repo_info_exit_code=0
    capture_command_output repo_full_name repo_info_exit_code get_repo_info "$repo_path"
    if [[ -z "$repo_full_name" ]]; then
        return 1
    fi

    local pr_number
    pr_number=$(echo "$pr_url" | grep -oE '/pull/[0-9]+' | grep -oE '[0-9]+' || true)
    if [[ -z "$pr_number" ]]; then
        return 1
    fi

    local desc_escaped
    desc_escaped=$(echo "$new_description" | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

    local api_url="https://api.github.com/repos/${repo_full_name}/pulls/${pr_number}"
    local json_data
    json_data=$(cat <<EOF
{
  "body": "${desc_escaped}"
}
EOF
)

    echo -e "${CYAN}更新 PR 描述...${NC}"
    echo -e "${CYAN}  → curl -X PATCH ${api_url}${NC}"
    echo -e "${CYAN}  → Head: Authorization: token ***${NC}"

    local response
    response=$(github_api_curl -s -w "\n%{http_code}" -X PATCH "$api_url" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token ${github_token}" \
        -H "Content-Type: application/json" \
        -d "$json_data" 2>&1 || true)

    local http_code
    http_code=$(echo "$response" | tail -n1)

    if [[ "$http_code" == "200" ]]; then
        return 0
    else
        return 1
    fi
}

# 将 Draft PR 设置为 Ready for review
mark_pr_ready_for_review() {
    local repo_full_name="$1"
    local pr_number="$2"
    local github_token="$3"

    if [[ -z "$repo_full_name" ]] || [[ -z "$pr_number" ]] || [[ -z "$github_token" ]]; then
        return 1
    fi

    local api_url="https://api.github.com/repos/${repo_full_name}/pulls/${pr_number}/ready_for_review"
    local response
    response=$(github_api_curl -s -w "\n%{http_code}" -X POST "$api_url" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token ${github_token}" 2>&1 || true)

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" == "200" ]]; then
        return 0
    fi

    if [[ "$http_code" == "422" ]] && echo "$body" | grep -qi "already ready for review"; then
        return 0
    fi

    return 1
}

# 创建多个仓库的 PR 并关联
create_prs() {
    local target_branch="${1:-main}"
    local title="${2:-}"
    local description="${3:-}"
    local ready_for_review="${4:-false}"

    local github_token=""
    local token_exit_code=0
    capture_command_output github_token token_exit_code get_github_token
    if [[ $token_exit_code -ne 0 ]] || [[ -z "$github_token" ]]; then
        echo -e "${BOLD_RED}错误: 未找到 GitHub token${NC}" >&2
        echo -e "${YELLOW}请使用以下命令设置 GitHub token:${NC}" >&2
        echo -e "${CYAN}  mt set-github-token <your_token>${NC}" >&2
        echo -e "${YELLOW}Token 将保存到 github.token 文件（已添加到 .gitignore）${NC}" >&2
        echo -e "${CYAN}获取 token: https://github.com/settings/tokens${NC}" >&2
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

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  创建 GitHub Pull Request${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${CYAN}目标分支: ${target_branch}${NC}"
    echo ""

    local pr_urls_names=()
    local pr_urls_values=()
    local pr_status_names=()
    local pr_status_values=()
    local review_summary_names=()
    local review_summary_urls=()
    local review_summary_descs=()
    local review_summary_authors=()
    local total=${#repos_array[@]}
    local success_count=0
    local skipped_count=0
    local planned_count=0
    local action_required_count=0
    local failure_count=0

    local review_author=""
    review_author=$(get_github_user_display_name "$github_token" 2>/dev/null || echo "")
    if [[ -z "$review_author" ]]; then
        review_author="unknown"
    fi
    review_author=$(echo "$review_author" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | sed -E 's/^ //; s/ $//')
    review_author="${review_author//|/ }"

    for i in "${!repos_array[@]}"; do
        local repo_info="${repos_array[$i]}"
        IFS='|' read -r name path url <<< "$repo_info"

        local repo_path="${PROJECT_ROOT}/${path}"
        local index=$((i + 1))

        echo -e "${CYAN}[${index}/${total}] ${name}${NC}"

        if [[ ! -d "$repo_path" ]]; then
            echo -e "${YELLOW}  ⏭  跳过: 路径不存在 ${path}${NC}"
            pr_status_names+=("$name")
            pr_status_values+=("路径不存在")
            ((skipped_count++))
            continue
        fi

        if ! is_git_repository_path "$repo_path"; then
            echo -e "${YELLOW}  ⏭  跳过: 不是 Git 仓库 ${path}${NC}"
            pr_status_names+=("$name")
            pr_status_values+=("不是 Git 仓库")
            ((skipped_count++))
            continue
        fi

        local current_branch=""
        local current_branch_exit_code=0
        capture_command_output current_branch current_branch_exit_code get_current_branch "$repo_path"
        if [[ -z "$current_branch" ]]; then
            echo -e "${YELLOW}  ⏭  跳过: 无法获取当前分支${NC}"
            pr_status_names+=("$name")
            pr_status_values+=("无法获取分支")
            ((failure_count++))
            continue
        fi

        if [[ "$current_branch" == "$target_branch" ]]; then
            echo -e "${YELLOW}  ⏭  跳过: 当前分支已是 ${target_branch}${NC}"
            pr_status_names+=("$name")
            pr_status_values+=("无代码变更")
            ((skipped_count++))
            continue
        fi

        if [[ "$GLOBAL_DRY_RUN" == "true" ]]; then
            echo -e "${YELLOW}  ⏭  dry-run: 将检查并创建/复用 PR（未实际执行）${NC}"
            pr_status_names+=("$name")
            pr_status_values+=("dry-run")
            ((planned_count++))
            echo ""
            continue
        fi

        local has_uncommitted_changes=false
        if ! (cd "$repo_path" && git diff --quiet 2>/dev/null); then
            has_uncommitted_changes=true
        fi
        if ! (cd "$repo_path" && git diff --cached --quiet 2>/dev/null); then
            has_uncommitted_changes=true
        fi
        if [[ "$has_uncommitted_changes" == true ]]; then
            echo -e "${YELLOW}  ⚠  检测到未提交的本地修改（PR 只基于已提交并推送到远程的提交）${NC}"
            echo -e "${YELLOW}  请先提交并推送后再执行 mt pr${NC}"
            echo -e "${CYAN}    git add . && git commit -m \"...\" && git push${NC}"
            pr_status_names+=("$name")
            pr_status_values+=("需要先提交")
            ((action_required_count++))
            echo ""
            continue
        fi

        local local_sha=""
        local remote_sha=""
        local_sha=$(cd "$repo_path" && git rev-parse "$current_branch" 2>/dev/null || echo "")
        remote_sha=$(cd "$repo_path" && git rev-parse "origin/${current_branch}" 2>/dev/null || echo "")
        if [[ -n "$local_sha" ]] && [[ -n "$remote_sha" ]] && [[ "$local_sha" != "$remote_sha" ]]; then
            local ahead_count
            local behind_count
            ahead_count=$(cd "$repo_path" && git rev-list --count "origin/${current_branch}..${current_branch}" 2>/dev/null || echo "0")
            behind_count=$(cd "$repo_path" && git rev-list --count "${current_branch}..origin/${current_branch}" 2>/dev/null || echo "0")

            echo -e "${YELLOW}  ⚠  本地分支与远程分支不一致（PR 以远程分支为准）${NC}"

            if [[ "$ahead_count" -gt 0 ]] && [[ "$behind_count" -eq 0 ]]; then
                echo -e "${YELLOW}  本地领先 ${ahead_count} 个提交，请先推送:${NC}"
                echo -e "${CYAN}    git push origin ${current_branch}${NC}"
                pr_status_names+=("$name")
                pr_status_values+=("需要先推送")
            elif [[ "$ahead_count" -eq 0 ]] && [[ "$behind_count" -gt 0 ]]; then
                echo -e "${YELLOW}  本地落后远程 ${behind_count} 个提交，请先同步:${NC}"
                echo -e "${CYAN}    git pull --rebase${NC}"
                pr_status_names+=("$name")
                pr_status_values+=("需要先同步")
            elif [[ "$ahead_count" -gt 0 ]] && [[ "$behind_count" -gt 0 ]]; then
                echo -e "${YELLOW}  分支发生分叉（可能执行了 rebase/amend），请先推送（推荐 --force-with-lease）:${NC}"
                echo -e "${CYAN}    git push --force-with-lease origin ${current_branch}${NC}"
                pr_status_names+=("$name")
                pr_status_values+=("需要先推送")
            else
                echo -e "${YELLOW}  请先推送/同步后再创建 PR${NC}"
                pr_status_names+=("$name")
                pr_status_values+=("需要先推送")
            fi

            ((action_required_count++))
            echo ""
            continue
        fi

        local has_remote_changes=false
        if check_repo_has_changes_for_pr "$repo_path" "$target_branch"; then
            has_remote_changes=true
        fi

        if [[ "$has_remote_changes" == false ]]; then
            (cd "$repo_path" && git fetch origin "$target_branch" "$current_branch" 2>/dev/null || true)
            local common_base
            common_base=$(cd "$repo_path" && git merge-base "origin/${target_branch}" "$current_branch" 2>/dev/null || echo "")

            if [[ -z "$common_base" ]]; then
                echo -e "${BOLD_YELLOW}警告: 无法判断是否有相对于 ${target_branch} 的代码变更（merge-base 失败）${NC}"
                echo -e "${YELLOW}可能原因:${NC}"
                echo -e "${CYAN}  1) 目标分支名不正确或未拉取（请尝试 git fetch origin ${target_branch}）${NC}"
                echo -e "${CYAN}  2) 分支历史无共同祖先（需要检查分支来源）${NC}"
                pr_status_names+=("$name")
                pr_status_values+=("无法比较")
                ((action_required_count++))
                echo ""
                continue
            fi

            local has_local_diff
            has_local_diff=$(cd "$repo_path" && git diff --quiet "${common_base}..${current_branch}" 2>/dev/null && echo "no" || echo "yes")

            if [[ "$has_local_diff" == "yes" ]]; then
                echo -e "${YELLOW}  ⚠  检测到本地有相对于 ${target_branch} 的提交差异，但远程分支未检测到变更${NC}"
                echo -e "${YELLOW}  PR 以远程分支为准，请先推送当前分支到远程后再创建 PR:${NC}"
                echo -e "${CYAN}    git push origin ${current_branch}${NC}"
                echo -e "${CYAN}    （如执行过 rebase/amend，推荐使用 --force-with-lease）${NC}"
                pr_status_names+=("$name")
                pr_status_values+=("需要先推送")
                ((action_required_count++))
                echo ""
                continue
            fi

            echo -e "${YELLOW}  ⏭  跳过: 没有相对于 ${target_branch} 的代码变更${NC}"
            pr_status_names+=("$name")
            pr_status_values+=("无代码变更")
            ((skipped_count++))
            continue
        fi

        local pr_title="${title:-}"
        if [[ -z "$pr_title" ]]; then
            capture_command_output pr_title current_branch_exit_code get_latest_commit_message "$repo_path"
            if [[ -z "$pr_title" ]]; then
                pr_title="$current_branch"
            fi
        fi
        local pr_description="${description:-}"

        local repo_full_name=""
        local repo_full_name_exit_code=0
        capture_command_output repo_full_name repo_full_name_exit_code get_repo_info "$repo_path"
        local existing_pr_url=""
        if [[ -n "$repo_full_name" ]]; then
            existing_pr_url=$(get_existing_pr_url "$repo_full_name" "$current_branch" "$target_branch" "$github_token" 2>/dev/null || echo "")
        fi

        if [[ -n "$existing_pr_url" ]]; then
            pr_urls_names+=("$name")
            pr_urls_values+=("$existing_pr_url")
            pr_status_names+=("$name")
            pr_status_values+=("$existing_pr_url")
            ((success_count++))
            echo -e "${GREEN}  ${CHECK_MARK} PR 已存在${NC}"
            echo -e "${CYAN}    ${existing_pr_url}${NC}"

            local summary_desc="${pr_description:-}"
            if [[ -z "$summary_desc" ]]; then
                summary_desc="$pr_title"
            fi
            summary_desc=$(echo "$summary_desc" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | sed -E 's/^ //; s/ $//')
            summary_desc="${summary_desc//|/ }"
            if [[ -z "$summary_desc" ]]; then
                summary_desc="无描述"
            fi
            review_summary_names+=("$name")
            review_summary_urls+=("$existing_pr_url")
            review_summary_descs+=("$summary_desc")
            review_summary_authors+=("$review_author")

            if [[ "$ready_for_review" == "true" ]]; then
                if declare -F mark_pr_ready_for_review >/dev/null 2>&1; then
                    local pr_number
                    pr_number=$(extract_pr_number_from_url "$existing_pr_url")
                    if [[ -n "$pr_number" ]] && [[ -n "$repo_full_name" ]]; then
                        if mark_pr_ready_for_review "$repo_full_name" "$pr_number" "$github_token"; then
                            echo -e "${GREEN}  ${CHECK_MARK} 已设置为 Ready${NC}"
                        else
                            echo -e "${BOLD_YELLOW}  警告: 设置 Ready 失败${NC}"
                        fi
                    else
                        echo -e "${BOLD_YELLOW}  警告: 无法解析 PR 号，跳过 Ready${NC}"
                    fi
                else
                    echo -e "${BOLD_YELLOW}  警告: 当前版本不支持设置 Ready，请升级 mt${NC}"
                fi
            fi
            echo ""
            continue
        else
            local temp_stderr
            temp_stderr=$(mktemp)
            local pr_url=""
            local pr_exit_code=0
            capture_command_output pr_url pr_exit_code create_github_pr "$repo_path" "$repo_info" "$current_branch" "$target_branch" "$pr_title" "$pr_description" "$github_token" 2>"$temp_stderr"
            local pr_error_output
            pr_error_output=$(cat "$temp_stderr" 2>/dev/null)
            rm -f "$temp_stderr"

            if [[ -n "$pr_error_output" ]]; then
                echo "$pr_error_output" >&2
            fi

            if [[ -n "$pr_url" ]] && echo "$pr_url" | grep -q "github.com" && [[ "$pr_exit_code" -eq 0 ]]; then
                pr_urls_names+=("$name")
                pr_urls_values+=("$pr_url")
                pr_status_names+=("$name")
                pr_status_values+=("$pr_url")
                ((success_count++))
                echo -e "${GREEN}  ${CHECK_MARK} PR 创建成功${NC}"
                echo -e "${CYAN}    ${pr_url}${NC}"

                local summary_desc="${pr_description:-}"
                if [[ -z "$summary_desc" ]]; then
                    summary_desc="$pr_title"
                fi
                summary_desc=$(echo "$summary_desc" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | sed -E 's/^ //; s/ $//')
                summary_desc="${summary_desc//|/ }"
                if [[ -z "$summary_desc" ]]; then
                    summary_desc="无描述"
                fi
                review_summary_names+=("$name")
                review_summary_urls+=("$pr_url")
                review_summary_descs+=("$summary_desc")
                review_summary_authors+=("$review_author")

                if [[ "$ready_for_review" == "true" ]]; then
                    if declare -F mark_pr_ready_for_review >/dev/null 2>&1; then
                        local pr_number
                        pr_number=$(extract_pr_number_from_url "$pr_url")
                        if [[ -n "$pr_number" ]] && [[ -n "$repo_full_name" ]]; then
                            if mark_pr_ready_for_review "$repo_full_name" "$pr_number" "$github_token"; then
                                echo -e "${GREEN}  ${CHECK_MARK} 已设置为 Ready${NC}"
                            else
                                echo -e "${BOLD_YELLOW}  警告: 设置 Ready 失败${NC}"
                            fi
                        else
                            echo -e "${BOLD_YELLOW}  警告: 无法解析 PR 号，跳过 Ready${NC}"
                        fi
                    else
                        echo -e "${BOLD_YELLOW}  警告: 当前版本不支持设置 Ready，请升级 mt${NC}"
                    fi
                fi
            elif [[ "$pr_url" == "PR_EXISTS" ]] && [[ "$pr_exit_code" -eq 0 ]]; then
                pr_status_names+=("$name")
                pr_status_values+=("PR 已存在")
                ((success_count++))
                echo -e "${GREEN}  ${CHECK_MARK} PR 已存在${NC}"
            elif [[ "$pr_exit_code" -eq 2 ]]; then
                local historical_status="历史 PR 存在"
                if echo "$pr_error_output" | grep -q "历史 PR 已合并"; then
                    historical_status="历史 PR 已合并"
                elif echo "$pr_error_output" | grep -q "历史 PR 已关闭"; then
                    historical_status="历史 PR 已关闭"
                elif [[ -z "$pr_url" ]]; then
                    historical_status="PR 已存在（未解析到链接）"
                fi

                if [[ -n "$pr_url" ]] && echo "$pr_url" | grep -q "github.com"; then
                    historical_status="${historical_status}: ${pr_url}"
                fi

                pr_status_names+=("$name")
                pr_status_values+=("$historical_status")
                ((action_required_count++))
                echo -e "${BOLD_YELLOW}  警告: ${historical_status}${NC}"
            elif echo "$pr_url" | grep -q "可能导致冲突" || echo "$pr_error_output" | grep -q "可能导致冲突"; then
                pr_status_names+=("$name")
                pr_status_values+=("需要解决冲突")
                ((action_required_count++))
                echo -e "${RED}  ${CROSS_MARK} 需要解决冲突（见上方提示）${NC}"
            else
                pr_status_names+=("$name")
                pr_status_values+=("创建失败")
                ((failure_count++))
                if [[ -z "$pr_error_output" ]] && [[ $pr_exit_code -ne 0 ]]; then
                    echo -e "${RED}  ${CROSS_MARK} PR 创建失败（退出码: ${pr_exit_code}）${NC}"
                    echo -e "${YELLOW}  提示: 请检查网络连接、GitHub token 权限和分支状态${NC}"
                else
                    echo -e "${RED}  ${CROSS_MARK} PR 创建失败（见上方错误信息）${NC}"
                fi
            fi
        fi
        echo ""

        if [[ "$GLOBAL_FAIL_FAST" == "true" ]]; then
            local latest_status_index=$((${#pr_status_values[@]} - 1))
            if [[ $latest_status_index -ge 0 ]]; then
                local latest_status="${pr_status_values[$latest_status_index]}"
                if [[ "$latest_status" == "创建失败" ]] || [[ "$latest_status" == "需要解决冲突" ]]; then
                    break
                fi
            fi
        fi
    done

    if [[ ${#pr_urls_names[@]} -gt 1 ]]; then
        echo -e "${BLUE}更新 PR 描述，添加关联链接...${NC}"
        echo ""

        for i in "${!pr_urls_names[@]}"; do
            local repo_name="${pr_urls_names[$i]}"
            local pr_url="${pr_urls_values[$i]}"
            local related_links="## 相关 PR"$'\n'$'\n'
            for j in "${!pr_urls_names[@]}"; do
                local other_repo="${pr_urls_names[$j]}"
                local other_url="${pr_urls_values[$j]}"
                if [[ "$other_repo" != "$repo_name" ]]; then
                    related_links="${related_links}- [${other_repo}](${other_url})"$'\n'
                fi
            done

            for repo_info in "${repos_array[@]}"; do
                IFS='|' read -r name path url <<< "$repo_info"
                if [[ "$name" == "$repo_name" ]]; then
                    local repo_path="${PROJECT_ROOT}/${path}"
                    local original_description="${description:-}"
                    local new_description="${original_description}"$'\n'$'\n'"${related_links}"

                    if update_pr_description "$repo_path" "$repo_info" "$pr_url" "$new_description" "$github_token"; then
                        echo -e "${GREEN}${CHECK_MARK} 已更新 ${repo_name} 的 PR 描述${NC}"
                    else
                        echo -e "${BOLD_YELLOW}警告: 更新 ${repo_name} 的 PR 描述失败${NC}"
                    fi
                    break
                fi
            done
        done
        echo ""
    fi

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  PR 创建结果汇总${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    printf "%-30s %s\n" "仓库" "状态/PR 链接"
    echo "────────────────────────────────────────────────────────────────"

    for repo_info in "${repos_array[@]}"; do
        IFS='|' read -r name path url <<< "$repo_info"

        local found=false
        local status=""
        for i in "${!pr_status_names[@]}"; do
            if [[ "${pr_status_names[$i]}" == "$name" ]]; then
                status="${pr_status_values[$i]}"
                found=true
                break
            fi
        done

        if [[ "$found" == true ]]; then
            if [[ "$status" == "无改动" ]] || [[ "$status" == "无代码变更" ]]; then
                printf "%-30s %s\n" "$name:" "无代码变更"
            elif [[ "$status" == "需要先推送" ]]; then
                printf "%-30s %s\n" "$name:" "需要先推送（本地有未推送的提交）"
            elif [[ "$status" == "创建失败" ]] || [[ "$status" == "路径不存在" ]] || [[ "$status" == "无法获取分支" ]]; then
                printf "%-30s %s\n" "$name:" "$status"
            else
                printf "%-30s %s\n" "$name:" "$status"
            fi
        else
            printf "%-30s %s\n" "$name:" "未处理"
        fi
    done

    echo ""
    echo -e "${BLUE}========================================${NC}"
    if [[ $success_count -gt 0 ]]; then
        echo -e "${GREEN}${CHECK_MARK} 成功创建/复用 ${success_count} 个 open PR${NC}"
    fi
    if [[ $skipped_count -gt 0 ]]; then
        echo -e "${YELLOW}⏭  跳过 ${skipped_count} 个仓库${NC}"
    fi
    if [[ $planned_count -gt 0 ]]; then
        echo -e "${CYAN}⏭  dry-run 计划 ${planned_count} 个仓库${NC}"
    fi
    if [[ $action_required_count -gt 0 ]]; then
        echo -e "${BOLD_YELLOW}⚠  ${action_required_count} 个仓库需要人工处理${NC}"
    fi
    if [[ $failure_count -gt 0 ]]; then
        echo -e "${BOLD_RED}${CROSS_MARK} ${failure_count} 个仓库创建 PR 失败${NC}"
    fi
    if [[ $success_count -eq 0 ]] && [[ $skipped_count -eq 0 ]] && [[ $planned_count -eq 0 ]] && [[ $action_required_count -eq 0 ]] && [[ $failure_count -eq 0 ]]; then
        echo -e "${YELLOW}没有创建任何 PR${NC}"
    fi
    echo -e "${BLUE}========================================${NC}"

    if [[ ${#review_summary_urls[@]} -gt 0 ]]; then
        echo ""
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  Review 群发布摘要${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""

        for i in "${!review_summary_urls[@]}"; do
            local repo_name="${review_summary_names[$i]}"
            local pr_url="${review_summary_urls[$i]}"
            local desc="${review_summary_descs[$i]}"
            local author="${review_summary_authors[$i]}"
            echo "[${repo_name}]"
            echo "  作者: ${author}"
            echo "  变更: ${desc}"
            echo "  PR: ${pr_url}"
            echo ""
        done

        echo ""
        echo "注：本PR review由mt工具创建"

        echo ""
        echo -e "${BLUE}========================================${NC}"
    fi
    if [[ $failure_count -gt 0 ]]; then
        return 1
    fi

    return 0
}
