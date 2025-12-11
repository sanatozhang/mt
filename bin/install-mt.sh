#!/bin/bash
#
# MT 安装脚本
# 自动将 mt 工具添加到 PATH
#

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 获取脚本所在目录
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MT_DIR="$(cd "${BIN_DIR}/.." && pwd)"
MT_SCRIPT="${BIN_DIR}/mt"

# 检查 mt 脚本是否存在
if [[ ! -f "$MT_SCRIPT" ]]; then
    echo -e "${RED}错误: mt 脚本不存在: ${MT_SCRIPT}${NC}"
    echo -e "${YELLOW}请确保在 mt/bin/ 目录下执行此脚本${NC}"
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

