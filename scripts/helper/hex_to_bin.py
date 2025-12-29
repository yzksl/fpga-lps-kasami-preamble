#!/usr/bin/env python3
import sys
import binascii

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <hex_string> <output_file>")
        print("Example:")
        print(f"  {sys.argv[0]} A1B2C3 out.bin")
        sys.exit(1)

    hex_str = sys.argv[1]
    out_file = sys.argv[2]

    # Clean up common formats
    hex_str = hex_str.replace(" ", "").replace("_", "")
    if hex_str.startswith(("0x", "0X")):
        hex_str = hex_str[2:]

    # Validate
    if len(hex_str) % 2 != 0:
        print("❌ Error: hex string must have even number of characters.")
        sys.exit(1)

    try:
        data = binascii.unhexlify(hex_str)
    except binascii.Error as e:
        print(f"❌ Invalid hex string: {e}")
        sys.exit(1)

    with open(out_file, "wb") as f:
        f.write(data)

    print(f"✅ Wrote {len(data)} bytes to {out_file}")

if __name__ == "__main__":
    main()
