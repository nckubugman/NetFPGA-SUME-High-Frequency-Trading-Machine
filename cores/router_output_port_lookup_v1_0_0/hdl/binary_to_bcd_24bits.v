///////////////////////////////////////////////////////////////////////////////
// $Id: connect_check.v 5240 2009-03-14 01:50:42Z grg $
//
// Module: binary_to_bcd.v
// Project: NF2.1
// Description: binaey_to_bcd_24bits(for fix sequence num)
//              
//
///////////////////////////////////////////////////////////////////////////////


  module binary_to_bcd_24bits
    ( 
	input [23:0] binary,
	output reg [3:0] reg_0,
	output reg [3:0] reg_1,
	output reg [3:0] reg_2,
	output reg [3:0] reg_3,
	output reg [3:0] reg_4,
	output reg [3:0] reg_5,
	output reg [3:0] reg_6,
	output reg [3:0] reg_7
    );


	integer i;

always @(binary) begin
	reg_0 = 4'd0;
	reg_1 = 4'd0;
	reg_2 = 4'd0;
	reg_3 = 4'd0;
	reg_4 = 4'd0;
	reg_5 = 4'd0;
	reg_6 = 4'd0;
	reg_7 = 4'd0;

	for(i = 23; i >= 0; i = i - 1) begin
		if(reg_7 >= 5) begin
			reg_7 = reg_7 + 3;
		end
		if(reg_6 >= 5) begin
			reg_6 = reg_6 + 3;
		end
		if(reg_5 >= 5) begin
			reg_5 = reg_5 + 3;
		end
		if(reg_4 >= 5) begin
			reg_4 = reg_4 + 3;
		end
		if(reg_3 >= 5) begin
			reg_3 = reg_3 + 3;
		end
		if(reg_2 >= 5) begin
			reg_2 = reg_2 + 3;
		end
		if(reg_1 >= 5) begin
			reg_1 = reg_1 + 3;
		end
		if(reg_0 >= 5) begin
			reg_0 = reg_0 + 3;
		end
		
		reg_7 = reg_7 << 1;
		reg_7[0] = reg_6[3];

		reg_6 = reg_6 << 1;
		reg_6[0] = reg_5[3];
	
		reg_5 = reg_5 << 1;
		reg_5[0] = reg_4[3];
	
		reg_4 = reg_4 << 1;
		reg_4[0] = reg_3[3];
	
		reg_3 = reg_3 << 1;
		reg_3[0] = reg_2[3];
	
		reg_2 = reg_2 << 1;
		reg_2[0] = reg_1[3];
	
		reg_1 = reg_1 << 1;
		reg_1[0] = reg_0[3];
	
		reg_0 = reg_0 << 1;
		reg_0[0] = binary[i];
	end
end
endmodule
