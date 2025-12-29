import random
import sys
import math  # Added for sin() and radians()

# ==========================================
# 1. HARDCODED SEQUENCES
# ==========================================
KASAMI_SEQ_A = "100100001010011111010101011100000110001010110011001011111101111001101110111001010100101000100101101000110011100111100011011000010001011101011110110111110000110100110101101101010000010011101100100100110000001110100100011100010000000101100011110100001111111"
KASAMI_SEQ_B = "011110111000010000000011001101111100111000111100011101101100000011011100110110000010111001011111011010111100110001110010100010100011010010001000100110001010000110111010111011000001101001011110101011100110011111011110101110011111010011110010001110111101110"

# ==========================================
# 2. CONFIGURATION MODE
# ==========================================
USE_HARDCODED_INPUTS = True  # Set to False to test Phase Inputs

# Defaults if USE_HARDCODED_INPUTS is True
HC_TOTAL_SAMPLES = 4096
HC_END_INDEX_A   = 1420   
HC_END_INDEX_B   = 2620   
HC_PHASE_A       = 0      # Degrees
HC_PHASE_B       = 45     # Degrees (Test the strong signal case)
HC_SIGNAL_AMP    = 50     
HC_NOISE_AMP     = 5     

# ==========================================
# 3. CONSTANTS & COLORS
# ==========================================
OVERSAMPLE_FACTOR = 4
SEQ_LENGTH_BITS   = 255
SEQ_LENGTH_SAMPLES = SEQ_LENGTH_BITS * OVERSAMPLE_FACTOR  # 1020 samples

# ANSI Colors
C_RESET  = '\033[0m'
C_NOISE  = '\033[90m' # Gray
C_SEQ_A  = '\033[91m' # Red
C_SEQ_B  = '\033[96m' # Cyan
C_BOTH   = '\033[95m' # Purple (Overlap)
C_GREEN  = '\033[92m'
C_YELLOW = '\033[93m'

def get_valid_int(prompt, min_val, max_val, default=None):
    while True:
        try:
            p_str = f"{prompt} ({min_val}-{max_val})"
            if default is not None:
                p_str += f" [{default}]"
            
            user_input = input(f"{p_str}: ")
            
            if user_input.strip() == "" and default is not None:
                return default
            
            val = int(user_input)
            if min_val <= val <= max_val:
                return val
            print(f"Error: Value must be between {min_val} and {max_val}")
        except ValueError:
            print("Error: Invalid integer.")

def to_hex_8bit(val):
    """Converts int (-128 to 127) to 2-char Hex (2's complement)."""
    # Clip to verify validity before hex conversion
    if val > 127: val = 127
    if val < -128: val = -128
    if val < 0: val = (val + 256) & 0xFF
    return f"{val:02X}"

def inject_sequence_sine(buffer, mask_buf, seq_str, end_idx, amplitude, phase_deg, mask_bit):
    """
    Generates BPSK modulated sine waves with configurable phase shift.
    Phase Shift 0 deg -> Samples at 0, 90, 180, 270 (Ideal Sin: 0, 1, 0, -1)
    Phase Shift 45 deg -> Samples at 45, 135, 225, 315
    """
    if end_idx == 0: return
    
    start_idx = end_idx - SEQ_LENGTH_SAMPLES + 1
    
    # Pre-calculate radians for the phase shift
    phase_rad = math.radians(phase_deg)

    for i, bit in enumerate(seq_str):
        # BPSK Polarity: '1' -> +1, '0' -> -1 (180 deg phase flip)
        polarity = 1 if bit == '1' else -1
        
        for k in range(OVERSAMPLE_FACTOR):
            # Calculate sampling angle: (0, 90, 180, 270) + Phase Shift
            angle_deg = (k * 90)
            angle_rad = math.radians(angle_deg)
            
            # The Formula: Amp * Polarity * sin(theta + phi)
            raw_val = amplitude * polarity * math.sin(angle_rad + phase_rad)
            
            # Accumulate into buffer (integer)
            idx = start_idx + (i * OVERSAMPLE_FACTOR) + k
            if 0 <= idx < len(buffer):
                buffer[idx] += int(raw_val)
                mask_buf[idx] |= mask_bit

def main():
    print(f"\n{C_GREEN}=== FPGA Signal Generator (BPSK Sine Wave) ==={C_RESET}")
    print(f"Sequence Length: {SEQ_LENGTH_BITS} bits * {OVERSAMPLE_FACTOR}x = {SEQ_LENGTH_SAMPLES} samples")

    # --- INPUT PHASE ---
    if USE_HARDCODED_INPUTS:
        print(f"{C_YELLOW}[INFO] Using Hardcoded Inputs{C_RESET}")
        total_samples = HC_TOTAL_SAMPLES
        end_idx_a = HC_END_INDEX_A
        end_idx_b = HC_END_INDEX_B
        phase_a = HC_PHASE_A
        phase_b = HC_PHASE_B
        sig_amp = HC_SIGNAL_AMP
        noise_amp = HC_NOISE_AMP
    else:
        # 1. Total Samples
        total_samples = get_valid_int("Total Samples", SEQ_LENGTH_SAMPLES + 100, 65535, 4096)
        
        # 2. Sequence A
        print(f"\n{C_GREEN}--- Sequence A Setup ---{C_RESET}")
        min_end = SEQ_LENGTH_SAMPLES - 1
        max_end = total_samples - 1
        end_idx_a = get_valid_int("End Index A (0 to disable)", 0, max_end, 2000)
        phase_a = 0
        if end_idx_a != 0:
            phase_a = get_valid_int("Phase Misalignment A (degrees)", 0, 360, 0)
        
        # 3. Sequence B
        print(f"\n{C_GREEN}--- Sequence B Setup ---{C_RESET}")
        end_idx_b = get_valid_int("End Index B (0 to disable)", 0, max_end, 3000)
        phase_b = 0
        if end_idx_b != 0:
            phase_b = get_valid_int("Phase Misalignment B (degrees)", 0, 360, 45)

        # 4. Amplitudes
        print(f"\n{C_GREEN}--- Signal Properties ---{C_RESET}")
        sig_amp = get_valid_int("Signal Amplitude", 1, 127, 50)
        noise_amp = get_valid_int("Noise Amplitude", 0, 50, 5)

    # --- GENERATION PHASE ---
    samples = [0] * total_samples
    mask = [0] * total_samples 
    
    # Inject Signals with specified phases
    inject_sequence_sine(samples, mask, KASAMI_SEQ_A, end_idx_a, sig_amp, phase_a, 1)
    inject_sequence_sine(samples, mask, KASAMI_SEQ_B, end_idx_b, sig_amp, phase_b, 2)

    # Add Noise & Hex Conversion
    final_hex_chars = []
    for s in samples:
        noise = int(random.gauss(0, noise_amp))
        val = s + noise
        final_hex_chars.append(to_hex_8bit(val))

    # --- FILE OUTPUT ---
    full_hex_str = "".join(final_hex_chars)
    filename = "signal_output.txt"
    with open(filename, "w") as f:
        f.write(full_hex_str)

    # --- DETAILED REPORT ---
    print("\n" + "="*50)
    print(f"{C_GREEN}              GENERATION REPORT              {C_RESET}")
    print("="*50)
    print(f"Total Samples  : {total_samples}")
    print(f"Noise Amp      : +/- {noise_amp}")
    print("-" * 50)
    
    if end_idx_a > 0:
        print(f"Sequence A     : {C_SEQ_A}ACTIVE{C_RESET}")
        print(f"  > Phase Shift: {phase_a}°")
        print(f"  > End Index  : {end_idx_a}")
    else:
        print(f"Sequence A     : {C_NOISE}DISABLED{C_RESET}")

    if end_idx_b > 0:
        print(f"Sequence B     : {C_SEQ_B}ACTIVE{C_RESET}")
        print(f"  > Phase Shift: {phase_b}°")
        print(f"  > End Index  : {end_idx_b}")
    else:
        print(f"Sequence B     : {C_NOISE}DISABLED{C_RESET}")
    
    print("="*50)
    print(f"[SUCCESS] Data saved to '{filename}'")

    # --- VISUALIZATION ---
    print(f"\n{C_RESET}Visualization Legend:")
    print(f"{C_NOISE}■ Noise Only{C_RESET} | {C_SEQ_A}■ Seq A{C_RESET} | {C_SEQ_B}■ Seq B{C_RESET} | {C_BOTH}■ Overlap{C_RESET}")
    
    do_print = input("\nShow colored hex dump? (y/N): ").lower()
    if do_print == 'y':
        print("-" * 64)
        row_count = 0
        for i, hex_val in enumerate(final_hex_chars):
            m = mask[i]
            color = C_NOISE
            if m == 1: color = C_SEQ_A
            elif m == 2: color = C_SEQ_B
            elif m == 3: color = C_BOTH
            print(f"{color}{hex_val}{C_RESET}", end="")
            row_count += 1
            if row_count >= 32: 
                print() 
                row_count = 0
        print("\n" + "-" * 64)

if __name__ == "__main__":
    main()