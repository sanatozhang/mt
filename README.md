# MT

`mt` 是 Plaud-App 的多仓库开发工具。默认固定支持 7 个仓库，零配置可用。

## 安装

推荐直接一键安装：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanatozhang/mt/main/bin/install-mt.sh)"
```

如果一键安装失败，或者 `curl` 无法访问 GitHub Raw，就直接回退到手动安装：

```bash
git clone https://github.com/sanatozhang/mt.git
cd mt
./bin/install-mt.sh
```

安装完成后，重新打开终端，或者执行：

```bash
source ~/.zshrc
# 或
source ~/.bashrc
```

## 初始化开发环境

首次拉起工作区时执行：

```bash
cd /path/to/your/workspace
mt init
```

如果要指定目录名：

```bash
mt init My-Plaud-App
```

`mt init` 用来创建项目环境。它会依次完成：
- 检测 Homebrew
- 检测并安装 FVM
- 安装并配置 Flutter `3.38.9`
- 执行 `mt clone` 拉取 Plaud-App 代码

初始化完成后建议先检查一次环境：

```bash
cd Plaud-App
mt doctor
```

如果你传了自定义目录名，进入对应目录即可。

## 新手推荐

第一次进入项目后，推荐直接执行：

```bash
cd Plaud-App
mt go
```

`mt go` 是新手最常用的入口，默认会执行 Android `global debug` 的 `prebuild + install`。

## 常用命令

- `mt init`
  创建项目环境，拉取代码，配置 Flutter 引擎。
- `mt go`
  新手推荐命令。默认执行 Android `global debug` 的 `prebuild + install`。
- `mt install`
  执行 Android 打包并安装到设备。
- `mt install:ios`
  执行 iOS 打包并安装到设备。
- `mt prebuild`
  执行 Flutter 项目预构建，调用工作区的 `build_all.sh`，通常包括 `flutter pub get`、多语言脚本等。
- `mt build`
  只构建，不安装。
- `mt pr`
  为多仓库创建 PR。
- `mt upgrade`
  更新 mt 工具。

常用全局选项有 `--current`、`--json`、`--dry-run`、`--fail-fast`。完整参数说明见详细文档。

## 详细文档

- [使用文档](doc/README.md)
- [技术方案](doc/TECHNICAL_DESIGN.md)
