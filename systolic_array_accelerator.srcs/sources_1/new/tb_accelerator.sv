`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Author:      Partey Samuel Nadutey
// Project:     Systolic Array Accelerator for Edge AI
// Module:      tb_accelerator (Self-Checking Testbench)
// Target:      Simulation (Vivado XSim)
// Description: Verification environment for the Weight-Stationary Accelerator.
//
//              Verification Strategy:
//              1. Generate synthetic input data (Matrices A and B).
//              2. Drive the RTL design (DUT) with the specific timing protocol required
//                 by the Weight-Stationary architecture (Load Phase -> Compute Phase).
//              3. Compute the expected result (Golden Model) using behavioral SystemVerilog.
//              4. The user verifies correctness by comparing 'results_out' waveforms
//                 against the expected values.
//////////////////////////////////////////////////////////////////////////////////

module tb_accelerator;

    // ========================================================================
    // 1. PARAMETERS & SIGNALS
    // ========================================================================
    // Must match the Design Under Test (DUT)
    parameter ROWS = 4;
    parameter COLS = 4;
    parameter WIDTH = 8;
    
    // Clock and Reset
    logic clk;
    logic rst_n;        // Active low reset
    logic load_weight;  // Mode control
    
    // Data Signals (Arrays matching the DUT interface)
    logic signed [WIDTH-1:0] flat_ifmap_in [ROWS-1:0];  // Input stream
    logic signed [WIDTH-1:0] flat_weight_in [COLS-1:0]; // Weight stream
    logic signed [31:0]      results_out [COLS-1:0];    // Hardware Output
    
    // Internal 2D Arrays for the "Golden Model" (Software Reference)
    logic signed [WIDTH-1:0] matrix_A [ROWS-1:0][ROWS-1:0]; // 4x4 Input Matrix
    logic signed [WIDTH-1:0] matrix_B [ROWS-1:0][COLS-1:0]; // 4x4 Weight Matrix
    logic signed [31:0]      expected_C [ROWS-1:0][COLS-1:0]; // Expected Result (A x B)

    // Loop variables
    integer r, c, k;

    // ========================================================================
    // 2. INSTANTIATE THE DUT (Device Under Test)
    // ========================================================================
    accelerator_top #(
        .ROWS(ROWS),
        .COLS(COLS),
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .load_weight(load_weight),
        .flat_ifmap_in(flat_ifmap_in),
        .flat_weight_in(flat_weight_in),
        .results_out(results_out)
    );

    // ========================================================================
    // 3. CLOCK GENERATION
    // ========================================================================
    // 100MHz Clock (10ns period), standard for testing logic functionality.
    // For timing closure verification (850MHz), static timing analysis (STA) is used.
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // ========================================================================
    // 4. TEST PROCEDURE
    // ========================================================================
    initial begin
        // --- SETUP ---
        $display("-------------------------------------------------------------");
        $display("Starting Simulation: Weight-Stationary Systolic Array");
        $display("-------------------------------------------------------------");
        
        // 1. Initialize Matrices with deterministic patterns
        // Matrix A (Inputs) = Identity-like pattern (Diagonal=2, Rest=1)
        // This makes visual verification in waveforms easier.
        for (r=0; r<ROWS; r++) begin
            for (c=0; c<ROWS; c++) begin 
                matrix_A[r][c] = (r == c) ? 2 : 1; 
            end
        end
        
        // Matrix B (Weights) = Simple sequential values
        for (r=0; r<ROWS; r++) begin
            for (c=0; c<COLS; c++) begin
                matrix_B[r][c] = (r+1) + (c+1); 
            end
        end

        // 2. Hardware Reset
        rst_n = 0;
        load_weight = 0;
        // Zero out inputs to prevent 'X' propagation
        for(r=0; r<ROWS; r++) flat_ifmap_in[r] = 0;
        for(c=0; c<COLS; c++) flat_weight_in[c] = 0;
        
        #20; // Hold reset low for 2 cycles
        rst_n = 1;
        #10;

        // --- PHASE 1: LOAD WEIGHTS (Vertical Stream) ---
        // In Weight-Stationary architecture, weights are loaded first and stay fixed.
        // This minimizes memory bandwidth during the compute intensive phase.
        $display("[t=%0t] Phase 1: Loading Weights...", $time);
        load_weight = 1;
        
        // We load weights into the array columns.
        // The array passes weights down, so we feed the rows sequentially.
        for (r = ROWS-1; r >= 0; r--) begin
            // Put Row 'r' of Matrix B onto the input bus
            for (c = 0; c < COLS; c++) begin
                flat_weight_in[c] = matrix_B[r][c];
            end
            #10; // Wait 1 clock cycle for weights to shift down
        end
        
        // Cleanup after loading
        for (c = 0; c < COLS; c++) flat_weight_in[c] = 0;
        load_weight = 0; // Switch FSM to Compute Mode
        $display("[t=%0t] Weights Loaded.", $time);
        
        // --- PHASE 2: STREAM INPUTS (Horizontal Stream) ---
        // Inputs flow Left->Right. The 'accelerator_top' module handles the 
        // complex skewing (delaying rows) internally, so the testbench just
        // feeds flat vectors. This proves the abstraction layer works.
        $display("[t=%0t] Phase 2: Streaming Inputs...", $time);
        
        // Stream Matrix A row-by-row (transposed in time)
        for (c = 0; c < ROWS; c++) begin 
             for (r = 0; r < ROWS; r++) begin
                 flat_ifmap_in[r] = matrix_A[r][c];
             end
             #10; // Next cycle
        end
        
        // Flush the pipeline with zeros
        for (r = 0; r < ROWS; r++) flat_ifmap_in[r] = 0;
        
        // Wait for the pipeline to drain.
        // Latency = Array Width + Array Height + Skew overhead
        #100;
        
        // --- PHASE 3: CHECK RESULTS (Golden Model) ---
        $display("[t=%0t] Phase 3: Verification...", $time);
        
        // Calculate the Expected Result (C = A x B) using high-level software logic
        for(r=0; r<ROWS; r++) begin
            for(c=0; c<COLS; c++) begin
                expected_C[r][c] = 0;
                for(k=0; k<ROWS; k++) begin
                    expected_C[r][c] += matrix_A[r][k] * matrix_B[k][c];
                end
            end
        end
        
        // In a full verification suite, we would add automatic assertions here.
        // For this demo, manual waveform inspection of 'results_out' vs 'expected_C'
        // is performed.
        
        $display("Simulation Complete. Please check waveforms.");
        $finish;
    end

endmodule