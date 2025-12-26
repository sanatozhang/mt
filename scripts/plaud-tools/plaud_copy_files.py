#!/usr/bin/env python3
"""
文件复制脚本：复制指定文件50次，文件名自动递增
用法: python copy_files.py <文件路径>
"""

import sys
import os
import shutil
from pathlib import Path


def get_next_filename(original_path, copy_number):
    """
    生成递增的文件名
    如果原文件名包含数字，在该数字基础上递增
    否则使用 原文件名_copy_N.扩展名 格式
    """
    original_file = Path(original_path)
    parent_dir = original_file.parent
    stem = original_file.stem  # 文件名（不含扩展名）
    suffix = original_file.suffix  # 扩展名

    # 尝试从文件名中提取数字
    import re

    match = re.search(r"(\d+)", stem)

    if match:
        # 如果文件名包含数字，在数字基础上递增
        number_str = match.group(1)
        number = int(number_str)
        new_number = number + copy_number

        # 替换原数字为新数字
        new_stem = stem.replace(number_str, str(new_number))
        new_filename = f"{new_stem}{suffix}"
    else:
        # 如果文件名不包含数字，使用 _copy_N 格式
        new_filename = f"{stem}_copy_{copy_number}{suffix}"

    return parent_dir / new_filename


def copy_file_multiple_times(source_file, num_copies=50):
    """
    复制文件指定次数，文件名自动递增

    Args:
        source_file: 源文件路径
        num_copies: 复制次数，默认50
    """
    source_path = Path(source_file)

    # 检查源文件是否存在
    if not source_path.exists():
        print(f"错误：文件 '{source_file}' 不存在")
        return False

    if not source_path.is_file():
        print(f"错误：'{source_file}' 不是一个文件")
        return False

    print(f"开始复制文件：{source_file}")
    print(f"目标：生成 {num_copies} 个副本\n")

    successful_copies = 0

    for i in range(1, num_copies + 1):
        try:
            # 生成新文件名
            dest_path = get_next_filename(source_path, i)

            # 如果目标文件已存在，跳过或覆盖（这里选择跳过）
            if dest_path.exists():
                print(f"跳过：文件 '{dest_path.name}' 已存在")
                continue

            # 复制文件
            shutil.copy2(source_path, dest_path)
            successful_copies += 1

            if i % 10 == 0:  # 每10个文件输出一次进度
                print(f"进度：已复制 {i}/{num_copies} 个文件...")

        except Exception as e:
            print(f"错误：复制第 {i} 个文件时出错 - {e}")
            continue

    print(f"\n完成！成功复制 {successful_copies} 个文件")
    return True


def main():
    """主函数"""
    if len(sys.argv) < 2:
        print("用法: python copy_files.py <文件路径> [复制次数]")
        print("示例: python copy_files.py 1761633950.ogg")
        print("示例: python copy_files.py 1761633950.ogg 100")
        sys.exit(1)

    source_file = sys.argv[1]
    num_copies = 50  # 默认复制50次

    # 如果提供了第二个参数，使用它作为复制次数
    if len(sys.argv) >= 3:
        try:
            num_copies = int(sys.argv[2])
            if num_copies <= 0:
                print("错误：复制次数必须大于0")
                sys.exit(1)
        except ValueError:
            print("错误：复制次数必须是数字")
            sys.exit(1)

    copy_file_multiple_times(source_file, num_copies)


if __name__ == "__main__":
    main()
