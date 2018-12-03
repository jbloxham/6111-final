`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:25:14 11/29/2018 
// Design Name: 
// Module Name:    step_synth 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module step_synth(
    input clock,
    input reset,
    input ready,
    input beat,
    input [1:0] seed,
    output reg [3:0] arrow
    );

   always @(posedge clock) begin
      if (ready) begin
	 if (beat) arrow <= 4'b1 << seed;
	 else arrow <= 4'b0000;
      end
   end

endmodule
