#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Plaud 日志解密器
基于HTML版本的Python实现，支持解密.plaud文件并提取ZIP内容
"""

import os
import sys
import argparse
import zipfile
import io
from pathlib import Path


class ChaCha20:
    """ChaCha20实现，与HTML版本完全一致"""
    
    def __init__(self, key, nonce):
        self.key = bytearray(key)
        self.nonce = bytearray(nonce)
        self.counter = 0
    
    def quarter_round(self, a, b, c, d, x):
        """ChaCha20四分之一轮函数"""
        x[a] = (x[a] + x[b]) & 0xffffffff
        x[d] ^= x[a]
        x[d] = ((x[d] << 16) | (x[d] >> 16)) & 0xffffffff
        
        x[c] = (x[c] + x[d]) & 0xffffffff
        x[b] ^= x[c]
        x[b] = ((x[b] << 12) | (x[b] >> 20)) & 0xffffffff
        
        x[a] = (x[a] + x[b]) & 0xffffffff
        x[d] ^= x[a]
        x[d] = ((x[d] << 8) | (x[d] >> 24)) & 0xffffffff
        
        x[c] = (x[c] + x[d]) & 0xffffffff
        x[b] ^= x[c]
        x[b] = ((x[b] << 7) | (x[b] >> 25)) & 0xffffffff
    
    def block(self):
        """生成一个ChaCha20块"""
        x = [0] * 16
        
        # 常量
        x[0] = 0x61707865
        x[1] = 0x3320646e
        x[2] = 0x79622d32
        x[3] = 0x6b206574
        
        # 密钥
        for i in range(8):
            x[4 + i] = (self.key[i * 4] |
                       (self.key[i * 4 + 1] << 8) |
                       (self.key[i * 4 + 2] << 16) |
                       (self.key[i * 4 + 3] << 24)) & 0xffffffff
        
        # 计数器
        x[12] = self.counter & 0xffffffff
        
        # Nonce
        for i in range(3):
            x[13 + i] = (self.nonce[i * 4] |
                        (self.nonce[i * 4 + 1] << 8) |
                        (self.nonce[i * 4 + 2] << 16) |
                        (self.nonce[i * 4 + 3] << 24)) & 0xffffffff
        
        working = x[:]
        
        # 20轮
        for i in range(10):
            self.quarter_round(0, 4, 8, 12, working)
            self.quarter_round(1, 5, 9, 13, working)
            self.quarter_round(2, 6, 10, 14, working)
            self.quarter_round(3, 7, 11, 15, working)
            
            self.quarter_round(0, 5, 10, 15, working)
            self.quarter_round(1, 6, 11, 12, working)
            self.quarter_round(2, 7, 8, 13, working)
            self.quarter_round(3, 4, 9, 14, working)
        
        # 添加初始状态
        for i in range(16):
            working[i] = (working[i] + x[i]) & 0xffffffff
        
        # 转换为字节
        output = bytearray(64)
        for i in range(16):
            val = working[i]
            output[i * 4] = val & 0xff
            output[i * 4 + 1] = (val >> 8) & 0xff
            output[i * 4 + 2] = (val >> 16) & 0xff
            output[i * 4 + 3] = (val >> 24) & 0xff
        
        self.counter += 1
        return output
    
    def decrypt(self, ciphertext):
        """解密数据"""
        plaintext = bytearray(len(ciphertext))
        pos = 0
        
        self.counter = 0  # 重置计数器
        
        while pos < len(ciphertext):
            keystream = self.block()
            remaining = len(ciphertext) - pos
            block_size = min(64, remaining)
            
            for i in range(block_size):
                plaintext[pos + i] = ciphertext[pos + i] ^ keystream[i]
            
            pos += block_size
        
        return plaintext


class PlaudDecryptor:
    """Plaud日志解密器类"""
    
    def __init__(self):
        # 与HTML版本保持一致的加密参数
        self.CHACHA20_KEY = 'plaud2023_log_chacha20_key_32bit'
        self.CHACHA20_NONCE = b'\x01' * 12  # 12字节全为1
        self.BLOCK_SIZE = 8192  # 8KB块大小
        
    def decrypt_file(self, encrypted_data):
        """
        使用ChaCha20解密文件数据
        
        Args:
            encrypted_data (bytes): 加密的数据
            
        Returns:
            bytes: 解密后的数据
        """
        try:
            print(f"开始解密文件...")
            print(f"加密数据大小: {len(encrypted_data)} 字节")
            
            # 准备密钥和nonce
            key_bytes = self.CHACHA20_KEY.encode('utf-8')
            
            # 确保密钥长度为32字节
            if len(key_bytes) < 32:
                key_bytes = key_bytes.ljust(32, b'\x00')
            elif len(key_bytes) > 32:
                key_bytes = key_bytes[:32]
            
            print(f"密钥长度: {len(key_bytes)} 字节")
            print(f"Nonce长度: {len(self.CHACHA20_NONCE)} 字节")
            
            # 创建ChaCha20实例
            chacha20 = ChaCha20(key_bytes, self.CHACHA20_NONCE)
            
            # 分块解密以处理大文件
            decrypted_chunks = []
            total_blocks = (len(encrypted_data) + self.BLOCK_SIZE - 1) // self.BLOCK_SIZE
            
            for i in range(0, len(encrypted_data), self.BLOCK_SIZE):
                chunk = encrypted_data[i:i + self.BLOCK_SIZE]
                
                # 重置计数器为块索引（模拟 Flutter 实现）
                chacha20.counter = i // 64
                
                # 解密块
                decrypted_chunk = chacha20.decrypt(chunk)
                decrypted_chunks.append(decrypted_chunk)
                
                # 显示进度
                current_block = i // self.BLOCK_SIZE + 1
                if current_block % 10 == 0 or current_block == total_blocks:
                    progress = (current_block / total_blocks) * 100
                    print(f"解密进度: {progress:.1f}% ({current_block}/{total_blocks})")
            
            # 合并所有解密的块
            result = b''.join(decrypted_chunks)
            
            print(f"解密完成，解密数据大小: {len(result)} 字节")
            
            # 检查是否是有效的ZIP文件
            if len(result) >= 2 and result[:2] == b'PK':
                print("解密结果看起来像有效的ZIP文件")
            else:
                print("警告: 解密结果不像ZIP文件，可能解密失败")
                print(f"前几个字节: {' '.join(f'0x{b:02x}' for b in result[:10])}")
            
            return result
            
        except Exception as e:
            print(f"文件解密失败: {e}")
            raise
    
    def extract_zip_files(self, zip_data, output_dir):
        """
        从ZIP数据中提取文件
        
        Args:
            zip_data (bytes): ZIP文件数据
            output_dir (str): 输出目录
            
        Returns:
            list: 提取的文件列表
        """
        try:
            print("开始解压ZIP文件...")
            
            # 创建输出目录
            os.makedirs(output_dir, exist_ok=True)
            
            extracted_files = []
            
            with zipfile.ZipFile(io.BytesIO(zip_data), 'r') as zip_file:
                for file_info in zip_file.filelist:
                    if not file_info.is_dir():
                        print(f"解压文件: {file_info.filename}")
                        
                        # 读取文件内容
                        content = zip_file.read(file_info.filename)
                        
                        # 保存到输出目录
                        output_path = os.path.join(output_dir, file_info.filename)
                        os.makedirs(os.path.dirname(output_path), exist_ok=True)
                        
                        with open(output_path, 'wb') as f:
                            f.write(content)
                        
                        extracted_files.append(output_path)
            
            print(f"解压完成，共 {len(extracted_files)} 个文件")
            return extracted_files
            
        except Exception as e:
            print(f"ZIP解压失败: {e}")
            raise
    
    def decrypt_plaud_file(self, input_file, output_dir=None):
        """
        解密Plaud日志文件
        
        Args:
            input_file (str): 输入的.plaud文件路径
            output_dir (str): 输出目录，默认为输入文件同目录
            
        Returns:
            list: 解密后的文件列表
        """
        try:
            # 检查输入文件
            if not os.path.exists(input_file):
                raise FileNotFoundError(f"输入文件不存在: {input_file}")
            
            if not input_file.lower().endswith('.plaud'):
                print("警告: 文件扩展名不是.plaud")
            
            # 设置输出目录
            if output_dir is None:
                input_path = Path(input_file)
                output_dir = input_path.parent / f"{input_path.stem}_decrypted"
            
            print(f"输入文件: {input_file}")
            print(f"输出目录: {output_dir}")
            
            # 读取加密文件
            print("读取加密文件...")
            with open(input_file, 'rb') as f:
                encrypted_data = f.read()
            
            # 解密文件
            decrypted_data = self.decrypt_file(encrypted_data)
            
            # 提取ZIP文件
            extracted_files = self.extract_zip_files(decrypted_data, output_dir)
            
            print(f"\n解密成功！")
            print(f"输出目录: {output_dir}")
            print(f"提取的文件:")
            for file_path in extracted_files:
                file_size = os.path.getsize(file_path)
                print(f"  - {file_path} ({file_size} 字节)")
            
            return extracted_files
            
        except Exception as e:
            print(f"解密失败: {e}")
            raise


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description='Plaud日志解密器 - 解密.plaud文件并提取ZIP内容',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用示例:
  python plaudDecryptor.py input.plaud
  python plaudDecryptor.py input.plaud -o /path/to/output
  python plaudDecryptor.py input.plaud --output-dir /path/to/output
        """
    )
    
    parser.add_argument(
        'input_file',
        help='输入的.plaud文件路径'
    )
    
    parser.add_argument(
        '-o', '--output-dir',
        help='输出目录路径（默认为输入文件同目录下的_decrypted文件夹）'
    )
    
    parser.add_argument(
        '--version',
        action='version',
        version='Plaud日志解密器 v1.0'
    )
    
    args = parser.parse_args()
    
    try:
        # 创建解密器实例
        decryptor = PlaudDecryptor()
        
        # 执行解密
        extracted_files = decryptor.decrypt_plaud_file(
            args.input_file,
            args.output_dir
        )
        
        print(f"\n✅ 解密完成！共提取 {len(extracted_files)} 个文件")
        
    except KeyboardInterrupt:
        print("\n\n用户中断操作")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
