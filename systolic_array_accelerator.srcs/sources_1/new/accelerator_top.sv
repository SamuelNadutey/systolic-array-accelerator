`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Author:      Partey Samuel Nadutey
// Project:     Systolic Array Accelerator for Edge AI
// Module:      accelerator_top (Top-Level Wrapper)
// Target:      Zynq-7000 (xc7z020)
// Description: The top-level hierarchy for the hardware accelerator.
//              It acts as the bridge between standard system memory (Flat Data)
//              and the specialized Systolic Array (Diagonal Data).
//
//              Key Functions:
//              1. Input Skewing: Converts parallel data streams into diagonal
//                 wavefronts required for systolic timing.
//              2. Control Distribution: Manages weight loading vs. computation.
//              3. Scalability: Parameterized entry point for the entire IP core.
//////////////////////////////////////////////////////////////////////////////////

module accelerator_top #(
    parameter ROWS = 4,   // Matrix Height (Batch size or Output Channels)
    parameter COLS = 4,   // Matrix Width (Output Features)
    parameter WIDTH = 8   // Input Precision (INT8)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic load_weight, // 1 = Load Weights into PEs, 0 = Stream Inputs & Compute
    
    // Flat Inputs (Standard Memory Order)
    // The external DRAM/SRAM sends data row-by-row at the same time.
    // We must reshape this in hardware to minimize memory controller complexity.
    input  logic signed [WIDTH-1:0] flat_ifmap_in [ROWS-1:0],
    input  logic signed [WIDTH-1:0] flat_weight_in [COLS-1:0],
    
    // Outputs
    // 32-bit Accumulated Results (INT8 * INT8 -> INT16 -> Accumulate -> INT32)
    output logic signed [31:0] results_out [COLS-1:0]
);

    // Internal wires connecting the Skew Buffers to the Systolic Array
    logic signed [WIDTH-1:0] skewed_ifmap [ROWS-1:0];

    // ========================================================================
    // 1. INPUT SKEWING UNIT (Data Shaping)
    // ========================================================================
    // To ensure the correct pixels meet the correct weights at the right time,
    // input data must enter as a "diagonal wave."
    // We achieve this by delaying Row N by N clock cycles.
    
    genvar i;
    generate
        for (i = 0; i < ROWS; i++) begin : input_skew_buffers
            skew_buffer #(
                .WIDTH(WIDTH),
                .DELAY(i)      // <--- THE SYSTOLIC MAGIC: Row 0 waits 0, Row 1 waits 1, etc.
            ) sb_inst (
                .clk(clk),
                .rst_n(rst_n),
                .d_in(flat_ifmap_in[i]),
                .d_out(skewed_ifmap[i])
            );
        end
    endgenerate

    // ========================================================================
    // 2. THE CORE SYSTOLIC ARRAY (The Math Engine)
    // ========================================================================
    // Instantiates the 2D grid of MAC units.
    
    systolic_array #(
        .ROWS(ROWS),
        .COLS(COLS),
        .WIDTH(WIDTH)
    ) core_inst (
        .clk(clk),
        .rst_n(rst_n),
        .load_weight(load_weight),
        
        // Connect the SKEWED inputs here (The Wavefront)
        .ifmap_in(skewed_ifmap),
        
        // Weights typically don't need skewing in "Load Mode" because we pause 
        // computation to load them vertically into the stationary registers.
        .weight_in(flat_weight_in),
        
        // Final Results exiting the bottom of the array
        .psum_out(results_out)
    );

endmodule