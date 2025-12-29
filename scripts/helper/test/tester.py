import math
import random
import matplotlib.pyplot as plt

# ==========================================
# 1. SETUP: KASAMI SEQUENCES
# ==========================================
KASAMI_SEQ_A = "100100001010011111010101011100000110001010110011001011111101111001101110111001010100101000100101101000110011100111100011011000010001011101011110110111110000110100110101101101010000010011101100100100110000001110100100011100010000000101100011110100001111111"
# We define Seq B just to add interference
KASAMI_SEQ_B = "011110111000010000000011001101111100111000111100011101101100000011011100110110000010111001011111011010111100110001110010100010100011010010001000100110001010000110111010111011000001101001011110101011100110011111011110101110011111010011110010001110111101110"

# Constants
OVERSAMPLE_FACTOR = 4
SEQ_LENGTH_BITS = 255
SEQ_LENGTH_SAMPLES = SEQ_LENGTH_BITS * OVERSAMPLE_FACTOR # 1020 Samples

# ==========================================
# 2. SIGNAL GENERATOR (Inputs)
# ==========================================
def generate_input_signal():
    total_samples = 4096
    sig_amp = 50
    noise_amp = 5
    buffer = [0] * total_samples
    
    # Helper to inject sine waves
    def inject(buf, seq, end_idx, amp, phase):
        start = end_idx - SEQ_LENGTH_SAMPLES + 1
        phase_rad = math.radians(phase)
        for i, bit in enumerate(seq):
            polarity = 1 if bit == '1' else -1
            for k in range(OVERSAMPLE_FACTOR):
                angle_deg = k * 90
                val = amp * polarity * math.sin(math.radians(angle_deg) + phase_rad)
                idx = start + (i * OVERSAMPLE_FACTOR) + k
                if 0 <= idx < len(buf):
                    buf[idx] += int(val) # Integer arithmetic

    # 1. Inject Valid Signal (Seq A) aligned to end at 1999
    # Start Index = 1999 - 1020 + 1 = 980 (Divisible by 4, perfectly aligned)
    inject(buffer, KASAMI_SEQ_A, 1999, sig_amp, phase=0)
    
    # 2. Inject Interference (Seq B) at 2999 (Misaligned phase 45 deg)
    inject(buffer, KASAMI_SEQ_B, 2999, sig_amp, phase=45)

    # 3. Add Noise
    noisy_buffer = []
    for s in buffer:
        noise = int(random.gauss(0, noise_amp))
        noisy_buffer.append(max(-128, min(127, s + noise)))
        
    return noisy_buffer

# ==========================================
# 3. RECEIVER PROCESS (The Perez Method)
# ==========================================
def run_fpga_process(input_samples, threshold=10000):
    # Prepare Template: +1 / -1
    template = [1 if bit == '1' else -1 for bit in KASAMI_SEQ_B]
    
    # Shift Register (Buffer) for 255 demodulated symbols
    demod_buffer = [0] * SEQ_LENGTH_BITS 
    
    scores = []
    detections = []
    
    # Loop through input 4 samples at a time (Symbol Rate)
    num_symbols = len(input_samples) // 4
    
    for sym_idx in range(num_symbols):
        # --- A. BPSK Demodulator ---
        # Read 4 samples
        base = sym_idx * 4
        s0, s1, s2, s3 = input_samples[base:base+4]
        
        # Calculate Soft Bit: (S0 + S1) - (S2 + S3)
        soft_bit = (s0 + s1) - (s2 + s3)
        
        # --- B. Update Buffer ---
        # Shift left, add new bit at end
        demod_buffer.pop(0)
        demod_buffer.append(soft_bit)
        
        # --- C. Kasami Correlator ---
        # Dot Product of Buffer vs Template
        current_score = 0
        for i in range(SEQ_LENGTH_BITS):
            current_score += demod_buffer[i] * template[i]
            
        scores.append(current_score)
        
        # --- D. Threshold Check ---
        # The 'current sample' is the last sample of the current symbol
        current_sample_num = (sym_idx + 1) * 4 - 1
        
        if current_score > threshold:
            # Save the first detection
            if not detections:
                print(f"[DETECTED] Threshold crossed at Sample {current_sample_num}")
                print(f"           Score: {current_score}")
            detections.append((current_sample_num, current_score))
            
    return scores

# ==========================================
# 4. EXECUTION
# ==========================================
samples = generate_input_signal()
scores = run_fpga_process(samples, threshold=10000)

# Plot
x_axis = [(i+1)*4 - 1 for i in range(len(scores))]
plt.figure(figsize=(10, 5))
plt.plot(x_axis, scores, label='Correlation Score')
plt.axhline(y=10000, color='r', linestyle='--', label='Threshold (10,000)')
plt.title('Receiver Output: Score vs Input Sample')
plt.xlabel('Sample Index')
plt.ylabel('Score')
plt.legend()
plt.grid(True)
plt.show()