#!/usr/bin/env python3
# 移除网络请求数据
import sys
import os


def remove_special_chars(file_path):
    # Characters to remove
    special_chars = ["║", "╔", "╣", "╚", "╟"]

    try:
        # Check if file exists
        if not os.path.exists(file_path):
            print(f"Error: File '{file_path}' does not exist")
            return

        # Read all lines from the file
        with open(file_path, "r", encoding="utf-8", errors="ignore") as file:
            content = file.read()

        # Add newline before INFO: if it's not at the start of a line
        content = content.replace("INFO: ", "\nINFO: ")
        # Remove any double newlines that might have been created
        content = content.replace("\n\n", "\n")
        # Split into lines
        lines = content.splitlines()

        # Filter out lines containing special characters, empty lines, and empty INFO lines
        filtered_lines = [
            line
            for line in lines
            if not any(char in line for char in special_chars)
            and line.strip()  # Remove empty lines
            and not (
                line.startswith("INFO: ") and line.strip().endswith(":")
            )  # Remove empty INFO lines
        ]

        # Write back the filtered content
        with open(file_path, "w", encoding="utf-8", errors="ignore") as file:
            file.writelines(line + "\n" for line in filtered_lines)

        print(f"Successfully cleaned up the file {file_path}")

    except Exception as e:
        print(f"An error occurred: {str(e)}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 test.py <file_path>")
        sys.exit(1)

    file_path = sys.argv[1]
    remove_special_chars(file_path)
