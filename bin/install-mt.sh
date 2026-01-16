#!/bin/bash
#
# MT 安装脚本
# 自动将 mt 工具添加到 PATH
#
# 使用方式：
#   1. 从 GitHub 直接安装：
#      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanatozhang/mt/refs/heads/main/bin/install-mt.sh)"
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

# GitHub 仓库信息
GITHUB_REPO="git@github.com:sanatozhang/mt.git"
GITHUB_BRANCH="main"
MT_REPO_NAME="mt"

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
    local install_dir="${HOME}/.local/share/${MT_REPO_NAME}"
    
    echo -e "${BLUE}正在从 GitHub 克隆 mt 仓库...${NC}"
    echo -e "${CYAN}仓库地址: ${GITHUB_REPO}${NC}"
    echo -e "${CYAN}安装目录: ${install_dir}${NC}"
    echo ""
    
    # 如果目录已存在，检查是否是 Git 仓库
    if [[ -d "$install_dir" ]]; then
        if [[ -d "${install_dir}/.git" ]]; then
            echo -e "${YELLOW}检测到已存在的 Git 仓库: ${install_dir}${NC}"
            echo -e "${BLUE}可以使用 'mt upgrade' 命令更新到最新版本${NC}"
            echo -e "${BLUE}或删除目录后重新安装以获取最新代码${NC}"
            read -p "是否删除并重新克隆? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${BLUE}正在删除旧目录...${NC}"
                rm -rf "$install_dir"
            else
                echo -e "${BLUE}使用现有仓库${NC}"
                echo "$install_dir"
                return 0
            fi
        else
            echo -e "${YELLOW}检测到已存在的目录（非 Git 仓库）: ${install_dir}${NC}"
            read -p "是否删除并重新克隆? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$install_dir"
            else
                echo -e "${RED}错误: 目录已存在且不是 Git 仓库${NC}"
                return 1
            fi
        fi
    fi
    
    # 优先尝试使用 SSH 克隆仓库
    echo -e "${BLUE}尝试使用 SSH 方式克隆...${NC}"
    if git clone -b "$GITHUB_BRANCH" "$GITHUB_REPO" "$install_dir" 2>&1; then
        echo -e "${GREEN}✓ 仓库克隆成功（使用 SSH）${NC}"
        echo -e "${BLUE}源码已保存到: ${install_dir}${NC}"
        echo -e "${BLUE}后续可以使用 'mt upgrade' 命令更新${NC}"
        echo "$install_dir"
        return 0
    else
        # SSH 克隆失败，回退到 HTTPS 方式
        echo -e "${YELLOW}SSH 克隆失败，尝试使用 HTTPS 方式...${NC}"
        local https_repo="https://github.com/sanatozhang/mt.git"
        if git clone -b "$GITHUB_BRANCH" "$https_repo" "$install_dir" 2>&1; then
            echo -e "${GREEN}✓ 仓库克隆成功（使用 HTTPS）${NC}"
            echo -e "${BLUE}源码已保存到: ${install_dir}${NC}"
            echo -e "${BLUE}后续可以使用 'mt upgrade' 命令更新${NC}"
            echo -e "${YELLOW}提示: 配置 SSH 密钥后可使用更快的 SSH 方式${NC}"
            echo "$install_dir"
            return 0
        else
            echo -e "${RED}错误: 克隆仓库失败${NC}"
            echo -e "${YELLOW}请检查：${NC}"
            echo -e "${YELLOW}  1. 网络连接是否正常${NC}"
            echo -e "${YELLOW}  2. Git 是否已安装${NC}"
            echo -e "${YELLOW}  3. 是否有访问仓库的权限${NC}"
            return 1
        fi
    fi
}

# 获取脚本所在目录
get_script_dir() {
    local script_path="${BASH_SOURCE[0]}"
    
    # 如果是远程执行，返回克隆的目录
    if is_remote_execution; then
        local install_dir
        install_dir=$(clone_repository)
        if [[ $? -ne 0 ]]; then
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
MT_DIR="$(cd "${BIN_DIR}/.." && pwd)"
MT_SCRIPT="${BIN_DIR}/mt"

# 检查 mt 脚本是否存在
if [[ ! -f "$MT_SCRIPT" ]]; then
    echo -e "${RED}错误: mt 脚本不存在: ${MT_SCRIPT}${NC}"
    if is_remote_execution; then
        echo -e "${YELLOW}请检查 GitHub 仓库是否可访问${NC}"
    else
        echo -e "${YELLOW}请确保在 mt/bin/ 目录下执行此脚本${NC}"
    fi
    exit 1
fi

# 检查是否可执行
if [[ ! -x "$MT_SCRIPT" ]]; then
    echo -e "${YELLOW}添加执行权限...${NC}"
    chmod +x "$MT_SCRIPT"
fi

# 检测 Shell 类型
detect_shell() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
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
        echo -e "${YELLOW}检测到 mt 已安装: ${installed_path}${NC}"
        read -p "是否重新安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}取消安装${NC}"
            exit 0
        fi
    fi
}

# 安装到系统路径（需要 sudo）
install_system_wide() {
    echo -e "${BLUE}尝试安装到系统路径...${NC}"
    if sudo ln -sf "$MT_SCRIPT" /usr/local/bin/mt 2>/dev/null; then
        echo -e "${GREEN}✓ 已安装到 /usr/local/bin/mt${NC}"
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
        echo -e "${RED}错误: 无法检测 Shell 类型${NC}"
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
    ln -sf "$MT_SCRIPT" "$link_path"
    
    # 检查 PATH 是否已包含
    if [[ ":$PATH:" != *":${bin_dir}:"* ]]; then
        # 添加到 Shell 配置
        local export_line="export PATH=\"\${PATH}:${bin_dir}\""
        
        # 检查是否已存在
        if ! grep -q "\.local/bin" "$config_file" 2>/dev/null; then
            echo "" >> "$config_file"
            echo "# MT Tool" >> "$config_file"
            echo "$export_line" >> "$config_file"
            echo -e "${GREEN}✓ 已添加到 ${config_file}${NC}"
        else
            echo -e "${YELLOW}⚠  PATH 配置已存在${NC}"
        fi
    fi
    
    echo -e "${GREEN}✓ 已安装到 ${link_path}${NC}"
    echo -e "${BLUE}请运行以下命令使配置生效:${NC}"
    echo -e "${CYAN}  source ${config_file}${NC}"
    echo -e "${CYAN}  或重新打开终端${NC}"
}

# 主安装流程
main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  MT - Multi-repo Tool 安装程序${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 检查是否已安装
    check_installed
    
    # 检测 Shell
    local shell_type
    shell_type=$(detect_shell)
    echo -e "${BLUE}检测到 Shell: ${shell_type}${NC}"
    
    # 尝试系统级安装
    if install_system_wide; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  安装成功！${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo -e "${BLUE}现在可以使用 mt 命令了:${NC}"
        echo -e "${CYAN}  mt --version${NC}"
        echo -e "${CYAN}  mt help${NC}"
        return 0
    fi
    
    # 回退到用户级安装
    echo -e "${YELLOW}系统级安装失败，使用用户级安装...${NC}"
    echo ""
    
    if install_user_path "$shell_type"; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  安装成功！${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo -e "${BLUE}请运行以下命令使配置生效:${NC}"
        local config_file
        config_file=$(get_shell_config "$shell_type")
        echo -e "${CYAN}  source ${config_file}${NC}"
        echo ""
        echo -e "${BLUE}然后可以使用 mt 命令:${NC}"
        echo -e "${CYAN}  mt --version${NC}"
        echo -e "${CYAN}  mt help${NC}"
    else
        echo -e "${RED}安装失败${NC}"
        exit 1
    fi
}

# 执行安装
main "$@"

