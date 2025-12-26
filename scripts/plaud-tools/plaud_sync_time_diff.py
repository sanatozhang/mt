#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sync_time_diff.py
从日志中提取 "syncFinish begin:" 与 "syncFinish end:" 的毫秒时间戳，
按先进先出配对，计算时间差（秒），并打印为：
YYYY-MM-DD HH:MM:SS.sss (原始毫秒)  |  YYYY-MM-DD HH:MM:SS.sss (原始毫秒)  |  diff_sec

新增：
--min-diff <float>  过滤掉时间差小于该值（秒）的记录；例如 --min-diff 0.1
"""

import re
import sys
import os
import argparse
from datetime import datetime


def read_file_safely(file_path):
    """尝试多种编码方式读取文件"""
    encodings = ["utf-8", "utf-8-sig", "gb18030", "latin-1"]
    for enc in encodings:
        try:
            with open(file_path, "r", encoding=enc) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
    raise UnicodeDecodeError("无法用常见编码解码文件，请手动检查文件编码。")


def ms_to_datetime_with_raw(ms_timestamp: int) -> str:
    """毫秒时间戳转为 'YYYY-MM-DD HH:MM:SS.sss (ms)' 字符串"""
    try:
        dt = datetime.fromtimestamp(ms_timestamp / 1000).strftime(
            "%Y-%m-%d %H:%M:%S.%f"
        )[:-3]
        return f"{dt} ({ms_timestamp})"
    except Exception:
        return f"{ms_timestamp}"


def parse_sync_log(file_path: str, min_diff: float | None = None):
    """
    解析日志并打印全部记录。
    :param file_path: 日志路径
    :param min_diff: 若设置，则过滤掉 diff_sec < min_diff 的记录
    """
    if not os.path.exists(file_path):
        print(f"❌ 文件不存在: {file_path}")
        return

    log_data = read_file_safely(file_path)

    # 提取 begin / end 毫秒时间戳（先进先出）
    begin_times = list(map(int, re.findall(r"syncFinish begin:\s*(\d+)", log_data)))
    end_times = list(map(int, re.findall(r"syncFinish end:\s*(\d+)", log_data)))

    pair_count = min(len(begin_times), len(end_times))
    if pair_count == 0:
        print("⚠️ 未匹配到可配对的 begin/end 时间戳。")
        return

    # 计算所有 diff
    records = []
    for i in range(pair_count):
        b = begin_times[i]
        e = end_times[i]
        diff_sec = (e - b) / 1000
        records.append((b, e, diff_sec))

    total_before = len(records)

    # 过滤小于 min_diff 的记录（若指定）
    if min_diff is not None:
        records = [r for r in records if r[2] >= min_diff]

    total_after = len(records)
    removed = total_before - total_after

    # 打印表头与统计
    print(f"✅ 配对到 {pair_count} 组（未过滤）。", end="")
    if min_diff is not None:
        print(
            f" 过滤阈值: diff < {min_diff:.3f} 秒 → 移除 {removed} 条，保留 {total_after} 条。"
        )
    else:
        print()

    print(
        f"\n{'序号':<5}{'Begin 时间 (含毫秒原值)':<40}{'End 时间 (含毫秒原值)':<40}{'时间差(秒)':<10}"
    )
    print("-" * 100)

    # 打印全部记录
    for idx, (b, e, d) in enumerate(records, start=1):
        print(
            f"{idx:<5}{ms_to_datetime_with_raw(b):<40}{ms_to_datetime_with_raw(e):<40}{d:<10.3f}"
        )


def main():
    parser = argparse.ArgumentParser(
        description="从日志中提取 syncFinish begin/end 时间戳并计算时间差（秒）"
    )
    parser.add_argument("log_file", help="日志文件路径，例如 /path/to/plaud.log")
    parser.add_argument(
        "--min-diff",
        type=float,
        default=None,
        help="过滤掉时间差小于该值（秒）的记录，例如 --min-diff 0.1",
    )
    args = parser.parse_args()

    parse_sync_log(args.log_file, min_diff=args.min_diff)


if __name__ == "__main__":
    main()
