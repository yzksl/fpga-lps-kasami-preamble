import matplotlib.pyplot as plt
import csv
import sys
import os

# ==========================================
# 1. CONFIGURATION
# ==========================================
INPUT_FILE = 'scores_output.csv'

# Colors (Matplotlib & Terminal)
COLOR_A = 'tab:red'
COLOR_B = 'tab:cyan'

# ANSI Colors for Terminal
C_GREEN = '\033[92m'
C_CYAN  = '\033[96m'
C_RED   = '\033[91m'
C_RESET = '\033[0m'
C_BOLD  = '\033[1m'

def load_data(filename):
    indices = []
    scores_a = []
    scores_b = []
    
    if not os.path.exists(filename):
        print(f"{C_RED}Error: File '{filename}' not found.{C_RESET}")
        print("Run 'uart_interface.py' first.")
        sys.exit(1)

    print(f"{C_GREEN}Loading data from {filename}...{C_RESET}")
    
    with open(filename, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                indices.append(int(row['Index']))
                scores_a.append(int(row['Score_A']))
                scores_b.append(int(row['Score_B']))
            except ValueError:
                continue # Skip bad lines
                
    return indices, scores_a, scores_b

def analyze_peaks(indices, scores, name):
    """Finds the maximum correlation peak and its index."""
    if not scores: return 0, 0
    
    # Simple max search
    max_score = max(scores)
    
    # Handle negative peaks? Usually correlation magnitude matters, 
    # but for standard Kasami/BPSK, we usually look for positive matches.
    # If you inverted the signal, you might need min(scores).
    # We will assume positive peaks for now.
    
    peak_idx = indices[scores.index(max_score)]
    
    return peak_idx, max_score

def main():
    print(f"{C_CYAN}=== Correlation Visualizer ==={C_RESET}")
    
    # 1. Load Data
    idxs, a_vals, b_vals = load_data(INPUT_FILE)
    
    if len(idxs) == 0:
        print(f"{C_RED}Error: No data in CSV.{C_RESET}")
        sys.exit(1)

    # 2. Analyze Peaks
    peak_idx_a, peak_val_a = analyze_peaks(idxs, a_vals, "A")
    peak_idx_b, peak_val_b = analyze_peaks(idxs, b_vals, "B")
    
    print("-" * 40)
    print(f"{C_BOLD}Analysis Report:{C_RESET}")
    print(f"Total Samples : {len(idxs)}")
    print(f"Peak Score A  : {peak_val_a} at Index {C_RED}{peak_idx_a}{C_RESET}")
    print(f"Peak Score B  : {peak_val_b} at Index {C_CYAN}{peak_idx_b}{C_RESET}")
    
    # Calculate Distance (Delta T)
    delta_samples = abs(peak_idx_a - peak_idx_b)
    print(f"Delta Samples : {delta_samples}")
    print("-" * 40)

    # 3. Plotting
    print(f"{C_GREEN}Launching Graph Window...{C_RESET}")
    
    # Create two subplots sharing the X axis
    fig, (ax1, ax2) = plt.subplots(2, 1, sharex=True, figsize=(10, 8))
    fig.canvas.manager.set_window_title('FPGA Correlation Results')

    # --- PLOT SCORE A ---
    ax1.plot(idxs, a_vals, color=COLOR_A, label='Score A (Kasami A)', linewidth=1)
    ax1.set_ylabel('Correlation Score')
    ax1.set_title(f'Sequence A Detection (Peak: {peak_val_a} @ {peak_idx_a})')
    ax1.grid(True, which='both', linestyle='--', alpha=0.6)
    ax1.legend(loc='upper right')
    
    # Annotate Peak A
    ax1.annotate(f'Peak: {peak_val_a}', 
                 xy=(peak_idx_a, peak_val_a), 
                 xytext=(peak_idx_a, peak_val_a + (max(a_vals)*0.1)),
                 arrowprops=dict(facecolor='black', shrink=0.05))

    # --- PLOT SCORE B ---
    ax2.plot(idxs, b_vals, color=COLOR_B, label='Score B (Kasami B)', linewidth=1)
    ax2.set_xlabel('Sample Index (Time)')
    ax2.set_ylabel('Correlation Score')
    ax2.set_title(f'Sequence B Detection (Peak: {peak_val_b} @ {peak_idx_b})')
    ax2.grid(True, which='both', linestyle='--', alpha=0.6)
    ax2.legend(loc='upper right')

    # Annotate Peak B
    ax2.annotate(f'Peak: {peak_val_b}', 
                 xy=(peak_idx_b, peak_val_b), 
                 xytext=(peak_idx_b, peak_val_b + (max(b_vals)*0.1)),
                 arrowprops=dict(facecolor='black', shrink=0.05))

    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    main()