# MT - 多仓库 Git 管理工具

MT (Multi-repo Tool) 是一个用于管理多仓库 Git 操作的工具。

## 安装

### 方式一：克隆仓库

```bash
git clone <mt-repo-url> /path/to/mt
cd /path/to/mt
./bin/install-mt.sh
```

### 方式二：直接使用

```bash
# 将 mt 目录添加到 PATH
export PATH="/path/to/mt/bin:$PATH"
```

## 快速开始

1. **安装工具**：
   ```bash
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

