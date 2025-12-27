import re

def hex_2s_to_signed_decimal(hex_string):
    # extract 2-hex-digit tokens
    tokens = re.findall(r'[0-9A-Fa-f]{2}', hex_string)

    result = []
    for t in tokens:
        val = int(t, 16)
        if val >= 0x80:      # two's complement negative
            val -= 0x100
        result.append(val)

    return result

if __name__ == "__main__":
    hex_input = input("Enter hex bytes: ")
    decimals = hex_2s_to_signed_decimal(hex_input)
    print(",".join(str(d) for d in decimals))
