`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Author:      Partey Samuel Nadutey
// Project:     Systolic Array Accelerator for Edge AI
// Module:      systolic_array (Core Grid Architecture)
// Target:      Zynq-7000 (xc7z020)
// Description: Top-level grid module for the Weight-Stationary Accelerator.
//              It instantiates a parameterized NxM grid of MAC PEs and handles
//              the "Systolic" data flow.
//
//              Data Flow Architecture:
//              - Horizontal: Input Feature Maps (Pixels) flow Left -> Right.
//                This maximizes data reuse (minimizing off-chip fetches).
//              - Vertical:   Partial Sums flow Top -> Bottom.
//              - Vertical:   Weights are pre-loaded vertically.
//////////////////////////////////////////////////////////////////////////////////

module systolic_array #(
    parameter ROWS = 4,   // Configurable array height (e.g., 4, 8, 16)
    parameter COLS = 4,   // Configurable array width
    parameter WIDTH = 8   // Data width (INT8 for quantized models)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic load_weight, // Global control: 1 = Load Weights, 0 = Compute
    
    // Array Inputs
    // Using "packed arrays" allows for cleaner top-level interfaces
    input  logic signed [WIDTH-1:0] ifmap_in [ROWS-1:0],  // Rows of Pixels entering from Left
    input  logic signed [WIDTH-1:0] weight_in [COLS-1:0], // Columns of Weights entering from Top
    
    // Array Outputs
    output logic signed [31:0]      psum_out [COLS-1:0]   // Columns of Results exiting at Bottom
);

    // ========================================================================
    // Internal Wires (The "Nervous System" of the Array)
    // ========================================================================
    
    // Horizontal wires: Carry pixels from PE[i][j] to PE[i][j+1]
    // Size is [ROWS][COLS+1] to include the wires exiting the last column
    logic signed [WIDTH-1:0] horizontal_wires [ROWS-1:0][COLS:0]; 
    
    // Vertical wires: Carry weights (during load) and sums (during compute)
    // Size is [ROWS+1][COLS] to include wires entering the top and exiting bottom
    logic signed [31:0]      vertical_sums    [ROWS:0][COLS-1:0];
    logic signed [WIDTH-1:0] vertical_weights [ROWS:0][COLS-1:0];

    genvar i, j;
    generate
        // --------------------------------------------------------------------
        // 1. Connect the Edges (Boundary Conditions)
        // --------------------------------------------------------------------
        for (i = 0; i < ROWS; i++) begin
            // Connect module input ports to the first column of wires (Left Edge)
            assign horizontal_wires[i][0] = ifmap_in[i]; 
        end
        
        for (j = 0; j < COLS; j++) begin
            // Initialize top sums to 0 (Start of the accumulator chain)
            assign vertical_sums[0][j]    = 32'd0;       
            // Connect module weight inputs to the top row (for vertical loading)
            assign vertical_weights[0][j] = weight_in[j];
        end

        // --------------------------------------------------------------------
        // 2. Instantiate the Grid (The Core Logic)
        // --------------------------------------------------------------------
        // This nested loop creates the physical mesh of PEs.
        // It connects every PE to its Right and Bottom neighbors.
        for (i = 0; i < ROWS; i++) begin : row_loop
            for (j = 0; j < COLS; j++) begin : col_loop
                
                mac_pe #(.WIDTH(WIDTH)) pe_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .load_weight(load_weight),
                    
                    // Left-to-Right Data Flow (Pixels)
                    .ifmap_in   (horizontal_wires[i][j]),
                    .ifmap_out  (horizontal_wires[i][j+1]),
                    
                    // Top-to-Bottom Data Flow (Weights)
                    .weight_in  (vertical_weights[i][j]),
                    .weight_out (vertical_weights[i+1][j]),
                    
                    // Top-to-Bottom Data Flow (Sums)
                    .psum_in    (vertical_sums[i][j]),
                    .psum_out   (vertical_sums[i+1][j])
                );
                
            end
        end
        
        // --------------------------------------------------------------------
        // 3. Output Assignment
        // --------------------------------------------------------------------
        for (j = 0; j < COLS; j++) begin
            // The result comes out of the very bottom row of PEs
            assign psum_out[j] = vertical_sums[ROWS][j];
        end
        
    endgenerate

endmodule