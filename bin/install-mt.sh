#!/bin/bash
#
# MT 安装脚本
# 自动将 mt 工具添加到 PATH
#
# 使用方式：
#   1. 从 GitHub 直接安装：
#      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanatozhang/mt/main/bin/install-mt.sh)"
#   2. 在已克隆的仓库中安装：
#      ./bin/install-mt.sh
#

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 双语输出: 中文一行 + 英文一行，共用同一颜色
echo_bi() {
    local color="$1" zh="$2" en="$3"
    echo -e "${color}${zh}${NC}"
    echo -e "${color}${en}${NC}"
}

# 同上，输出到 stderr
echo_bi_err() {
    local color="$1" zh="$2" en="$3"
    echo -e "${color}${zh}${NC}" >&2
    echo -e "${color}${en}${NC}" >&2
}

# GitHub 仓库信息
GITHUB_REPO="${MT_GITHUB_REPO:-git@github.com:sanatozhang/mt.git}"
GITHUB_HTTPS_REPO="${MT_GITHUB_HTTPS_REPO:-https://github.com/sanatozhang/mt.git}"
GITHUB_BRANCH="${MT_GITHUB_BRANCH:-main}"
MT_REPO_NAME="mt"
INSTALL_DIR="${MT_INSTALL_DIR:-${HOME}/.local/share/${MT_REPO_NAME}}"

# 检测是否是从远程 URL 直接执行的
is_remote_execution() {
    # 获取脚本的实际路径
    local script_path="${BASH_SOURCE[0]:-}"
    
    # 如果脚本路径为空或不存在，可能是远程执行
    if [[ -z "$script_path" ]] || [[ ! -f "$script_path" ]]; then
        return 0
    fi
    
    # 如果脚本路径包含 /dev/fd/ 或 /tmp/，可能是通过 curl 下载执行的
    if [[ "$script_path" == *"/dev/fd/"* ]] || [[ "$script_path" == *"/tmp/"* ]]; then
        return 0
    fi
    
    # 检查脚本所在目录是否包含 "mt" 目录结构（本地安装应该有 bin/mt 文件）
    local script_dir
    script_dir="$(cd "$(dirname "$script_path")" 2>/dev/null && pwd)" || return 0
    local mt_script="${script_dir}/mt"
    
    # 如果同目录下没有 mt 脚本，可能是远程执行
    if [[ ! -f "$mt_script" ]]; then
        return 0
    fi
    
    return 1
}

# 从 GitHub 克隆仓库
clone_repository() {
    local install_dir="${INSTALL_DIR}"
    
    echo_bi_err "$BLUE" "正在从 GitHub 克隆 mt 仓库..." "Cloning the mt repository from GitHub..."
    echo_bi_err "$CYAN" "仓库地址: ${GITHUB_REPO}" "Repository: ${GITHUB_REPO}"
    echo_bi_err "$CYAN" "安装目录: ${install_dir}" "Install directory: ${install_dir}"
    echo "" >&2

    # 如果目录已存在，检查是否是 Git 仓库
    if [[ -d "$install_dir" ]]; then
        if [[ -d "${install_dir}/.git" ]]; then
            echo_bi_err "$YELLOW" "检测到已存在的 Git 仓库: ${install_dir}" "Found an existing Git repository: ${install_dir}"
            echo_bi_err "$BLUE" "可以使用 'mt upgrade' 命令更新到最新版本" "You can run 'mt upgrade' to update to the latest version"
            echo_bi_err "$BLUE" "或删除目录后重新安装以获取最新代码" "Or delete the directory and reinstall to get the latest code"
            read -p "是否删除并重新克隆 / Delete and re-clone? (y/N): " -n 1 -r
            echo >&2
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo_bi_err "$BLUE" "正在删除旧目录..." "Removing the old directory..."
                rm -rf "$install_dir"
            else
                echo_bi_err "$BLUE" "使用现有仓库" "Using the existing repository"
                echo "$install_dir"
                return 0
            fi
        else
            echo_bi_err "$YELLOW" "检测到已存在的目录（非 Git 仓库）: ${install_dir}" "Found an existing directory (not a Git repository): ${install_dir}"
            read -p "是否删除并重新克隆 / Delete and re-clone? (y/N): " -n 1 -r
            echo >&2
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$install_dir"
            else
                echo_bi_err "$RED" "错误: 目录已存在且不是 Git 仓库" "Error: the directory already exists and is not a Git repository"
                return 1
            fi
        fi
    fi

    # 优先尝试使用 SSH 克隆仓库
    echo_bi_err "$BLUE" "尝试使用 SSH 方式克隆..." "Trying to clone via SSH..."
    if git clone -b "$GITHUB_BRANCH" "$GITHUB_REPO" "$install_dir" >&2; then
        echo_bi_err "$GREEN" "✓ 仓库克隆成功（使用 SSH）" "✓ Repository cloned successfully (via SSH)"
        echo_bi_err "$BLUE" "源码已保存到: ${install_dir}" "Source saved to: ${install_dir}"
        echo_bi_err "$BLUE" "后续可以使用 'mt upgrade' 命令更新" "You can run 'mt upgrade' later to update"
        echo "$install_dir"
        return 0
    else
        # SSH 克隆失败，回退到 HTTPS 方式
        echo_bi_err "$YELLOW" "SSH 克隆失败，尝试使用 HTTPS 方式..." "SSH clone failed, trying HTTPS..."
        if git clone -b "$GITHUB_BRANCH" "$GITHUB_HTTPS_REPO" "$install_dir" >&2; then
            echo_bi_err "$GREEN" "✓ 仓库克隆成功（使用 HTTPS）" "✓ Repository cloned successfully (via HTTPS)"
            echo_bi_err "$BLUE" "源码已保存到: ${install_dir}" "Source saved to: ${install_dir}"
            echo_bi_err "$BLUE" "后续可以使用 'mt upgrade' 命令更新" "You can run 'mt upgrade' later to update"
            echo_bi_err "$YELLOW" "提示: 配置 SSH 密钥后可使用更快的 SSH 方式" "Tip: set up an SSH key to use the faster SSH method"
            echo "$install_dir"
            return 0
        else
            echo_bi_err "$RED" "错误: 克隆仓库失败" "Error: failed to clone the repository"
            echo_bi_err "$YELLOW" "请检查：" "Please check:"
            echo_bi_err "$YELLOW" "  1. 网络连接是否正常" "  1. Whether your network connection is working"
            echo_bi_err "$YELLOW" "  2. Git 是否已安装" "  2. Whether Git is installed"
            echo_bi_err "$YELLOW" "  3. 是否有访问仓库的权限" "  3. Whether you have access to the repository"
            echo_bi_err "$YELLOW" "如果一键安装仍失败，请回退到手动方式：" "If the one-line install still fails, fall back to manual install:"
            echo -e "${CYAN}  git clone ${GITHUB_HTTPS_REPO} && cd ${MT_REPO_NAME} && ./bin/install-mt.sh${NC}" >&2
            return 1
        fi
    fi
}

# 获取脚本所在目录
get_script_dir() {
    local script_path="${BASH_SOURCE[0]:-$0}"
    
    # 如果是远程执行，返回克隆的目录
    if is_remote_execution; then
        local install_dir
        if ! install_dir=$(clone_repository); then
            exit 1
        fi
        echo "${install_dir}/bin"
        return 0
    fi
    
    # 本地执行，使用脚本所在目录
    echo "$(cd "$(dirname "$script_path")" && pwd)"
}

# 初始化路径变量
BIN_DIR=$(get_script_dir)

# 验证 BIN_DIR 是否有效
if [[ -z "$BIN_DIR" ]]; then
    echo_bi "$RED" "错误: 无法确定脚本目录" "Error: could not determine the script directory"
    exit 1
fi

# 如果是远程执行，BIN_DIR 应该是 ${install_dir}/bin
# 如果 bin 目录不存在，从父目录创建
if [[ ! -d "$BIN_DIR" ]]; then
    parent_dir="$(dirname "$BIN_DIR")"
    if [[ -d "$parent_dir" ]]; then
        # 父目录存在，创建 bin 目录
        mkdir -p "$BIN_DIR" 2>/dev/null || {
            echo_bi "$RED" "错误: 无法创建目录: ${BIN_DIR}" "Error: could not create directory: ${BIN_DIR}"
            exit 1
        }
    else
        echo_bi "$RED" "错误: 父目录不存在: ${parent_dir}" "Error: parent directory does not exist: ${parent_dir}"
        echo_bi "$YELLOW" "请检查克隆是否成功" "Please check whether the clone succeeded"
        exit 1
    fi
fi

# 安全地获取 MT_DIR（即使 bin 目录不存在，也能获取父目录）
MT_DIR="$(cd "$(dirname "$BIN_DIR")" && pwd)"
MT_SCRIPT="${BIN_DIR}/mt"

# 检查 mt 脚本是否存在
if [[ ! -f "$MT_SCRIPT" ]]; then
    echo_bi "$RED" "错误: mt 脚本不存在: ${MT_SCRIPT}" "Error: mt script not found: ${MT_SCRIPT}"
    if is_remote_execution; then
        echo_bi "$YELLOW" "请检查 GitHub 仓库是否可访问" "Please check whether the GitHub repository is reachable"
    else
        echo_bi "$YELLOW" "请确保在 mt/bin/ 目录下执行此脚本" "Please make sure you run this script from mt/bin/"
    fi
    exit 1
fi

# 检查是否可执行
if [[ ! -x "$MT_SCRIPT" ]]; then
    echo_bi "$YELLOW" "添加执行权限..." "Adding execute permission..."
    chmod +x "$MT_SCRIPT"
fi

# 检测 Shell 类型
detect_shell() {
    local shell_name="${SHELL##*/}"
    if [[ "$shell_name" == "zsh" ]]; then
        echo "zsh"
    elif [[ "$shell_name" == "bash" ]]; then
        echo "bash"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        echo "zsh"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        echo "bash"
    else
        echo "unknown"
    fi
}

# 获取 Shell 配置文件路径
get_shell_config() {
    local shell_type="$1"
    case "$shell_type" in
        zsh)
            echo "${HOME}/.zshrc"
            ;;
        bash)
            echo "${HOME}/.bashrc"
            ;;
        *)
            echo ""
            ;;
    esac
}

# 检查是否已安装
check_installed() {
    if command -v mt &> /dev/null; then
        local installed_path
        installed_path=$(command -v mt)
        echo_bi "$YELLOW" "检测到 mt 已安装: ${installed_path}" "mt is already installed: ${installed_path}"
        read -p "是否重新安装 / Reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo_bi "$BLUE" "取消安装" "Installation cancelled"
            exit 0
        fi
    fi
}

# 安装到系统路径（需要 sudo）
install_system_wide() {
    echo_bi "$BLUE" "尝试安装到系统路径..." "Trying to install to a system path..."
    if sudo ln -sf "$MT_SCRIPT" /usr/local/bin/mt 2>/dev/null; then
        echo_bi "$GREEN" "✓ 已安装到 /usr/local/bin/mt" "✓ Installed to /usr/local/bin/mt"
        return 0
    else
        return 1
    fi
}

# 安装到用户 PATH
install_user_path() {
    local shell_type="$1"
    local config_file
    config_file=$(get_shell_config "$shell_type")

    if [[ -z "$config_file" ]]; then
        echo_bi "$RED" "错误: 无法检测 Shell 类型" "Error: could not detect the shell type"
        return 1
    fi

    # 创建配置目录（如果不存在）
    local bin_dir="${HOME}/.local/bin"
    mkdir -p "$bin_dir"

    # 创建符号链接
    local link_path="${bin_dir}/mt"
    if [[ -L "$link_path" ]]; then
        rm "$link_path"
    fi
    if ! ln -sf "$MT_SCRIPT" "$link_path"; then
        echo_bi "$RED" "错误: 无法创建符号链接: ${link_path}" "Error: could not create symlink: ${link_path}"
        return 1
    fi

    # 检查配置文件中是否已包含 .local/bin 的 PATH 配置
    local path_added=false
    if ! grep -q "\.local/bin" "$config_file" 2>/dev/null; then
        # 配置文件中没有，添加 PATH 配置
        local export_line="export PATH=\"\${PATH}:${bin_dir}\""
        echo "" >> "$config_file"
        echo "# MT Tool" >> "$config_file"
        echo "$export_line" >> "$config_file"
        echo_bi "$GREEN" "✓ 已添加到 ${config_file}" "✓ Added to ${config_file}"
        path_added=true
    else
        echo_bi "$YELLOW" "⚠  PATH 配置已存在（可能由其他工具添加）" "⚠  PATH entry already exists (possibly added by another tool)"
        path_added=true
    fi

    # 检查当前 PATH 是否包含（用于提示）
    if [[ ":$PATH:" != *":${bin_dir}:"* ]]; then
        if [[ "$path_added" == "true" ]]; then
            echo_bi "$YELLOW" "⚠  当前 PATH 中不包含 ${bin_dir}，需要重新加载配置" "⚠  Current PATH does not include ${bin_dir}; reload your shell config"
        fi
    fi

    echo_bi "$GREEN" "✓ 已安装到 ${link_path}" "✓ Installed to ${link_path}"
    echo_bi "$BLUE" "请运行以下命令使配置生效:" "Run the following command to apply the change:"
    echo -e "${CYAN}  source ${config_file}${NC}"
    echo_bi "$CYAN" "  或重新打开终端" "  Or reopen your terminal"
}

# 主安装流程
main() {
    echo -e "${CYAN}========================================${NC}"
    echo_bi "$CYAN" "  MT - Multi-repo Tool 安装程序" "  MT - Multi-repo Tool Installer"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    # 检查是否已安装
    check_installed

    # 检测 Shell
    local shell_type
    shell_type=$(detect_shell)
    echo_bi "$BLUE" "检测到 Shell: ${shell_type}" "Detected shell: ${shell_type}"

    # 检测是否是远程执行（远程执行时跳过系统级安装，直接使用用户级安装）
    local is_remote=false
    if [[ ! -f "${BASH_SOURCE[0]:-$0}" ]] || [[ "${BASH_SOURCE[0]:-$0}" == *"/dev/fd/"* ]] || [[ "${BASH_SOURCE[0]:-$0}" == *"/tmp/"* ]]; then
        is_remote=true
    elif [[ -f "${BASH_SOURCE[0]:-$0}" ]]; then
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || true
        if [[ -n "$script_dir" ]] && [[ ! -f "${script_dir}/mt" ]]; then
            is_remote=true
        fi
    fi

    # 如果是远程执行，直接使用用户级安装（不需要密码）
    if [[ "$is_remote" == "true" ]]; then
        echo_bi "$BLUE" "检测到远程安装，使用用户级安装（无需密码）..." "Remote install detected, using user-level install (no password needed)..."
        echo ""

        if install_user_path "$shell_type"; then
            echo ""
            echo -e "${GREEN}========================================${NC}"
            echo_bi "$GREEN" "  安装成功！" "  Installation succeeded!"
            echo -e "${GREEN}========================================${NC}"
            echo ""
            echo_bi "$BLUE" "请运行以下命令使配置生效:" "Run the following command to apply the change:"
            local config_file
            config_file=$(get_shell_config "$shell_type")
            echo -e "${CYAN}  source ${config_file}${NC}"
            echo ""
            echo_bi "$BLUE" "然后可以使用 mt 命令:" "Then you can use the mt command:"
            echo -e "${CYAN}  mt --version${NC}"
            echo -e "${CYAN}  mt help${NC}"
        else
            echo_bi "$RED" "安装失败" "Installation failed"
            exit 1
        fi
        return 0
    fi

    # 本地执行：尝试系统级安装（需要密码）
    if install_system_wide; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo_bi "$GREEN" "  安装成功！" "  Installation succeeded!"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo_bi "$BLUE" "现在可以使用 mt 命令了:" "You can now use the mt command:"
        echo -e "${CYAN}  mt --version${NC}"
        echo -e "${CYAN}  mt help${NC}"
        return 0
    fi

    # 回退到用户级安装
    echo_bi "$YELLOW" "系统级安装失败，使用用户级安装..." "System-level install failed, falling back to user-level install..."
    echo ""

    if install_user_path "$shell_type"; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo_bi "$GREEN" "  安装成功！" "  Installation succeeded!"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo_bi "$BLUE" "请运行以下命令使配置生效:" "Run the following command to apply the change:"
        local config_file
        config_file=$(get_shell_config "$shell_type")
        echo -e "${CYAN}  source ${config_file}${NC}"
        echo ""
        echo_bi "$BLUE" "然后可以使用 mt 命令:" "Then you can use the mt command:"
        echo -e "${CYAN}  mt --version${NC}"
        echo -e "${CYAN}  mt help${NC}"
    else
        echo_bi "$RED" "安装失败" "Installation failed"
        exit 1
    fi
}

# 执行安装
main "$@"
