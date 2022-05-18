`timescale 1ns / 1ps

`include "ARMLEG.v"
`include "Clock.v"

module ARMLEGvtf;
	wire CLOCK;
	reg RESET;

	Clock clock(CLOCK);

	ARMLEG ARMLEGv8(CLOCK, RESET);

	always @ ( RESET ) begin
		#0.025;
		RESET = ~RESET;
	end

	initial
	begin

		RESET = 1;
		#2.5;
		
	end
endmodule