module binary_to_bcd_seq
    (
        input [23:0] binary,
	output reg [3:0] hundred_thousand,
	output reg [3:0] ten_thousand,
        output reg [3:0] thousand,
        output reg [3:0] hundred,
        output reg [3:0] ten,
        output reg [3:0] one
    );


        integer i;

always @(binary) begin
	hundred_thousand=4'd0;
	ten_thousand=4'd0;
        thousand = 4'd0;
        hundred = 4'd0;
        ten = 4'd0;
        one = 4'd0;

        for(i = 23; i >= 0; i = i - 1) begin
                if(hundred_thousand >= 5) begin
                        hundred_thousand = hundred_thousand + 3;
                end
                if(ten_thousand >= 5) begin
                        ten_thousand = ten_thousand + 3;
                end
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
                hundred_thousand = hundred_thousand << 1;
                hundred_thousand[0] = ten_thousand[3];

                ten_thousand = ten_thousand << 1;
                ten_thousand[0] = thousand[3];

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

