#!/usr/bin/env python3
"""
Converte binário RISC-V (little-endian) para formato $readmemh do Verilator.
Uma palavra de 32 bits por linha, em hexadecimal.

Uso: python3 bin2hex.py <entrada.bin> <saida.hex>
"""
import struct
import sys

if len(sys.argv) != 3:
    print("Uso: " + sys.argv[0] + " <entrada.bin> <saida.hex>", file=sys.stderr)
    sys.exit(1)

with open(sys.argv[1], 'rb') as f:
    data = f.read()

# Pad to 4-byte alignment / Garante alinhamento de 4 bytes
while len(data) % 4:
    data += b'\x00'

with open(sys.argv[2], 'w') as f:
    for i in range(0, len(data), 4):
        word = struct.unpack_from('<I', data, i)[0]
        f.write(f'{word:08x}\n')

print(f"[bin2hex] {len(data)//4} palavras → {sys.argv[2]}")
