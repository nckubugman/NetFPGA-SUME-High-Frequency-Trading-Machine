///////////////////////////////////////////////////////////////////////////////
// $Id: connect_check.v 5240 2009-03-14 01:50:42Z grg $
//
// Module: binary_to_bcd.v
// Project: NF2.1
// Description: binaey_to_bcd
//              
//
///////////////////////////////////////////////////////////////////////////////


  module binary_to_bcd
    ( 
	input [11:0] binary,
	output reg [3:0] thousand,
	output reg [3:0] hundred,
	output reg [3:0] ten,
	output reg [3:0] one
    );


	integer i;

always @(binary) begin
	thousand = 4'd0;
	hundred = 4'd0;
	ten = 4'd0;
	one = 4'd0;

	for(i = 11; i >= 0; i = i - 1) begin
		if(thousand >= 5) begin
			thousand = thousand + 3;
		end
		if(hundred >= 5) begin
			hundred = hundred + 3;
		end
		if(ten >= 5) begin
			ten = ten + 3;
		end
		if(one >= 5) begin
			one = one + 3;
		end

		thousand = thousand << 1;
		thousand[0] = hundred[3];

		hundred = hundred << 1;
		hundred[0] = ten[3];

		ten = ten << 1;
		ten[0] = one[3];

		one = one << 1;
		one[0] = binary[i];
	end
end
endmodule
