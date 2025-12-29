# fpga-lps-kasami-preamble
Tubes Sistem Digital 2025

Folder ini berisi kode VHDL yang dibuat secara _bottom-up_ yang berfungsi dalam melakukan pendeteksian _preamble_ a dan b yang terdapat pada sebuah sinyal yang digenerate melalui kode python dan diperoleh grafik hasil korelasi ketika pendeteksian _preamble_ a dan _preamble_ b terjadi pada laptop/pc dan waktu yang dibutuhkan untuk mendeteksi masing-masing _preamble_. Laporan terkait projek ini dapat dilihat pada folder laporan (belum lengkap). Kode apabila diurutkan secara top-down akan terlihat seperti di bawah ini:

SYSTEM_TOP_LEVEL.vhd

│

├── MAIN_FSM_CONTROLLER.vhd  (The Brain)

│

├── VIRTUAL_ADC_INTERFACE.vhd (Wrapper)

│   ├── clock_div_160k.vhd

│   ├── uart_rx.vhd

│   └── fifo_8bit_4096.vhd (Quartus IP)

│

├── PREAMBLE_PROCESSOR.vhd (Wrapper)

│   ├── bpsk_demodulator.vhd

│   │

│   └── KASAMI_CORRELATOR_SYSTEM.vhd (Wrapper)

│       ├── memory_controller.vhd

│       ├── kasami_lut.vhd           <-- The Code Generator (Instantiated twice: A & B)

│       ├── correlator_engine.vhd    <-- The Math Pipeline (Instantiated twice: A & B)

│       └── ram_dual_port.vhd        (Quartus IP)

│

└── OUTPUT_INTERFACE.vhd (Wrapper)

|   |── display_controller.vhd

|       └── seven_seg_scanner.vhd    <-- (Optional sub-block, or logic inside controller)

|   ├── uart_tx.vhd

|   └── fifo_36bit_256.vhd (Quartus IP)
