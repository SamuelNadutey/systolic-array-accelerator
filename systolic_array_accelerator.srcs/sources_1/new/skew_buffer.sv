`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Author:      Partey Samuel Nadutey
// Project:     Systolic Array Accelerator for Edge AI
// Module:      skew_buffer (Data Alignment FIFO)
// Target:      Zynq-7000 (xc7z020)
// Description: A parameterizable shift register used to align input data into a 
//              diagonal "wavefront" pattern required for Systolic computation.
//
//              Functionality:
//              - Delays input data by 'DELAY' clock cycles.
//              - Used at the edge of the array to ensure Row N arrives exactly 
//                when the partial sums from Row N-1 reach the correct PE.
//              - Critical for achieving high throughput without pipeline stalls.
//////////////////////////////////////////////////////////////////////////////////

module skew_buffer #(
    parameter WIDTH = 8,
    parameter DELAY = 0  // Number of cycles to delay (Row 0 = 0, Row 1 = 1, etc.)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic signed [WIDTH-1:0] d_in,  // Flat data from Memory
    output logic signed [WIDTH-1:0] d_out  // Skewed/Delayed data to Array
);

    // If DELAY is 0 (First Row), just pass through as a wire.
    // If DELAY > 0, create a chain of registers (Shift Register).
    generate
        if (DELAY == 0) begin
            // Direct connection for the first row to minimize latency
            assign d_out = d_in;
        end else begin
            // Internal storage for the delay chain (Pipeline Registers)
            // Using registers here helps break timing paths, aiding timing closure at high frequencies.
            logic signed [WIDTH-1:0] shift_reg [DELAY-1:0];
            
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    // Flush the buffer
                    for (int i = 0; i < DELAY; i++) begin
                        shift_reg[i] <= '0;
                    end
                end else begin
                    // Shift Data:
                    // Head of the line gets new input
                    shift_reg[0] <= d_in;
                    
                    // Shift the rest down the chain
                    for (int i = 1; i < DELAY; i++) begin
                        shift_reg[i] <= shift_reg[i-1];
                    end
                end
            end
            
            // Output is the last element in the chain
            assign d_out = shift_reg[DELAY-1];
        end
    endgenerate

endmodule