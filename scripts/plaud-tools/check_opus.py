import sys
import os


def check_file_lines(filepath):
    if not os.path.isfile(filepath):
        print(f"Error: File '{filepath}' not found.")
        return

    with open(filepath, "r") as file:
        for lineno, line in enumerate(file, start=1):
            stripped = line.strip().upper()
            if not stripped.startswith("B8"):
                print(f"Line {lineno} does not start with 'B8': {stripped}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python check_b8_lines.py <file_path>")
    else:
        check_file_lines(sys.argv[1])
