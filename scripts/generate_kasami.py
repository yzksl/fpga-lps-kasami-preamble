#!/usr/bin/env python3
"""
Kasami Sequence Generator for N=255 (n=8)
-----------------------------------------
Generates the "Small Set" of Kasami sequences which offers optimal 
cross-correlation properties (-1, -17, +15) for length 255.
"""

def feedback(state):
    """
    Primitive Polynomial for n=8: x^8 + x^4 + x^3 + x^2 + 1
    Taps: [8, 4, 3, 2, 0] -> indices 7, 3, 2, 1 (0-indexed logic)
    """
    # Using the polynomial x^8 + x^4 + x^3 + x^2 + 1
    # Taps at positions 8, 4, 3, 2 (corresponding to bits 7, 3, 2, 1 in a shift register)
    new_bit = (state >> 7) ^ (state >> 3) ^ (state >> 2) ^ (state >> 1)
    return new_bit & 1

def generate_m_sequence():
    """Generates the base Maximal Length Sequence (m-sequence) of length 255."""
    state = 0xFF  # Initial state (can't be 0)
    m_seq = []
    
    for _ in range(255):
        # Output the LSB
        output_bit = state & 1
        m_seq.append(output_bit)
        
        # Shift and add feedback
        fb = feedback(state)
        state = (state << 1) | fb
        state = state & 0xFF # Keep it 8-bit
        
    return m_seq

def decimate_sequence(seq, factor):
    """Decimates sequence by sampling every 'factor' indices."""
    return [seq[(i * factor) % len(seq)] for i in range(len(seq))]

def cyclic_shift(seq, k):
    """Rotates sequence left by k."""
    return seq[k:] + seq[:k]

def format_vhdl_string(seq):
    return '"' + ''.join(map(str, seq)) + '"'

def main():
    print("--- Generating Kasami Sequences (L=255) ---")
    
    # 1. Generate Base m-sequence (u)
    u = generate_m_sequence()
    
    # 2. Generate Decimated sequence (w)
    # For Kasami Small Set, decimation factor k = 2^(n/2) + 1
    # n=8, so k = 2^4 + 1 = 17
    w = decimate_sequence(u, 17)
    
    # 3. Create the Set
    # The set consists of 'u' and 'u XOR T^k(w)'
    # We will pick 'u' as Seq A, and 'u XOR w' as Seq B
    
    # Sequence A: The base m-sequence
    seq_a = u
    
    # Sequence B: Base XOR Decimated (Shift 0)
    seq_b = [(u[i] ^ w[i]) for i in range(255)]
    
    # Validation: Print Correlation to prove they are good
    # (Simple cross correlation at shift 0)
    correlation = sum([1 if seq_a[i] == seq_b[i] else -1 for i in range(255)])
    print(f"DEBUG: Cross-Correlation at Shift 0: {correlation} (Ideally small, e.g. -1, -17, or 15)")
    
    # 4. Output Strings
    str_a = "".join(map(str, seq_a))
    str_b = "".join(map(str, seq_b))
    
    print("\n[Copy these into your VHDL/Python Testbench]")
    print(f"KASAMI_SEQ_A = \"{str_a}\"")
    print(f"KASAMI_SEQ_B = \"{str_b}\"")

if __name__ == "__main__":
    main()