# MT - 多仓库 Git 管理工具

MT (Multi-repo Tool) 是一个用于管理多仓库 Git 操作的工具。

## 安装

### 方式一：一键安装（推荐）

从 GitHub 直接安装，无需手动克隆仓库：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanatozhang/mt/refs/heads/main/bin/install-mt.sh)"
```

安装脚本会自动：
1. 从 GitHub 克隆 mt 仓库源码到 `~/.local/share/mt`（使用 SSH 方式，优先尝试）
2. 将 `mt` 命令添加到系统 PATH
3. 配置 Shell 环境（自动检测 zsh/bash）

**注意**：
- 源码会完整克隆到本地，方便后续使用 `mt upgrade` 命令更新
- 如果 SSH 方式失败，会自动回退到 HTTPS 方式
- 如果目录已存在，会提示是否重新克隆

安装完成后，重新打开终端或运行 `source ~/.zshrc`（或 `source ~/.bashrc`）即可使用。

### 方式二：手动克隆安装

如果你已经克隆了仓库，可以直接运行安装脚本：

```bash
# 使用 SSH 方式（推荐）
git clone git@github.com:sanatozhang/mt.git
cd mt
./bin/install-mt.sh

# 或使用 HTTPS 方式
git clone https://github.com/sanatozhang/mt.git
cd mt
./bin/install-mt.sh
```

### 方式三：直接使用（不安装）

如果你不想安装到系统，可以直接使用：

```bash
# 将 mt 目录添加到 PATH
export PATH="/path/to/mt/bin:$PATH"
```

## 快速开始

1. **安装工具**（选择一种方式）：
   ```bash
   # 方式一：一键安装（推荐）
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanatozhang/mt/refs/heads/main/bin/install-mt.sh)"
   
   # 方式二：如果已克隆仓库
   ./bin/install-mt.sh
   ```

2. **在项目中使用**：
   ```bash
   # 进入你的项目目录
   cd /path/to/your/project
   
   # 初始化配置（自动从 mt 仓库复制或生成默认配置）
   mt init
   
   # 使用工具
   mt checkout -b feature/new-feature  # 所有仓库切换分支
   mt status                            # 查看所有仓库状态
   mt build cn -r                       # 构建 CN release 包
   mt install global                    # 构建并安装到设备
   ```

3. **更新工具**：
   ```bash
   mt upgrade
   ```

## 目录结构

```
mt/
├── bin/                    # 脚本目录
│   ├── mt                  # 主工具脚本
│   └── install-mt.sh      # 安装脚本
└── doc/                    # 文档目录
    ├── README.md           # 使用文档
    └── TECHNICAL_DESIGN.md # 技术方案
```

## 详细文档

- [使用文档](doc/README.md) - 完整的使用说明和示例
- [技术方案](doc/TECHNICAL_DESIGN.md) - 技术架构和实现细节

## 升级

使用 `mt upgrade` 命令可以更新工具到最新版本：

```bash
mt upgrade
```

该命令会：
1. 从远程仓库获取最新更新
2. 显示更新内容
3. 确认后执行更新

