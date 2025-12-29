import serial
import serial.tools.list_ports
import matplotlib.pyplot as plt
import random
import time
import sys
import os

# ==========================================
# 1. GLOBAL CONFIGURATION
# ==========================================
DEFAULT_BAUD = 115200
DEFAULT_PORT = '/dev/ttyUSB0'  # Arch Linux default

BYTES_PER_FRAME   = 5     # 40 bits total per sample
TOTAL_SAMPLES     = 4096  # Buffer depth
OVERSAMPLE_FACTOR = 4     # M=4
SEQ_LENGTH_BITS   = 255   # Kasami Length

KASAMI_SEQ_A = "100100001010011111010101011100000110001010110011001011111101111001101110111001010100101000100101101000110011100111100011011000010001011101011110110111110000110100110101101101010000010011101100100100110000001110100100011100010000000101100011110100001111111"
KASAMI_SEQ_B = "011110111000010000000011001101111100111000111100011101101100000011011100110110000010111001011111011010111100110001110010100010100011010010001000100110001010000110111010111011000001101001011110101011100110011111011110101110011111010011110010001110111101110"

C_GREEN = '\033[92m'
C_CYAN  = '\033[96m'
C_RED   = '\033[91m'
C_RESET = '\033[0m'
C_BOLD  = '\033[1m'

# ==========================================
# 2. SIGNAL GENERATION MODULE
# ==========================================
class SignalGenerator:
    def __init__(self, samples=4096, sig_amp=50, noise_amp=5):
        self.samples = samples
        self.sig_amp = sig_amp
        self.noise_amp = noise_amp
        self.buffer = [0] * samples
        self.mask = [0] * samples

    def inject(self, seq_str, end_idx, mask_id):
        if end_idx == 0: return
        seq_len_samples = SEQ_LENGTH_BITS * OVERSAMPLE_FACTOR
        start_idx = end_idx - seq_len_samples + 1

        for i, bit in enumerate(seq_str):
            val = self.sig_amp if bit == '1' else -self.sig_amp
            for k in range(OVERSAMPLE_FACTOR):
                idx = start_idx + (i * OVERSAMPLE_FACTOR) + k
                if 0 <= idx < len(self.buffer):
                    self.buffer[idx] += val
                    self.mask[idx] |= mask_id

    def generate(self, end_a, end_b):
        self.buffer = [0] * self.samples
        self.mask = [0] * self.samples

        self.inject(KASAMI_SEQ_A, end_a, 1)
        self.inject(KASAMI_SEQ_B, end_b, 2)

        byte_data = bytearray()
        for s in self.buffer:
            noise = int(random.gauss(0, self.noise_amp))
            val = s + noise
            if val > 127: val = 127
            if val < -128: val = -128
            if val < 0: val = (val + 256) & 0xFF
            byte_data.append(val)

        return byte_data

# ==========================================
# 3. UART MODULE
# ==========================================
def get_serial_port():
    ports = serial.tools.list_ports.comports()
    if not ports:
        print(f"{C_RED}No serial ports found!{C_RESET}")
        return DEFAULT_PORT

    print(f"\n{C_CYAN}--- Select Serial Port ---{C_RESET}")
    for i, p in enumerate(ports):
        print(f"[{i}] {p.device} ({p.description})")

    val = input(f"Choice [0]: ")
    if val == "": return ports[0].device
    if val.isdigit() and int(val) < len(ports):
        return ports[int(val)].device
    return val

def sign_extend_18bit(val):
    if val & (1 << 17):
        return val - (1 << 18)
    return val

def unpack_scores(rx_bytes):
    scores_a = []
    scores_b = []

    for i in range(0, len(rx_bytes), BYTES_PER_FRAME):
        chunk = rx_bytes[i : i + BYTES_PER_FRAME]
        if len(chunk) < BYTES_PER_FRAME: break

        full_val = (chunk[0]) | (chunk[1] << 8) | (chunk[2] << 16) | \
                   (chunk[3] << 24) | (chunk[4] << 32)

        raw_a = full_val & 0x3FFFF
        raw_b = (full_val >> 18) & 0x3FFFF

        scores_a.append(sign_extend_18bit(raw_a))
        scores_b.append(sign_extend_18bit(raw_b))

    return scores_a, scores_b

# ==========================================
# 4. PLOTTING MODULE
# ==========================================
def plot_results(indices, a_vals, b_vals):
    peak_val_a = max(a_vals) if a_vals else 0
    peak_idx_a = indices[a_vals.index(peak_val_a)] if a_vals else 0

    peak_val_b = max(b_vals) if b_vals else 0
    peak_idx_b = indices[b_vals.index(peak_val_b)] if b_vals else 0

    delta = abs(peak_idx_a - peak_idx_b)

    print(f"\n{C_BOLD}--- RESULTS ---{C_RESET}")
    print(f"Peak A: {peak_val_a} @ Index {peak_idx_a}")
    print(f"Peak B: {peak_val_b} @ Index {peak_idx_b}")
    print(f"Delta : {delta} samples")

    fig, (ax1, ax2) = plt.subplots(2, 1, sharex=True, figsize=(10, 8))
    fig.canvas.manager.set_window_title('FPGA Hardware-in-Loop Test')

    ax1.plot(indices, a_vals, 'r-', linewidth=1, label='Score A')
    ax1.set_title(f'Kasami A Detection (Peak: {peak_val_a} @ {peak_idx_a})')
    ax1.set_ylabel('Correlation')
    ax1.grid(True, alpha=0.6)
    ax1.annotate(f'Peak', xy=(peak_idx_a, peak_val_a), arrowprops=dict(facecolor='black', shrink=0.05))

    ax2.plot(indices, b_vals, 'c-', linewidth=1, label='Score B')
    ax2.set_title(f'Kasami B Detection (Peak: {peak_val_b} @ {peak_idx_b})')
    ax2.set_ylabel('Correlation')
    ax2.set_xlabel('Sample Index')
    ax2.grid(True, alpha=0.6)
    ax2.annotate(f'Peak', xy=(peak_idx_b, peak_val_b), arrowprops=dict(facecolor='black', shrink=0.05))

    plt.tight_layout()
    plt.show()

# ==========================================
# 5. MAIN APPLICATION
# ==========================================
def main():
    print(f"{C_GREEN}=== FPGA ULTRASONIC LPS TESTBENCH ==={C_RESET}")

    port = get_serial_port()

    print(f"\n{C_CYAN}--- Signal Configuration ---{C_RESET}")
    end_a_def = 2000
    end_b_def = 3000

    try:
        val = input(f"End Index A (0=Off) [{end_a_def}]: ")
        end_a = int(val) if val else end_a_def

        val = input(f"End Index B (0=Off) [{end_b_def}]: ")
        end_b = int(val) if val else end_b_def
    except ValueError:
        print("Invalid input, using defaults.")
        end_a, end_b = end_a_def, end_b_def

    print(f"\n{C_GREEN}[1/4] Generating Signal...{C_RESET}")
    gen = SignalGenerator(TOTAL_SAMPLES, sig_amp=50, noise_amp=5)
    tx_payload = gen.generate(end_a, end_b)
    print(f"Generated {len(tx_payload)} bytes. (Noise +/- 5, Sig +/- 50)")

    try:
        with serial.Serial(port, DEFAULT_BAUD, timeout=10) as ser:
            # 1. SEND
            print(f"{C_GREEN}[2/4] Uploading to FPGA...{C_RESET}")
            ser.reset_input_buffer()
            ser.reset_output_buffer()

            start_t = time.time()
            ser.write(tx_payload)
            print(f"Sent {len(tx_payload)} bytes in {time.time()-start_t:.3f}s.")

            # 2. WAIT for FPGA to finish processing
            processing_time_s = 1.0  # Adjust this based on FPGA speed
            print(f"{C_CYAN}Waiting {processing_time_s}s for FPGA to process...{C_RESET}")
            time.sleep(processing_time_s)

            # 3. RECEIVE
            print(f"{C_GREEN}[3/4] Receiving Data...{C_RESET}")
            expected_bytes = TOTAL_SAMPLES * BYTES_PER_FRAME
            rx_data = bytearray()

            while len(rx_data) < expected_bytes:
                chunk = ser.read(expected_bytes - len(rx_data))
                if not chunk: break
                rx_data.extend(chunk)
                print(f"\rReceived {len(rx_data)}/{expected_bytes} bytes", end='', flush=True)
            print()

            if len(rx_data) != expected_bytes:
                print(f"{C_RED}Warning: Incomplete Read! Got {len(rx_data)}/{expected_bytes} bytes.{C_RESET}")

    except serial.SerialException as e:
        print(f"{C_RED}Serial Error: {e}{C_RESET}")
        sys.exit(1)

    # 4. UNPACK & PLOT
    print(f"{C_GREEN}[4/4] Processing Results...{C_RESET}")
    if len(rx_data) == 0:
        print("No data received. Exiting.")
        sys.exit(1)

    scores_a, scores_b = unpack_scores(rx_data)
    indices = list(range(len(scores_a)))

    plot_results(indices, scores_a, scores_b)

if __name__ == "__main__":
    main()
