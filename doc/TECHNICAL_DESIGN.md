# MT 工具技术方案

## 一、项目概述

### 1.1 问题背景
- 项目包含多个 Git 仓库（通过 Git Submodules 管理）
- 每次切换分支、提交代码需要在多个仓库手动执行
- 操作繁琐，容易遗漏某个仓库

### 1.2 解决方案
创建统一工具 `mt` (Multi-repo Tool)，支持在多仓库同时执行 Git 命令。

## 二、技术架构

### 2.1 技术选型
- **实现语言**: Bash Shell
- **配置文件格式**: YAML
- **执行方式**: 串行执行（保证输出清晰，错误易定位）

### 2.2 文件结构
```
Plaud-App/
├── mt/                     # MT 工具目录
│   ├── bin/                # 脚本目录
│   │   ├── mt              # 主工具脚本（可执行）
│   │   └── install-mt.sh  # 安装脚本
│   └── doc/                # 文档目录
│       ├── README.md       # 使用文档
│       └── TECHNICAL_DESIGN.md  # 技术方案（本文档）
└── .mt-config.yaml         # 配置文件（仓库列表，位于项目根目录）
```

## 三、核心功能设计

### 3.1 配置管理

#### 配置文件格式
```yaml
repositories:
  - name: plaud-flutter-cn
    path: plaud-flutter-cn
    url: git@github.com:Plaud-AI/plaud-flutter-cn.git
  # ... 更多仓库
```

#### 配置解析
- 使用纯 Shell 脚本解析 YAML（避免外部依赖）
- 支持从 `.gitmodules` 自动生成配置（`mt init` 命令）

### 3.2 命令执行流程

```
用户输入: mt checkout -b newBranch
    ↓
解析配置文件 (.mt-config.yaml)
    ↓
获取仓库列表
    ↓
串行执行（逐个仓库）:
  [1/5] plaud-flutter-cn
    → cd plaud-flutter-cn
    → git checkout -b newBranch
    → 显示结果
  [2/5] plaud-flutter-global
    → ...
  ...
    ↓
汇总执行结果
```

### 3.3 支持的命令

#### Git 命令映射
所有 Git 命令通过参数透传实现：
- `mt checkout -b <branch>` → `git checkout -b <branch>`（所有仓库）
- `mt commit -m "msg"` → `git commit -m "msg"`（当前仓库）
- `mt push origin branch` → `git push origin branch`（当前仓库）
- 等等...

#### 全局命令（所有仓库执行）
以下命令会在所有配置的仓库中执行：
- `checkout`, `branch`, `switch` - 分支切换和查看
- `merge`, `rebase`, `cherry-pick` - 分支合并和变基
- `status`, `stash` - 状态查看和暂存

#### 本地命令（当前仓库执行）
其他命令只在当前仓库执行：
- `commit`, `push`, `pull`, `log`, `diff`, `add` 等

#### 命令验证
- 如果输入了不支持的 Git 命令，会显示错误提示
- 支持的命令列表：add, am, apply, archive, bisect, blame, branch, bundle, checkout, cherry-pick, citool, clean, clone, commit, config, describe, diff, fetch, format-patch, gc, grep, gui, init, log, merge, mv, notes, pull, push, rebase, remote, reset, revert, rm, show, stash, status, submodule, switch, tag, worktree

#### 工具命令
- `mt list` - 列出所有仓库
- `mt init` - 初始化配置（优先从 mt 仓库复制，不存在则生成默认配置）
- `mt config` - 编辑配置
- `mt delete [-a]` - 删除本地分支（默认删除3个最旧分支，-a 删除所有）
- `mt clean` - 清除 Flutter、Android、iOS 缓存
- `mt set-github-token <token>` - 设置 GitHub token
- `mt upgrade` - 更新工具到最新版本
- `mt help` - 显示帮助

#### 构建命令
- `mt prebuild` - 构建 Flutter 模块（构建前准备）
- `mt build [cn|global] [options]` - 构建 Android 包
  - 默认市场：global
  - 默认构建类型：debug
  - 支持短参数：`-d`/`--d`/`--debug`, `-r`/`--r`/`--release`, `-p`/`--p`/`--profile`
  - CN 版本支持渠道：`-c`/`--c`/`--channel <name>`, `-a`/`--a`/`--all`
- `mt install [cn|global] [options]` - 构建并安装 Android 包到设备
  - 参数与 build 命令相同
  - 不执行 clean，直接构建以加快速度
- `mt build:check [-d|-r]` - 编译检查：同时构建 CN 和 Global 版本
- `mt build:ios [cn|global] [options]` - 构建 iOS 包
- `mt clean` - 清除 Flutter、Android、iOS 缓存

### 3.4 错误处理

1. **配置文件检查**: 启动时检查配置文件是否存在，如果不存在会自动从 mt 仓库复制
2. **路径验证**: 检查仓库路径是否存在
3. **Git 仓库验证**: 检查是否为有效的 Git 仓库（支持普通仓库和 Submodule）
4. **命令验证**: 检查输入的命令是否支持，不支持则显示错误提示
5. **执行错误**: 某个仓库失败时继续执行其他仓库
6. **结果汇总**: 最后显示成功/失败统计
7. **代码变更检查**: 
   - `push` 命令自动跳过没有代码变更的仓库
   - `pr` 命令自动跳过没有代码变更的仓库
   - `commit` 命令自动跳过没有暂存修改的仓库

### 3.5 输出格式

- **彩色输出**: 使用 ANSI 颜色码
  - 绿色: 成功
  - 红色: 失败/错误
  - 黄色: 警告
  - 蓝色: 信息
  - 青色: 标题

- **图标标识**:
  - ✓ 成功
  - ✗ 失败
  - → 操作

- **进度显示**: `[1/5]`, `[2/5]` 等

## 四、安装机制

### 4.1 安装方式

#### 方式一：系统级安装（推荐）
- 创建符号链接到 `/usr/local/bin/mt`
- 需要 sudo 权限
- 全局可用

#### 方式二：用户级安装（备选）
- 创建符号链接到 `~/.local/bin/mt`
- 自动添加到 PATH（修改 `~/.zshrc` 或 `~/.bashrc`）
- 无需 sudo 权限

### 4.2 安装流程

```
执行 install-mt.sh
    ↓
检测 Shell 类型
    ↓
尝试系统级安装
    ↓
成功? → 完成
    ↓
失败? → 用户级安装
    ↓
添加到 PATH
    ↓
提示用户 source 配置文件
```

## 五、实现细节

### 5.1 YAML 解析

由于避免外部依赖，使用纯 Shell 解析 YAML：
- 逐行读取配置文件
- 使用正则表达式匹配 key-value
- 支持简单的列表结构

**限制**: 不支持复杂嵌套结构（当前需求不需要）

### 5.2 路径处理

- 自动检测项目根目录（脚本所在目录）
- 支持相对路径和绝对路径
- 支持在任何子目录执行 `mt` 命令

### 5.3 命令参数透传

所有参数原样传递给 Git 命令：
```bash
mt checkout -b feature/new-feature
# 实际执行: git checkout -b feature/new-feature
```

### 5.4 特殊命令处理

- `checkout -b`: 显示"已创建并切换到分支"
- `checkout`: 显示"已切换到分支"
- `commit`: 显示"提交成功"
- 等等...

### 5.5 构建命令实现

#### 构建流程
1. **预构建** (`mt prebuild`): 执行 `build_all.sh` 构建 Flutter 模块
2. **切换 Flavor**: 使用 `switch_flavor.sh` 切换市场版本
3. **Gradle 构建**: 执行对应的 Gradle 任务
   - `build` 命令：执行 `gradlew <task>`（默认跳过 clean，直接构建）
   - `install` 命令：执行 `gradlew <task>`（跳过 clean）
4. **安装** (`mt install`): 构建成功后使用 `adb install -r` 安装到设备

#### 构建参数设计
- `_build_android_internal` 函数添加第 5 个参数 `skip_clean`
- `skip_clean=true`: 跳过 clean 步骤（build/install 默认使用）
- `skip_clean=false`: 执行 clean 步骤（如需干净构建，请先执行 `mt clean`）

#### 日志系统
- 日志目录：`mt/logs/`
- 日志文件命名：`build_{market}_{build_type}_{timestamp}.log`
- 日志内容：
  - 构建开始/结束时间
  - 构建参数（市场、类型、渠道）
  - Flavor 切换过程
  - Gradle 构建输出
  - APK 文件位置

#### 参数解析
- 支持短参数和长参数：`-d`/`--d`/`--debug`
- 默认构建类型：debug（而非 release）
- 参数验证：市场、构建类型、渠道参数

## 六、构建功能设计

### 6.1 构建命令

#### prebuild 命令
- 功能：构建 Flutter 模块（执行 `build_all.sh`）
- 用途：在构建 Android 包之前准备 Flutter 模块
- 日志：记录到 `mt/logs/prebuild_{timestamp}.log`

#### build 命令
- 功能：构建 Android APK 包
- 默认行为：构建 global debug 包
- 支持市场：cn、global
- 支持构建类型：debug、release、profile（未来）
- CN 多渠道支持：
  - 单渠道：`-c <channel>`
  - 所有渠道：`-a`（仅 release）
- 执行 clean：默认不执行 clean，直接构建（如需清理缓存请使用 `mt clean`）

#### install 命令
- 功能：构建并安装 Android APK 包到设备
- 参数：与 build 命令相同
- 执行流程：
  1. 调用 `_build_android_internal` 并传入 `skip_clean=true`
  2. 不执行 clean，直接构建以加快速度
  3. 构建成功后使用 `adb install -r` 安装到设备
- 设备检查：自动检查 adb 是否可用，设备是否连接

#### clean 命令
- 功能：清除 Flutter、Android、iOS 的缓存
- 清除内容：
  - Flutter: `.dart_tool`, `.flutter-plugins`, `.flutter-plugins-dependencies`, `build` 目录
  - Android: `.gradle`, `app/build`, `build` 目录
  - iOS: `PLAUD/build`, `Pods`, `DerivedData` 目录

#### build:check 命令
- 功能：同时构建 CN 和 Global 版本
- 用途：push 代码前的编译检查
- 默认：构建 debug 版本

### 6.2 日志系统

#### 日志目录结构
```
mt/logs/
├── prebuild_20240101_120000.log
├── build_cn_debug_20240101_120100.log
├── build_global_release_20240101_120200.log
└── ...
```

#### 日志内容
- 时间戳：每个关键步骤都有时间戳
- 构建参数：市场、类型、渠道
- 执行过程：Flavor 切换、Gradle 输出
- 结果信息：成功/失败、APK 位置

### 6.3 参数设计

#### 短参数支持
- `-d` / `--d` / `--debug`: Debug 构建
- `-r` / `--r` / `--release`: Release 构建
- `-p` / `--p` / `--profile`: Profile 构建
- `-c` / `--c` / `--channel`: 指定渠道
- `-a` / `--a` / `--all`: 所有渠道

#### 默认值
- 构建类型：debug（而非 release）
- CN 渠道：official（默认）

## 七、扩展性设计

### 7.1 添加新仓库

1. 编辑 `.mt-config.yaml`
2. 添加新仓库配置
3. 无需修改代码

### 7.2 已实现功能

- ✅ **条件执行**: `push`、`pr`、`commit` 命令自动跳过没有变更的仓库
- ✅ **分支管理**: `delete` 命令支持智能删除本地分支
- ✅ **缓存清理**: `clean` 命令清除 Flutter、Android、iOS 缓存
- ✅ **快速安装**: `install` 命令跳过 clean 以加快安装速度
- ✅ **配置自动复制**: `init` 命令优先从 mt 仓库复制配置
- ✅ **命令验证**: 不支持的命令显示错误提示

### 7.3 未来扩展点

- **Profile 构建**: 支持 Profile 构建类型
- **仓库分组**: 支持只操作特定组别的仓库
- **并行执行**: 可选并行模式（加快速度）
- **Git 钩子**: 集成 Git hooks
- **操作历史**: 记录执行历史
- **构建缓存**: 缓存构建结果，避免重复构建

## 八、测试策略

### 8.1 功能测试

- [x] 配置文件解析
- [x] 仓库列表显示
- [x] 版本号显示
- [x] 帮助信息显示
- [ ] Git 命令执行（需要实际 Git 仓库）
- [ ] 错误处理

### 8.2 边界情况

- 配置文件不存在
- 仓库路径不存在
- 非 Git 仓库
- Git 命令执行失败
- 空配置文件

## 九、性能考虑

### 9.1 执行效率

- **串行执行**: 虽然比并行慢，但输出清晰，错误易定位
- **单次 Git 操作**: 通常很快（< 1秒）
- **5个仓库**: 总耗时约 5-10 秒（可接受）

### 9.2 优化空间

- 如果未来需要，可以添加并行执行模式
- 可以缓存仓库列表（避免重复解析）

## 十、安全性

### 10.1 输入验证

- 检查配置文件格式
- 验证仓库路径
- 验证 Git 仓库有效性

### 10.2 权限控制

- 不修改系统文件（除非安装时）
- 只读取配置文件
- 执行 Git 命令（用户已有权限）

## 十一、维护性

### 11.1 代码组织

- 函数化设计，职责清晰
- 注释完善
- 错误信息明确

### 11.2 文档

- README_MT.md: 用户使用文档
- TECHNICAL_DESIGN_MT.md: 技术方案（本文档）
- 代码注释: 关键逻辑说明

## 十二、已知限制

1. **YAML 解析**: 使用简单正则，不支持复杂嵌套
2. **并行执行**: 当前不支持，未来可扩展
3. **Windows 支持**: 需要 Git Bash 或 WSL
4. **交互式命令**: 某些交互式 Git 命令可能体验不佳

## 十三、总结

MT 工具通过统一的命令行接口，简化了多仓库 Git 操作流程。采用 Shell 脚本实现，无需额外依赖，易于安装和维护。配置文件化管理，便于扩展新仓库。

**核心优势**:
- ✅ 简单易用
- ✅ 无需额外依赖
- ✅ 易于扩展
- ✅ 输出清晰
- ✅ 错误处理完善

