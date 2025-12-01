`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Author:      Partey Samuel Nadutey
// Project:     Systolic Array Accelerator for Edge AI
// Module:      mac_pe (Multiply-Accumulate Processing Element)
// Target:      Zynq-7000 (xc7z020)
// Description: The fundamental building block of the Weight-Stationary Systolic Array.
//              It supports INT8 quantization (8-bit signed integer math), aligning with
//              standard Edge-AI requirements.
//
//              Architecture: Weight-Stationary
//              - Mode 1 (Load): Weights are passed down vertically and latched locally.
//              - Mode 2 (Run):  Input pixels pass horizontally. They multiply with the
//                               stored weight, add to the partial sum from above, and
//                               pass the result down.
//////////////////////////////////////////////////////////////////////////////////

module mac_pe #(
    parameter WIDTH = 8  // Standard INT8 for quantized neural networks (MobileNet/EfficientNet)
)(
    input  logic clk,
    input  logic rst_n,       // Active-low reset (Standard in ASIC/FPGA industry)
    
    // Control Signal
    input  logic load_weight, // Control FSM signal: 1 = Load Weights, 0 = Compute Layer
    
    // Data Inputs
    // Note: 'signed' is required for Vivado to infer DSP48 slices correctly
    input  logic signed [WIDTH-1:0] ifmap_in,  // "Input Feature Map" (Pixel) entering from Left
    input  logic signed [WIDTH-1:0] weight_in, // Weight entering from Top (for loading)
    input  logic signed [31:0]      psum_in,   // Partial Sum entering from Top (32-bit accumulator to prevent overflow)
    
    // Data Outputs 
    // Registered outputs ensure clean timing paths between PEs (Timing Closure at 850MHz goal)
    output logic signed [WIDTH-1:0] ifmap_out, // Pass Pixel to Right Neighbor
    output logic signed [WIDTH-1:0] weight_out,// Pass Weight to Bottom Neighbor (Daisy-chain loading)
    output logic signed [31:0]      psum_out   // Pass MAC Result to Bottom Neighbor
);

    // Internal Memory: The "Stationary" Weight
    // This register minimizes off-chip memory traffic by reusing the weight for an entire row of pixels.
    logic signed [WIDTH-1:0] stored_weight;

    // Sequential Logic: Updates on the rising edge of the clock
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Synchronous Reset: Clear all pipelines
            ifmap_out     <= '0;
            weight_out    <= '0;
            psum_out      <= '0;
            stored_weight <= '0;
        end else begin
            // ---------------------------------------------------------
            // 1. Data Forwarding (Systolic Data Movement)
            // ---------------------------------------------------------
            // Regardless of compute mode, data must flow to neighbors to maintain array timing.
            ifmap_out  <= ifmap_in;  
            weight_out <= weight_in; 

            // ---------------------------------------------------------
            // 2. Arithmetic Operation Logic
            // ---------------------------------------------------------
            if (load_weight) begin
                // SETUP PHASE:
                // Latch the weight from the vertical bus into local storage.
                // Pass partial sum through unchanged (bubble).
                stored_weight <= weight_in;
                psum_out      <= psum_in;
            end else begin
                // COMPUTE PHASE (The AI Math):
                // Multiply-Accumulate (MAC): A * B + C
                // The synthesis tool (Vivado) will map this line to a hardware DSP48 slice
                // because we are using signed arithmetic on the registered 'stored_weight'.
                psum_out <= (ifmap_in * stored_weight) + psum_in;
            end
        end
    end

endmodule