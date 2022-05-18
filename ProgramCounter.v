`timescale 1ns / 1ps

module ProgramCounter
(
	input CLOCK,
	input RESET,
	input PCWire,
	input [63:0] programCounter_in,
	output reg [63:0] programCounter_out
);
	always @(posedge CLOCK or posedge RESET) begin
		if (RESET) begin
			programCounter_out  <= 0;
		end else if (CLOCK ==1) begin
			if (programCounter_in === 64'bx) 
				programCounter_out  <= 0;
			else  
				programCounter_out <= programCounter_in;
			end
	end 
endmodule
