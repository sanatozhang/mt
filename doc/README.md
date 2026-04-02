# MT - 多仓库 Git 管理工具

## 简介

`mt` (Multi-repo Tool) 是一个用于管理多仓库 Git 操作的工具，可以同时在多个 Git 仓库中执行相同的 Git 命令，简化多仓库项目的开发流程。

## 功能特性

- ✅ 统一管理多个 Git 仓库
- ✅ 支持所有常用 Git 命令
- ✅ 串行执行，输出清晰
- ✅ 配置文件化管理，易于扩展
- ✅ 自动错误处理和汇总
- ✅ 彩色输出，易于阅读

## 安装

### 首次安装

```bash
# 在项目根目录执行
./mt/bin/install-mt.sh
```

安装脚本会自动：
1. 检测你的 Shell 类型（bash/zsh）
2. 将 `mt` 添加到 PATH
3. 创建全局可用的 `mt` 命令

### 验证安装

```bash
mt --version
```

## 配置

### 初始化开发环境

首次使用前，先初始化本地开发环境并克隆代码：

```bash
mt init
```

`mt init` 会依次执行：
- 检测是否安装 Homebrew；未安装则提示先安装
- 检测是否安装 FVM；未安装则通过 Homebrew 安装
- 使用 FVM 安装 Flutter `3.38.9`
- 执行 `mt clone` 克隆 Plaud-App 仓库

克隆完成后，`mt` 会在项目根目录按需自动生成 `.mt-config.yaml`。

### 手动编辑配置

配置文件位于项目根目录：`.mt-config.yaml`

```yaml
repositories:
  - name: plaud-flutter-cn
    path: plaud-flutter-cn
    url: git@github.com:Plaud-AI/plaud-flutter-cn.git
  - name: plaud-flutter-global
    path: plaud-flutter-global
    url: git@github.com:Plaud-AI/plaud-flutter-global.git
  # ... 更多仓库
```

### 添加新仓库

编辑 `.mt-config.yaml`，添加新的仓库配置：

```yaml
repositories:
  - name: new-repo
    path: new-repo
    url: git@github.com:org/new-repo.git
```

## 使用方法

### 基本语法

```bash
mt <git-command> [options]
```

### 常用命令

#### 分支操作（所有分支相关命令支持多个 module）

```bash
# 创建并切换新分支（所有仓库）
mt checkout -b feature/new-feature

# 切换分支（所有仓库）
mt checkout main

# 查看所有仓库的分支
mt branch

# 查看分支详情
mt branch -a

# 合并分支（所有仓库）
mt merge develop

# 变基（所有仓库）
mt rebase main

# 选择提交（所有仓库）
mt cherry-pick <commit>

# 暂存更改（所有仓库）
mt stash

# 恢复暂存（所有仓库）
mt stash pop

# 删除本地分支
mt delete                    # 删除最近没有使用的3个分支（分支数需>=8）
mt delete -a                 # 删除所有分支（除了当前分支和 main/master）
```

**注意**：以下命令会在所有配置的仓库中执行：
- `checkout`, `branch`, `switch` - 分支切换和查看
- `merge`, `rebase`, `cherry-pick` - 分支合并和变基
- `status`, `stash` - 状态查看和暂存

其他命令（如 `commit`, `push`, `pull`, `log`, `diff`）只在当前仓库执行。

#### 提交操作

```bash
# 添加文件
mt add .

# 提交代码
mt commit -m "Add new feature"

# 查看状态
mt status

# 查看详细状态
mt status -s
```

#### 推送和拉取

```bash
# 推送到远程
mt push origin feature/new-feature

# 拉取更新
mt pull origin main

# 获取更新（不合并）
mt fetch
```


### 工具命令

```bash
# 列出所有配置的仓库
mt list

# 初始化本地开发环境并克隆代码
mt init

# 编辑配置文件
mt config

# 删除本地分支
mt delete                    # 删除最近没有使用的3个分支（分支数需>=8）
mt delete -a                 # 删除所有分支（除了当前分支和 main/master）

# 清除缓存（Flutter、Android、iOS）
mt clean

# 设置 GitHub token（用于创建 PR）
mt set-github-token <token>

# 更新 mt 工具到最新版本
mt upgrade

# 查看帮助
mt help
```

### 构建命令

#### 预构建

```bash
# 构建 Flutter 模块（构建 Android 包前准备）
mt prebuild
```

#### 基础构建

```bash
# 默认构建 global debug
mt build                                 # Global debug（默认）
mt build -r                              # Global release

# CN 版本构建（默认构建 debug）
mt build cn                              # CN 官方渠道 debug（默认）
mt build cn -r                           # CN 官方渠道 release
mt build cn -d                           # CN 官方渠道 debug（显式指定）
mt build cn -c huawei -r                 # CN 华为渠道 release
mt build cn -a -r                        # CN 所有渠道 release

# Global 版本构建（默认构建 debug）
mt build global                          # Global debug（默认）
mt build global -r                       # Global release
mt build global -d                       # Global debug（显式指定）
```

#### 安装到设备

```bash
# 构建并安装到连接的 Android 设备
mt install                               # Global debug（默认）
mt install -r                            # Global release
mt install cn                           # CN debug
mt install cn -r                         # CN release
mt install cn -c huawei -r               # CN 华为渠道 release

# 注意：
# - install 命令不会执行 clean，直接构建以加快速度
# - 需要设备已通过 USB 连接并启用 USB 调试
# - 参数与 build 命令相同
```

#### 清除缓存

```bash
# 清除 Flutter、Android 和 iOS 的缓存
mt clean

# 清除的缓存包括：
# - Flutter: .dart_tool, .flutter-plugins, build 目录
# - Android: .gradle, app/build, build 目录
# - iOS: PLAUD/build, Pods, DerivedData 目录
```

#### 编译检查

```bash
# 同时构建 CN 和 Global 版本（用于 push 前检查，默认 debug）
mt build:check                           # 构建 debug 版本
mt build:check -r                        # 构建 release 版本
mt build:check -d                        # 构建 debug 版本（显式指定）
```

#### 构建选项说明

**短参数支持**：
- `-d`, `--d`, `--debug`: 构建 Debug 包（默认）
- `-r`, `--r`, `--release`: 构建 Release 包
- `-p`, `--p`, `--profile`: 构建 Profile 包（未来支持）
- `-c`, `--c`, `--channel <name>`: CN 版本指定渠道
  - 支持的渠道：`official`, `huawei`, `xiaomi`, `oppo`, `vivo`, `honor`, `yingyongbao`
- `-a`, `--a`, `--all`: CN 版本构建所有渠道（仅支持 release）

#### 构建流程

1. **预构建**（可选）：执行 `mt prebuild` 构建 Flutter 模块
2. **切换 Flavor**：自动切换 Flavor（使用 `switch_flavor.sh`）
3. **Gradle 构建**：执行对应的 Gradle 构建任务
4. **日志记录**：所有构建过程记录到 `mt/logs/` 目录
5. **显示结果**：显示构建结果和 APK 文件位置

#### 日志系统

所有构建过程都会记录到日志文件：
- 日志目录：`mt/logs/`
- 日志文件命名：`build_{market}_{build_type}_{timestamp}.log`
- 日志内容：构建参数、执行过程、错误信息、APK 位置

查看日志：
```bash
ls mt/logs/
tail -f mt/logs/build_cn_debug_*.log
```

#### 使用建议

**完整构建流程**：

```bash
# 1. 预构建 Flutter 模块
mt prebuild

# 2. 构建 Android 包
mt build cn -r                           # 构建 CN release
# 或
mt build global -r                       # 构建 Global release
```

**Push 代码前检查**：

```bash
# 1. 编译检查（同时构建 CN 和 Global）
mt build:check -r

# 2. 如果构建成功，再 push
mt push origin feature/new-feature
```

## 执行流程

`mt` 采用**串行执行**方式：

1. 按配置文件顺序，逐个仓库执行命令
2. 每个仓库执行完成后显示结果
3. 如果某个仓库执行失败，会继续执行其他仓库
4. 最后汇总所有执行结果

### 输出示例

```
[1/5] plaud-flutter-cn
  ✓ 已切换到分支: feature/new-feature

[2/5] plaud-flutter-global
  ✓ 已切换到分支: feature/new-feature

[3/5] plaud-flutter-common
  ✓ 已切换到分支: feature/new-feature

[4/5] plaud-android
  ✓ 已切换到分支: feature/new-feature

[5/5] plaud-ios
  ✓ 已切换到分支: feature/new-feature

✅ 所有仓库执行成功 (5/5)
```

## 错误处理

如果某个仓库执行失败：

```
[1/5] plaud-flutter-cn
  ✓ 成功

[2/5] plaud-flutter-global
  ✗ 失败: 分支已存在

[3/5] plaud-flutter-common
  ✓ 成功

...

⚠️  部分仓库执行失败 (1/5)
失败仓库: plaud-flutter-global
```

## 注意事项

1. **确保仓库已初始化**：使用前确保所有子模块已初始化
   ```bash
   git submodule update --init --recursive
   ```

2. **工作目录**：
   - 可以在项目根目录或任何子目录执行 `mt` 命令
   - 分支相关命令（`checkout`, `branch`, `status` 等）会在所有仓库执行
   - 其他命令（`commit`, `push`, `log` 等）只在当前仓库执行

3. **配置文件位置**：`mt` 会自动查找项目根目录的 `.mt-config.yaml`

4. **Git 命令参数**：所有 Git 命令的参数都直接传递给底层 Git 命令

5. **不支持的命令**：如果输入了不支持的命令，会显示错误提示和帮助信息

6. **install 命令**：不会执行 clean，直接构建以加快安装速度

7. **代码变更检查**：
   - `mt push` 会自动跳过没有代码变更的仓库
   - `mt pr` 会自动跳过没有代码变更的仓库
   - `mt commit` 会自动跳过没有暂存修改的仓库

## 卸载

如果需要卸载 `mt`：

```bash
# 编辑 ~/.zshrc 或 ~/.bashrc，删除相关行
# 或运行
rm /usr/local/bin/mt  # 如果使用了符号链接
```

## 故障排查

### 命令未找到

```bash
# 检查是否在 PATH 中
which mt

# 重新安装
./mt/bin/install-mt.sh
```

### 配置文件未找到

```bash
# 直接执行任意 mt 命令，工具会自动生成配置
mt list
```

### 仓库路径不存在

检查 `.mt-config.yaml` 中的路径是否正确，确保仓库已正确克隆。

### 更新工具

```bash
# 更新 mt 工具到最新版本
mt upgrade
```

如果更新失败，可以手动执行：
```bash
cd /path/to/mt
git pull
```

### PR 创建失败

```bash
# 检查 GitHub token 是否配置
cat github.token

# 或使用命令设置 token
mt set-github-token <your_token>
```

## PR 命令

### 创建 GitHub Pull Request

`mt pr` 命令可以为所有配置的仓库创建 GitHub Pull Request，并自动关联相关 PR。

#### 基本用法

```bash
# 为所有仓库创建 PR（目标分支: main，使用当前分支名作为标题）
mt pr

# 指定目标分支
mt pr -b develop

# 指定 PR 标题
mt pr -t "Add new feature"

# 指定 PR 标题和描述
mt pr -t "Fix bug" -d "修复了某个问题"

# 完整示例
mt pr -b main -t "Feature: Add new API" -d "添加了新的 API 接口"
```

#### PR 关联功能

当为多个仓库创建 PR 时，工具会自动：

1. **创建所有仓库的 PR**：按顺序为每个仓库创建 PR
2. **自动关联 PR**：在每个 PR 的描述中添加"相关 PR"部分
3. **列出所有相关链接**：显示其他仓库的 PR 链接，实现互相关联

**示例**：
- 如果为 `plaud-flutter-common`、`plaud-flutter-global`、`plaud-flutter-cn` 创建了 PR
- 每个 PR 的描述中都会包含：
  ```
  ## 相关 PR
  
  - [plaud-flutter-global](https://github.com/.../pull/123)
  - [plaud-flutter-cn](https://github.com/.../pull/124)
  ```

#### 配置 GitHub Token

创建 PR 需要 GitHub Personal Access Token，使用以下命令设置：

```bash
mt set-github-token <your_token>
```

Token 将保存到项目根目录的 `github.token` 文件中（该文件已添加到 `.gitignore`，不会被提交到 Git）。

**Token 读取优先级**：
1. `github.token` 文件（推荐）
2. 环境变量 `GITHUB_TOKEN`（向后兼容）
3. 配置文件 `.mt-config.yaml` 中的 `github_token`（向后兼容，不推荐）

#### 获取 GitHub Token

1. 访问 [GitHub Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens)
2. 点击 "Generate new token (classic)"
3. 选择权限：至少需要 `repo` 权限
4. 生成并复制 token
5. 使用 `mt set-github-token <your_token>` 命令设置

#### 使用流程示例

```bash
# 1. 创建分支并提交代码
mt checkout -b feature/new-feature
mt add .
mt commit -m "Add new feature"
mt push origin feature/new-feature

# 2. 创建 PR（所有仓库）
mt pr -t "Feature: Add new feature" -d "实现了新功能"

# 3. 所有仓库的 PR 会自动创建并关联
```

#### 注意事项

- 如果当前分支已经是目标分支，会跳过该仓库
- 如果分支不存在于远程，会跳过创建 PR
- 如果 PR 已存在，会返回已存在的 PR URL
- 新建 PR 默认创建为 **Draft（WIP）**，并自动：
  - 请求 **Copilot** 作为 reviewer（最佳努力）
  - 添加 label：`MT AUTO`
  - 已存在的 PR 不会被修改状态/标签/reviewer
- 如需指定 Copilot reviewer 登录名，可通过环境变量覆盖：`MT_COPILOT_REVIEWER=<login> mt pr`
- 需要确保所有仓库都已推送到远程

## 开发计划

- [ ] 支持 Profile 构建类型
- [ ] 支持仓库分组操作
- [ ] 支持条件执行（只操作有变更的仓库）
- [ ] 支持并行执行模式（可选）
- [ ] 支持 Git 钩子集成
- [ ] 支持批量操作历史记录

## 许可证

本项目遵循项目主许可证。
