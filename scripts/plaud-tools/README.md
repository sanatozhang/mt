# Plaud 工具脚本

本目录包含 mt 工具集成的 Plaud 辅助工具脚本。

## 脚本列表

- `version_converter.py` - 版本号转换工具（versionCode ↔ 版本字符串）
- `log_sync_analyzer.py` - 日志同步分析工具
- `log_cleaner_network.py` - 网络日志清理工具
- `plaud_sync_time_diff.py` - 同步时间差分析工具
- `check_opus.py` - Opus 文件格式检查工具
- `plaud_copy_files.py` - 文件批量复制工具
- `plaudDecryptor.py` - Plaud 加密文件解密工具

## 使用方式

这些脚本通过 `mt plaud` 命令调用，例如：

```bash
mt plaud version -c 66048
mt plaud log sync app.log
mt plaud decrypt encrypted.plaud
```

## 来源

这些脚本来自 Plaud-app-scripts 项目，已复制到 mt 项目中以保持独立性。

## 依赖

- Python 3.7+
- 部分脚本可能需要额外的 Python 包（如 cryptography, pycryptodome）

