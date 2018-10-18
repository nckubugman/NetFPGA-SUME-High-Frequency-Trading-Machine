module one_at_a_time2(clk, reset, in_data, out_data);
input             clk, reset;
input      [47:0] in_data;
output reg [31:0] out_data;

//  ---   wires
wire   [31:0] hash_0_0, hash_0_1, hash_0_2;
wire   [31:0] hash_1_0, hash_1_1, hash_1_2;
wire   [31:0] hash_2_0, hash_2_1, hash_2_2;
wire   [31:0] hash_3_0, hash_3_1, hash_3_2;
wire   [31:0] hash_4_0, hash_4_1, hash_4_2;
wire   [31:0] hash_5_0, hash_5_1, hash_5_2;
wire   [31:0] hash_6_0, hash_6_1, hash_6_2;

//  ---   regs
reg    [31:0] hash_reg_0_2;
reg    [31:0] hash_reg_1_2;
reg    [31:0] hash_reg_2_2;
reg    [31:0] hash_reg_3_2;
reg    [31:0] hash_reg_4_2;
reg    [31:0] hash_reg_5_2;

reg    [39:0] in_data_reg_0;
reg    [31:0] in_data_reg_1;
reg    [23:0] in_data_reg_2;
reg    [15:0] in_data_reg_3;
reg    [7:0]  in_data_reg_4;


/**-------------- Logic ----------------**/
// charater[0]
assign        hash_0_0  =   {24'd0, in_data[47:40]};
assign        hash_0_1  =   hash_0_0 + (hash_0_0 << 11);
assign        hash_0_2  =   hash_0_1 ^ (hash_0_1 >> 5);
// charater[1]

assign        hash_1_0  =   hash_reg_0_2 + in_data_reg_0[39:32];
assign        hash_1_1  =   hash_1_0     + (hash_1_0 << 11);
assign        hash_1_2  =   hash_1_1     ^ (hash_1_1 >> 5);
// charater[2]
assign        hash_2_0  =   hash_reg_1_2 + in_data_reg_1[31:24];
assign        hash_2_1  =   hash_2_0     + (hash_2_0 << 11);
assign        hash_2_2  =   hash_2_1     ^ (hash_2_1 >> 5);
// charater[3]
assign        hash_3_0  =   hash_reg_2_2 + in_data_reg_2[23:16];
assign        hash_3_1  =   hash_3_0     + (hash_3_0 << 11);
assign        hash_3_2  =   hash_3_1     ^ (hash_3_1 >> 5);
// charater[4]
assign        hash_4_0  =   hash_reg_3_2 + in_data_reg_3[15:8];
assign        hash_4_1  =   hash_4_0     + (hash_4_0 << 11);
assign        hash_4_2  =   hash_4_1     ^ (hash_4_1 >> 5);
// charater[5]
assign        hash_5_0  =   hash_reg_4_2 + in_data_reg_4[7:0];
assign        hash_5_1  =   hash_5_0     + (hash_5_0 << 11);
assign        hash_5_2  =   hash_5_1     ^ (hash_5_1 >> 5);
// last compute
assign        hash_6_0  =   hash_reg_5_2 + (hash_reg_5_2 << 4);
assign        hash_6_1  =   hash_6_0     ^ (hash_6_0 >> 10);
assign        hash_6_2  =   hash_6_1     + (hash_6_1 << 14);



/**----- pipeline registers -------**/
always @(posedge clk) begin
    if(reset) begin
	    hash_reg_0_2  <= 32'd0;
	    hash_reg_1_2  <= 32'd0;
	    hash_reg_2_2  <= 32'd0;
	    hash_reg_3_2  <= 32'd0;
	    hash_reg_4_2  <= 32'd0;
	    hash_reg_5_2  <= 32'd0;
		in_data_reg_0 <= 40'd0;
		in_data_reg_1 <= 32'd0;
		in_data_reg_2 <= 24'd0;
		in_data_reg_3 <= 16'd0;
		in_data_reg_4 <= 8'd0;
        out_data      <= 32'd0;
	end
	else begin	    
	    hash_reg_0_2   <=   hash_0_2;
	    hash_reg_1_2   <=   hash_1_2;
	    hash_reg_2_2   <=   hash_2_2;
	    hash_reg_3_2   <=   hash_3_2;
	    hash_reg_4_2   <=   hash_4_2;
	    hash_reg_5_2   <=   hash_5_2;
		in_data_reg_0  <=   in_data[39:0];
		in_data_reg_1  <=   in_data_reg_0[31:0];
		in_data_reg_2  <=   in_data_reg_1[23:0];
		in_data_reg_3  <=   in_data_reg_2[15:0];
		in_data_reg_4  <=   in_data_reg_3[7:0];
        out_data       <=   hash_6_2;
	end
end
endmodule
