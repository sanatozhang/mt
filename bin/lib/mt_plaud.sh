# Python 工具脚本路径查找
find_plaud_scripts_dir() {
    local mt_scripts_dir="${MT_DIR}/scripts/plaud-tools"
    if [[ -d "$mt_scripts_dir" ]]; then
        echo "$mt_scripts_dir"
        return 0
    fi

    if [[ -n "${PLAUD_SCRIPTS_DIR:-}" ]] && [[ -d "${PLAUD_SCRIPTS_DIR}" ]]; then
        echo "${PLAUD_SCRIPTS_DIR}"
        return 0
    fi

    local possible_paths=(
        "/Users/sanato/Desktop/code/scrip/Plaud-app-scripts"
        "${HOME}/Desktop/code/scrip/Plaud-app-scripts"
        "${HOME}/Documents/Plaud-app-scripts"
        "${HOME}/code/scrip/Plaud-app-scripts"
    )

    for path in "${possible_paths[@]}"; do
        if [[ -d "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

# 检查 Python 脚本是否存在并执行
run_python_script() {
    local script_name="$1"
    shift
    local scripts_dir
    scripts_dir=$(find_plaud_scripts_dir)

    if [[ $? -ne 0 ]] || [[ -z "$scripts_dir" ]]; then
        echo_bi "$BOLD_RED" "错误: 未找到 Plaud-app-scripts 目录" "Error: Plaud-app-scripts directory not found"
        echo_bi "$YELLOW" "请设置环境变量 PLAUD_SCRIPTS_DIR 指向脚本目录" "Please set the PLAUD_SCRIPTS_DIR environment variable to the scripts directory"
        echo_bi "$CYAN" "例如: export PLAUD_SCRIPTS_DIR=/path/to/Plaud-app-scripts" "e.g.: export PLAUD_SCRIPTS_DIR=/path/to/Plaud-app-scripts"
        return 1
    fi

    local script_path="${scripts_dir}/${script_name}"

    if [[ ! -f "$script_path" ]]; then
        echo_bi "$BOLD_RED" "错误: 脚本文件不存在: ${script_path}" "Error: script file not found: ${script_path}"
        return 1
    fi

    if ! command -v python3 &> /dev/null; then
        echo_bi "$BOLD_RED" "错误: 未找到 python3 命令" "Error: python3 command not found"
        return 1
    fi

    python3 "$script_path" "$@"
}

# Plaud 工具：版本号转换
mt_plaud_version() {
    if [[ $# -eq 0 ]]; then
        echo_bi "$BOLD_RED" "错误: 缺少参数" "Error: missing arguments"
        echo_bi "$YELLOW" "用法:" "Usage:"
        echo -e "${CYAN}  mt plaud version -c <versionCode> [-f]    将 versionCode 转换为版本字符串 / Convert versionCode to a version string${NC}"
        echo -e "${CYAN}  mt plaud version -s <版本字符串>           将版本字符串转换为 versionCode / Convert a version string to versionCode${NC}"
        echo ""
        echo_bi "$YELLOW" "示例:" "Examples:"
        echo -e "${CYAN}  mt plaud version -c 66048                  # 输出: 1.0.0 / Output: 1.0.0${NC}"
        echo -e "${CYAN}  mt plaud version -c 66048 -f                # 输出完整版本（包含修订号）/ Output full version (with revision)${NC}"
        echo -e "${CYAN}  mt plaud version -s 1.0.0                  # 输出: 66048 / Output: 66048${NC}"
        return 1
    fi

    run_python_script "version_converter.py" "$@"
}

# Plaud 工具：日志同步分析
mt_plaud_log_sync() {
    if [[ $# -eq 0 ]]; then
        echo_bi "$BOLD_RED" "错误: 请提供日志文件路径" "Error: please provide a log file path"
        echo_bi "$YELLOW" "用法: mt plaud log sync <日志文件路径>" "Usage: mt plaud log sync <log_file_path>"
        return 1
    fi

    run_python_script "log_sync_analyzer.py" "$@"
}

# Plaud 工具：日志清理
mt_plaud_log_clean() {
    if [[ $# -eq 0 ]]; then
        echo_bi "$BOLD_RED" "错误: 请提供日志文件路径" "Error: please provide a log file path"
        echo_bi "$YELLOW" "用法: mt plaud log clean <日志文件路径>" "Usage: mt plaud log clean <log_file_path>"
        return 1
    fi

    run_python_script "log_cleaner_network.py" "$@"
}

# Plaud 工具：同步时间差分析
mt_plaud_log_time_diff() {
    if [[ $# -eq 0 ]]; then
        echo_bi "$BOLD_RED" "错误: 请提供日志文件路径" "Error: please provide a log file path"
        echo_bi "$YELLOW" "用法: mt plaud log time-diff <日志文件路径> [--min-diff <秒数>]" "Usage: mt plaud log time-diff <log_file_path> [--min-diff <seconds>]"
        echo -e "${CYAN}示例: mt plaud log time-diff app.log --min-diff 0.1 / Example: mt plaud log time-diff app.log --min-diff 0.1${NC}"
        return 1
    fi

    run_python_script "plaud_sync_time_diff.py" "$@"
}

# Plaud 工具：Opus 文件检查
mt_plaud_check_opus() {
    if [[ $# -eq 0 ]]; then
        echo_bi "$BOLD_RED" "错误: 请提供文件路径" "Error: please provide a file path"
        echo_bi "$YELLOW" "用法: mt plaud check opus <文件路径>" "Usage: mt plaud check opus <file_path>"
        return 1
    fi

    run_python_script "check_opus.py" "$@"
}

# Plaud 工具：文件批量复制
mt_plaud_copy() {
    if [[ $# -eq 0 ]]; then
        echo_bi "$BOLD_RED" "错误: 请提供文件路径" "Error: please provide a file path"
        echo_bi "$YELLOW" "用法: mt plaud copy <文件路径> [复制次数]" "Usage: mt plaud copy <file_path> [copy_count]"
        echo -e "${CYAN}示例: mt plaud copy file.ogg 100 / Example: mt plaud copy file.ogg 100${NC}"
        return 1
    fi

    run_python_script "plaud_copy_files.py" "$@"
}

# Plaud 工具：文件解密
mt_plaud_decrypt() {
    if [[ $# -lt 1 ]]; then
        echo_bi "$BOLD_RED" "错误: 缺少参数" "Error: missing arguments"
        echo_bi "$YELLOW" "用法: mt plaud decrypt <加密文件路径> [-o|--output-dir <输出目录>]" "Usage: mt plaud decrypt <encrypted_file_path> [-o|--output-dir <output_dir>]"
        echo ""
        echo_bi "$YELLOW" "示例:" "Examples:"
        echo -e "${CYAN}  mt plaud decrypt encrypted.plaud${NC}"
        echo -e "${CYAN}  mt plaud decrypt encrypted.plaud -o /path/to/output${NC}"
        echo -e "${CYAN}  mt plaud decrypt encrypted.plaud --output-dir /path/to/output${NC}"
        return 1
    fi

    run_python_script "plaudDecryptor.py" "$@"
}
