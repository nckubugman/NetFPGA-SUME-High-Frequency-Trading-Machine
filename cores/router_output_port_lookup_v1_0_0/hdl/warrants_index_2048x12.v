module warrants_index_2048x12(

   input      [10:0]     addr_a,
   input      [11:0]    din_a,
   output reg [11:0]    dout_a,

   input                clk_a,
   input                we_a

 /*  input      [8:0]     addr_b,
   input      [48:0]    din_b,
   output reg [48:0]    dout_b,

   input                clk_b,
   input                we_b
*/
);


   (* ram_style = "block" *) reg [11:0] ram [0:2047];
//   (* ram_style = "auto" *) reg [11:0] ram [0:2047];


   //-----------------------
   //    Port A
   //-----------------------
   always@(posedge clk_a) begin
      if (we_a) begin
         ram[addr_a]  <=  din_a;
         dout_a       <=  din_a;
      end
      else
         dout_a       <=  ram[addr_a];
   end
/*
   //-----------------------
   //    Port B
   //-----------------------
   always@(posedge clk_b) begin
      if (we_b) begin
         ram[addr_b]  <=  din_b;
         dout_b       <=  din_b;
      end
      else
         dout_b       <=  ram[addr_b];
   end
*/
endmodule

