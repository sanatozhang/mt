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

`mt init` 会依次完成：
- 检测 Homebrew
- 检测并安装 FVM
- 安装 Flutter `3.38.9`
- 执行 `mt clone` 拉取 Plaud-App 代码

初始化完成后建议先检查一次环境：

```bash
cd Plaud-App
mt doctor
```

如果你传了自定义目录名，进入对应目录即可。

## 常用命令

```bash
mt list
mt status
mt --current branch --show-current
mt checkout -b feature/my-feature
mt build cn -r
mt install global
mt pr -r -d "修复问题描述"
mt upgrade
```

常用全局选项有 `--current`、`--json`、`--dry-run`、`--fail-fast`。完整参数说明见详细文档。

## 详细文档

- [使用文档](doc/README.md)
- [技术方案](doc/TECHNICAL_DESIGN.md)
