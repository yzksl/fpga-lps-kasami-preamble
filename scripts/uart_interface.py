import serial
import serial.tools.list_ports
import sys
import os
import time

# ==========================================
# 1. CONFIGURATION
# ==========================================
DEFAULT_PORT = '/dev/ttyUSB0'  # Arch Linux default
BAUD_RATE    = 115200          # Updated as requested
INPUT_FILE   = 'signal_output.txt'
OUTPUT_FILE  = 'scores_output.csv'

# Packet Structure
# 5 Bytes per sample = 40 bits total
# Logic: [4 bits Zero] [18 bits Score B] [18 bits Score A]
# Little Endian transmission
BYTES_PER_FRAME = 5
TOTAL_SAMPLES   = 4096

# ANSI Colors
C_GREEN = '\033[92m'
C_CYAN  = '\033[96m'
C_RED   = '\033[91m'
C_RESET = '\033[0m'

def list_serial_ports():
    ports = serial.tools.list_ports.comports()
    return [p.device for p in ports]

def get_valid_port():
    available = list_serial_ports()
    print(f"\n{C_CYAN}--- Serial Port Selection ---{C_RESET}")
    if not available:
        print(f"{C_RED}No serial ports found! Check connections.{C_RESET}")
        print(f"Assuming {DEFAULT_PORT} for testing...")
        return DEFAULT_PORT
    
    print("Available Ports:")
    for i, p in enumerate(available):
        print(f"  [{i}] {p}")
    
    choice = input(f"Select port index or type custom path [{available[0]}]: ")
    if choice == "":
        return available[0]
    
    if choice.isdigit() and int(choice) < len(available):
        return available[int(choice)]
    
    return choice

def sign_extend_18bit(val):
    """Converts unsigned 18-bit integer to signed Python integer."""
    # If the 18th bit (sign bit) is set, subtract 2^18
    if val & (1 << 17):
        return val - (1 << 18)
    return val

def main():
    print(f"{C_GREEN}=== UART Interface & Data Logger ==={C_RESET}")
    
    # 1. Confirm File Exists
    if not os.path.exists(INPUT_FILE):
        print(f"{C_RED}Error: Input file '{INPUT_FILE}' not found.{C_RESET}")
        print("Please run signal_gen.py first.")
        sys.exit(1)
        
    # 2. Confirm Settings
    port = get_valid_port()
    print(f"\n{C_CYAN}--- Confirmation ---{C_RESET}")
    print(f"Serial Port   : {port}")
    print(f"Baud Rate     : {BAUD_RATE}")
    print(f"Input File    : {INPUT_FILE}")
    print(f"Expected Data : {TOTAL_SAMPLES} samples * {BYTES_PER_FRAME} bytes = {TOTAL_SAMPLES*BYTES_PER_FRAME} bytes")
    
    confirm = input("\nIs this correct? (y/N): ").lower()
    if confirm != 'y':
        print("Aborted.")
        sys.exit(0)

    # 3. Load Data
    print(f"\n{C_GREEN}[1/4] Loading Signal Data...{C_RESET}")
    with open(INPUT_FILE, 'r') as f:
        hex_data = f.read().strip()
    
    # Convert hex string to raw bytes
    try:
        tx_payload = bytes.fromhex(hex_data)
        print(f"Loaded {len(tx_payload)} bytes from file.")
    except ValueError:
        print(f"{C_RED}Error: Input file contains invalid hex.{C_RESET}")
        sys.exit(1)

    # 4. Open Serial & Execute
    try:
        with serial.Serial(port, BAUD_RATE, timeout=2) as ser:
            # --- SENDING ---
            print(f"{C_GREEN}[2/4] Sending Waveform to FPGA...{C_RESET}")
            # Optional: Reset buffers
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            
            start_time = time.time()
            ser.write(tx_payload)
            print(f"Upload finished in {time.time() - start_time:.4f} seconds.")

            # --- WAITING ---
            print(f"\n{C_CYAN}--- FPGA PROCESSING ---{C_RESET}")
            print("1. Press 'SW_START' on FPGA to process data.")
            print("2. Wait for processing to finish.")
            print("3. FPGA should automatically send data back (Upload Phase).")
            input(f"{C_GREEN}Press ENTER immediately when you see the FPGA starting to send data...{C_RESET}")
            
            # --- RECEIVING ---
            print(f"{C_GREEN}[3/4] Receiving Results...{C_RESET}")
            print(f"Listening for {TOTAL_SAMPLES * BYTES_PER_FRAME} bytes...")
            
            # Increase timeout for the read operation
            ser.timeout = 5 
            rx_data = ser.read(TOTAL_SAMPLES * BYTES_PER_FRAME)
            
            if len(rx_data) != (TOTAL_SAMPLES * BYTES_PER_FRAME):
                print(f"{C_RED}Warning: Incomplete Read! Got {len(rx_data)} bytes.{C_RESET}")
            else:
                print("Data reception complete.")

    except serial.SerialException as e:
        print(f"{C_RED}Serial Error: {e}{C_RESET}")
        sys.exit(1)

    # 5. Parsing & Unpacking
    print(f"{C_GREEN}[4/4] Parsing & Saving...{C_RESET}")
    
    scores_a = []
    scores_b = []
    
    # Loop through the raw byte array in chunks of 5
    for i in range(0, len(rx_data), BYTES_PER_FRAME):
        chunk = rx_data[i : i + BYTES_PER_FRAME]
        if len(chunk) < 5: break
        
        # 1. Reconstruct the 40-bit Integer (Little Endian)
        # Byte 0 is LSB, Byte 4 is MSB
        full_val = (chunk[0]) | \
                   (chunk[1] << 8) | \
                   (chunk[2] << 16) | \
                   (chunk[3] << 24) | \
                   (chunk[4] << 32)
        
        # 2. Extract Bit Fields
        # Structure: [Padding 4b] [Score A 18b] [Score B 18b]
        
        # NEW CORRECT ORDER
        # Score B is LOW 18 bits
        raw_b = full_val & 0x3FFFF

        # Score A is bits [35:18]
        raw_a = (full_val >> 18) & 0x3FFFF

        
        # 3. Sign Extend (Convert to signed int)
        val_a = sign_extend_18bit(raw_a)
        val_b = sign_extend_18bit(raw_b)
        
        scores_a.append(val_a)
        scores_b.append(val_b)

    # 6. Save to CSV
    with open(OUTPUT_FILE, 'w') as f:
        # Header
        f.write("Index,Score_A,Score_B\n")
        for i in range(len(scores_a)):
            f.write(f"{i},{scores_a[i]},{scores_b[i]}\n")
            
    print(f"\n{C_CYAN}Success!{C_RESET}")
    print(f"Decoded {len(scores_a)} samples.")
    print(f"Data saved to: {C_GREEN}{OUTPUT_FILE}{C_RESET}")

if __name__ == "__main__":
    main()