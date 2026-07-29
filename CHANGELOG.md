# Changelog

中文 | [English](CHANGELOG.en.md)

所有重要的变更都会记录在这个文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [2.1.0] - 2026-07-29

### 新增

#### 中英双语输出
- `bin/` 下所有用户可见输出（提示、错误、帮助文本、安装向导）全面支持中英双语，一条提示中文在前、英文在后
- 新增 `echo_bi` / `echo_bi_err`（`bin/lib/mt_core.sh`）双语输出助手，`bin/install-mt.sh` 因是独立分发脚本自带一份同名实现
- `mt help` 完整帮助文本双语化，`mt init` 在帮助文本与 README 中标注为新人入职后应执行的第一条命令
- `README.md` / `CHANGELOG.md` 新增语言切换链接；`README.md` 默认展示英文版，中文版移至 `README.zh.md`；新增 `CHANGELOG.en.md` 完整英文版

### 不变（向后兼容）

- 所有命令的行为、退出码、`--json` 输出的字段结构与 key 均未改变，仅 `message`/`summary` 等展示型文本追加了英文
- 内部作为哨兵值比较的字符串（如 `mt status` 的"没有变化"、`mt pr` 的 PR 状态码）保持原文不变，只在展示处双语化

## [2.0.1] - 2026-05-28

### 新增

#### `mt sync` 一键同步上游
- 新命令 `mt sync [base_branch] [--push]`：对每个仓库执行 `git fetch origin <base>` + `git rebase origin/<base>`
- 当前分支 == base 时自动改走 `git pull --ff-only`，避免 rebase 自己
- 工作区脏 / detached HEAD 自动跳过并清晰列出原因，不会破坏未提交修改
- rebase 冲突时自动 `git rebase --abort` 保护工作区，记录失败仓库继续处理其他仓库
- `--push` 选项：rebase 完成后 `git push --force-with-lease` 到当前分支远端
- 默认 base = `main`，可指定其他基线（如 `mt sync development`）

### 修复

#### `mt pull/fetch/push/clone` 长耗时网络命令"看似卡死"
- 之前 `run_command` 把整段输出 capture 后才打印，网络命令在慢仓库可静默 30 秒以上
- 新增 `is_long_running_git_command` 白名单（fetch/pull/push/clone/submodule update|sync|foreach），这类命令走 `tee` 流式输出 + 落盘 capture 的双轨分支
- 用户能实时看到 `From github.com:... -> FETCH_HEAD` 之类的真实进度
- 短命令（status/branch/log/diff 等）仍走原有 `format_output` 着色路径，输出风格不变

## [2.0.0] - 2026-05-28

### 重大更新

#### 同时支持 Plaud-Flutter 和 Plaud-Native 两个项目
mt 从此可以在两类工作区下零差异使用：
- **flutter-mt**：原有的 Flutter + Native 混合工程（marker: `plaud-android`），默认 7 仓库
- **native-app2**：全新 Plaud 纯 Native 工程（marker: `plaud-native-android`），5 仓库

mt 会自动按 `cwd` 识别当前工作区类型并切换底层实现，命令名、参数、产物路径与原有用法完全一致。

### 新增功能

#### 项目识别与守卫
- 新增 `PROJECT_PROFILES` 注册表（在 `bin/mt`），声明两类工作区的目录布局
- 新增 `detect_project_kind` / `require_project_kind` 守卫函数
- 在 A/B 项目之外执行打包/安装类命令时，给出友好错误并列出已支持的工作区

#### native-app2 打包闭环
- `mt build [cn|global] [-d/-r/-p] [-c <channel>] [-a]`：调用 `plaud-native-android/switch_flavor.sh` + `gradlew assemble*`
  - 完整支持 7 个 cn 渠道：official / huawei / xiaomi / oppo / vivo / honor / yingyongbao
- `mt build:ios [cn|global] [-d/-r]`：调用 `xcodebuild build` + scheme `Plaud-CN`/`Plaud-Global`，产出 `.app`
- `mt install` / `mt install:ios`：构建完成后自动安装到设备（adb / xcrun devicectl / ios-deploy）
- `mt prebuild`：依次执行 `plaud-native-android/build.sh` 与 `plaud-native-ios/scripts/start/build.sh`，处理翻译、埋点、CocoaPods 等
- `mt go` / `mt rebuild` / `mt build:check` / `mt clean`：全部支持 native-app2

#### native-app2 Git 多仓库支持
- 新增 `NATIVE_APP2_REPOSITORIES` 列表（5 条）：`plaud-native-android` / `plaud-native-ios` / `plaud-native-harmony` + 两个嵌套子模块 `nicebuildSDK` / `PenSubmodules`
- `mt status` / `mt branch` / `mt checkout` / `mt pull` / `mt push` / `mt list` / `mt pr` 等所有 git 多仓库命令在 native-app2 下自动按新列表执行
- `--current` / `--main-only` / `--subrepos-only` / `--only` / `--exclude` 等全局过滤选项行为不变

### 架构

#### 双轨隔离设计
- 新增 `bin/lib/mt_build_app2.sh`（~800 行），承载 native-app2 全部 `_app2_*` 实现
- 原有 `bin/lib/mt_build.sh` 内部函数（`_build_android_internal` / `_build_ios_internal` / `prebuild` / `clean_cache` 等）**一行未改**
- 分发发生在 `bin/lib/mt_cli.sh` 的 `handle_*` 入口层，对 flutter-mt 项目调用链与改造前完全一致
- 仓库列表分发集中在 `mt_core.sh:get_repositories`，按 `detect_project_kind` 路由

### 改进

- `find_project_root` 现在能识别任一已注册 profile 的 marker（向上溯源时既兼容 A 又兼容 B）
- 错误提示更清晰：未识别工作区时会列出已支持的项目名与 marker

### 不变（向后兼容）

- flutter-mt 项目下所有命令的行为、输出、产物路径、错误信息与 1.4.2 完全一致
- `DEFAULT_REPOSITORIES` 的 7 个仓库定义未做任何修改
- 安装方式、`mt upgrade`、`mt init` 等环境工具链无变化

## [1.4.2] - 2026-01-26

### 新增功能

#### PR Ready 与 Review 摘要
- `mt pr -r/--ready` 创建后将 PR 从 Draft 设为 Ready for review
- Review 群发布摘要增加作者/变更/链接，格式更适合直接转发
- 摘要追加脚注：本 PR review 由 mt 工具创建
- `mt init` 现在会检查 Homebrew/FVM、安装 Flutter `3.38.9`，并自动执行仓库克隆

### 改进

#### 多仓库覆盖范围
- 默认仓库列表固定覆盖 7 个仓库；缺失或未初始化的仓库会自动跳过
- 移除 `.mt-config.yaml` 运行时依赖，默认 7 仓库改为零配置运行
- `mt status` 无改动时输出“没有变化”
- 新增全局仓库筛选与执行控制：`--current`、`--main-only`、`--subrepos-only`、`--only`、`--exclude`、`--dry-run`、`--json`、`--fail-fast`
- 新增 `mt doctor` 用于检查开发环境、工作区和仓库状态
- 将 `bin/mt` 按模块拆分为 `bin/lib/*.sh`，入口脚本缩减为轻量加载器，便于维护各命令域
- `mt go`、`mt rebuild`、`mt init` 等组合命令在任一步骤失败时会明确输出整体失败结果，并返回非零退出码

### 修复

#### PR 描述更新异常
- 修复 `mt pr` 更新 PR 描述时 here-doc 结构错误导致的 `response/http_code` 未定义报错
- 修复 `mt pr` 误将 closed/merged 历史 PR 当成当前 open PR 的问题，避免部分仓库在汇总中“丢失”

## [1.4.1] - 2025-01-16

### 修复

#### 远程安装环境变量修复
- **关键修复**：修复了通过 `curl | bash` 方式安装时，mt 工具没有添加到环境变量的问题
- 远程执行时，自动跳过系统级安装（需要密码），直接使用用户级安装（无需密码）
- 修复了 `install_user_path()` 函数的 PATH 检查逻辑：
  - 无论当前 PATH 是否包含 `.local/bin`，都会检查配置文件并添加（如果不存在）
  - 确保 PATH 配置能够持久化到 Shell 配置文件（`.zshrc` 或 `.bashrc`）
- 改进了符号链接创建的错误处理，确保安装过程不会静默失败
- 添加了更清晰的提示信息，告知用户需要重新加载配置或重新打开终端

## [1.4.0] - 2025-01-16

### 新增功能

#### Status 命令彩色输出
- `mt status` 命令现在支持彩色输出，颜色与 `git status` 完全一致
- 不同状态使用不同颜色：
  - 青色/蓝色：分支信息（`On branch ...`）
  - 绿色：已暂存的更改（`Changes to be committed:`、`new file:`、`nothing to commit`）
  - 红色：未暂存的更改（`Changes not staged for commit:`、`modified:`、`deleted:`、`Untracked files:`）
  - 黄色：提示信息（`Your branch is ahead/behind...`、`no changes added to commit`、`renamed:`）
- 自动识别文件状态码（`M  file`、` M file`、`?? file` 等）并应用相应颜色
- `status` 命令不再显示额外的"执行成功"提示，输出更简洁

### 改进

#### 缓存目录权限处理优化
- 修复了在某些环境下无法创建缓存目录（`~/.cache/mt`）导致的权限错误
- 如果无法创建缓存目录，会静默跳过版本检查，不影响主功能
- 版本检查失败不会中断命令执行，提升工具稳定性

### 修复

#### 错误处理改进
- 修复了缓存目录创建失败时显示错误信息的问题
- 改进了错误处理逻辑，确保工具在权限受限环境下也能正常工作

#### BASH_SOURCE 未定义变量错误修复
- 修复了在 `set -u` 模式下访问 `BASH_SOURCE[0]` 和 `BASH_SOURCE[1]` 时可能出现的 "unbound variable" 错误
- 修复了 `bin/mt` 和 `bin/install-mt.sh` 中所有 `BASH_SOURCE` 访问，使用安全的默认值（`${BASH_SOURCE[0]:-$0}` 和 `${BASH_SOURCE[1]:-}`）
- 确保脚本在各种执行环境下（直接执行、source、符号链接、curl 远程执行等）都能正常工作
- 特别修复了通过 `curl | bash` 方式执行安装脚本时的错误

#### 安装脚本路径处理修复
- 修复了远程执行安装脚本时，`bin` 目录不存在导致的路径错误（`No such file or directory`）
- 改进了路径验证逻辑，在目录不存在时自动创建或提供清晰的错误提示
- 使用更安全的路径计算方法（`dirname` 替代 `..`），避免路径解析错误
- 确保克隆仓库后能正确识别和访问 `bin` 目录

## [1.2.0] - 2024-12-18

### 新增功能

#### 子仓库分支操作同步
- 分支相关操作（checkout, branch, merge, rebase, switch, cherry-pick）现在会在 Android 和 iOS 项目的子仓库中同步执行
- Android 子仓库：`plaud-android/nicebuildSDK`（自动检测并执行）
- iOS 子仓库：`plaud-ios/PLAUD/PenSubmodules`（自动检测并执行）
- 子仓库不存在时会自动跳过，不影响主仓库操作

#### 克隆功能增强
- `mt clone` 命令现在会自动克隆 Android 子仓库 `ble-sdk-android` 到 `plaud-android/nicebuildSDK`
- iOS 子仓库通过 `git submodule update --init --recursive` 自动初始化（Git 子模块）

### 改进

#### Push 命令行为变更
- `mt push` 现在会对所有配置的仓库执行 push 操作，不再检查是否有本地提交
- 移除 push 前的变更检测逻辑，简化使用流程
- 如果某个仓库没有可推送的提交，会显示 Git 的错误信息，但不会提前跳过

#### 执行结果统计优化
- 修复了分支操作包含子仓库时，总结统计显示不正确的问题（如显示 7/5）
- 现在正确统计所有执行的仓库（主仓库 + 子仓库），显示准确的执行数量

## [1.1.0] - 2024-12-17

### 新增功能

#### Git 命令缩写支持
- 支持常用的 Git 命令缩写，提升使用效率
- 支持的基础命令缩写：
  - `co` → `checkout`
  - `br` → `branch`
  - `ci`/`cm` → `commit`
  - `st` → `status`
  - `ps`/`ph` → `push`
  - `pl` → `pull`
  - `m` → `merge`
  - `rb` → `rebase`
  - `sa` → `stash`
  - `sw` → `switch`
  - `cp` → `cherry-pick`
  - `fe`/`ft` → `fetch`
  - `di` → `diff`
  - `lo` → `log`
  - `rs` → `reset`
  - `rv` → `revert`
  - `sh` → `show`
  - `ta` → `tag`
  - `ad` → `add`
- 支持带参数的复合缩写：
  - `cob` → `checkout -b`（创建并切换分支）
  - `bra` → `branch -a`（显示所有分支）
  - `cim` → `commit -m`（提交并指定消息）
  - `ciam` → `commit -am`（添加所有文件并提交）
  - `cane` → `commit --amend --no-edit`（修改最后一次提交）
  - `phf` → `push -f`（强制推送）
  - `plro` → `pull --rebase origin`（从 origin 变基拉取）
  - `rbi` → `rebase -i`（交互式变基）
  - `rba` → `rebase --abort`（中止变基）
  - `rbc` → `rebase --continue`（继续变基）
  - `rth` → `reset --hard`（硬重置）
  - `rts` → `reset --soft`（软重置）
  - `cpa` → `cherry-pick --abort`（中止 cherry-pick）
  - `cpc` → `cherry-pick --continue`（继续 cherry-pick）
  - `shs` → `stash save`（保存暂存）
  - `sha` → `stash apply`（应用暂存）
  - `shp` → `stash pop`（弹出暂存）
  - `shd` → `stash drop`（删除暂存）

#### Plaud 工具集成
- 集成 Plaud-app-scripts 工具集到 mt 工具中
- 所有工具脚本已复制到 `scripts/plaud-tools/` 目录，保持工具独立性
- 新增 `mt plaud` 命令前缀，统一管理 Plaud 相关工具
- 支持的工具命令：
  - `mt plaud version` - 版本号转换工具（versionCode ↔ 版本字符串）
  - `mt plaud log sync` - 日志同步分析工具
  - `mt plaud log clean` - 网络日志清理工具
  - `mt plaud log time-diff` - 同步时间差分析工具
  - `mt plaud check opus` - Opus 文件格式检查工具
  - `mt plaud copy` - 文件批量复制工具
  - `mt plaud decrypt` - Plaud 加密文件解密工具

#### 项目克隆功能
- 新增 `mt clone` 命令，一键克隆 Plaud-App 仓库
- 自动执行 `git submodule update --init --recursive` 初始化所有子模块
- 支持指定目标目录（默认为 `Plaud-App`）
- 提供清晰的进度提示和错误处理

#### Git Submodule 支持
- 完整支持 `git submodule` 命令
- 可在所有配置的仓库中执行子模块操作
- 示例：`mt submodule update --init --recursive`

### 改进

#### 项目根目录识别优化
- 改进了 `find_project_root` 函数，即使没有配置文件也能正确识别项目根目录
- 通过检测项目结构（包含多个 plaud 相关子目录）来识别项目根目录
- 解决了在子目录（如 `plaud-flutter-cn`）执行命令时路径识别错误的问题

#### 帮助文档更新
- 更新了 `mt help` 命令的输出，包含所有新功能
- 添加了 Git 命令缩写的详细说明和示例
- 添加了 Plaud 工具的使用说明

#### 错误提示优化
- 改进了不支持命令的错误提示，显示所有支持的缩写
- 优化了子模块初始化的输出显示

### 技术改进

#### 脚本路径管理
- 优先使用 mt 项目内的脚本目录（`scripts/plaud-tools/`）
- 支持通过环境变量 `PLAUD_SCRIPTS_DIR` 指定外部脚本目录
- 向后兼容，如果找不到内部脚本，会回退到外部目录

#### 代码组织
- 所有 Plaud 工具脚本已集成到 mt 项目中，保持工具独立性
- 创建了 `scripts/plaud-tools/README.md` 说明文档

### 文档

- 更新了 `README.md` 和 `doc/README.md`，包含所有新功能说明
- 更新了 `doc/TECHNICAL_DESIGN.md`，记录技术实现细节

## [1.0.0] - 初始版本

### 功能

- 多仓库 Git 命令统一执行
- 配置文件化管理仓库列表
- 支持所有常用 Git 命令
- 分支操作支持（checkout, branch, switch, merge, rebase, cherry-pick）
- 状态查看和暂存操作（status, stash）
- 提交和推送（自动跳过无变更的仓库）
- 差异查看（自动跳过无变化的仓库）
- 工具命令：list, init, config, delete, clean, upgrade
- 构建命令：prebuild, build, install, build:check, build:ios
- PR 创建功能（支持 Draft PR、自动添加 Copilot reviewer、MT AUTO 标签）
- iOS 安装支持（真机设备检测和选择）
