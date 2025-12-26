# Changelog

所有重要的变更都会记录在这个文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

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

