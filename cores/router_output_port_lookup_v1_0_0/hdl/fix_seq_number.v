module fix_seq_number
   #(//Master AXI Stream Data Width
    parameter C_S_AXIS_DATA_WIDTH = 256,
    parameter C_S_AXIS_TUSER_WIDTH  = 128 )
  (// --- interface to input fifo - fallthrough

    // Global Ports
    input clk,
    input reset,


    // Master Stream Ports (interface to data path)

    // Slave Stream Ports (interface to RX queues)
    input [C_S_AXIS_DATA_WIDTH - 1:0]              tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0]      tkeep,
    input                                          tvalid,
    input                                          tlast,
    input[C_S_AXIS_TUSER_WIDTH-1:0]        	   tuser,
   
   // --- interface to process
   output                             fix_seq_num_vld,
   output     [23:0]                  fix_new_seq_num,     // new checksum assuming decremented TTL
   input                              rd_fix_seq_num
    

   
  );

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2
   
   //---------------------- Wires and regs -------------------------
 
   reg [C_S_AXIS_DATA_WIDTH-1:0]     out_tdata_next;
   reg [(C_S_AXIS_DATA_WIDTH/8)-1:0] out_tkeep_next;
   reg                               out_tvalid_next;
   reg [C_S_AXIS_TUSER_WIDTH-1:0]   out_tuser_next;
   reg             out_tlast_next;
   
   reg    seq_num_done;
   wire   empty;

   
   wire [3:0] hundred_thousand,ten_thousand,thousand, hundred, ten, one;



   wire [23:0]            seq_num;
   wire  [3:0]              seq_num_0;
   wire  [3:0]              seq_num_1;
   wire  [3:0]              seq_num_2;
   wire  [3:0]              seq_num_3;
   wire  [3:0]              seq_num_4;
   wire  [3:0]              seq_num_5;
   wire  [3:0]              seq_num_6;
   wire  [3:0]              seq_num_7;
   // --- wade resend seq num temp

   reg  [3:0]              resend_seq_0;
   reg  [3:0]              resend_seq_1;
   reg  [3:0]              resend_seq_2;
   reg  [3:0]              resend_seq_3;
   reg  [3:0]              resend_seq_4;
   reg  [3:0]              resend_seq_5;
   reg  [3:0]              resend_seq_6;
   reg  [3:0]              resend_seq_7;

   reg  [3:0]              resend_seq_reg_0;
   reg  [3:0]              resend_seq_reg_1;
   reg  [3:0]              resend_seq_reg_2;
   reg  [3:0]              resend_seq_reg_3;
   reg  [3:0]              resend_seq_reg_4;
   reg  [3:0]              resend_seq_reg_5;
   reg  [3:0]              resend_seq_reg_6;
   reg  [3:0]              resend_seq_reg_7;

   reg  [15:0]             resend_counter;
   reg  [15:0]             resend_buffer;
   reg  [15:0]             resend_counter_reg;

   //---------- FIX Fields ------------
   reg  [3:0]              msg_seq_num_0;
   reg  [3:0]              msg_seq_num_1;
   reg  [3:0]              msg_seq_num_2;
   reg  [3:0]              msg_seq_num_3;
   reg  [3:0]              msg_seq_num_4;
   reg  [3:0]              msg_seq_num_5;
   reg  [3:0]              msg_seq_num_6;
   reg  [3:0]              msg_seq_num_7;
   reg  [3:0]              msg_seq_num_reg_0;
   reg  [3:0]              msg_seq_num_reg_1;
   reg  [3:0]              msg_seq_num_reg_2;
   reg  [3:0]              msg_seq_num_reg_3;
   reg  [3:0]              msg_seq_num_reg_4;
   reg  [3:0]              msg_seq_num_reg_5;
   reg  [3:0]              msg_seq_num_reg_6;
   reg  [3:0]              msg_seq_num_reg_7;
   reg                     flag;
   reg                     flag_next;
   reg			   wr_in_fifo;

   reg  [3:0]              new_msg_seq_num_0;
   reg  [3:0]              new_msg_seq_num_1;
   reg  [3:0]              new_msg_seq_num_2;
   reg  [3:0]              new_msg_seq_num_3;
   reg  [3:0]              new_msg_seq_num_4;
   reg  [3:0]              new_msg_seq_num_5;
   reg  [3:0]              new_msg_seq_num_6;
   reg  [3:0]              new_msg_seq_num_7;
   



   fallthrough_small_fifo #(.WIDTH(24), .MAX_DEPTH_BITS(2))
      fix_checksum_fifo
        (.din ({msg_seq_num_reg_5, msg_seq_num_reg_4, msg_seq_num_reg_3, msg_seq_num_reg_2, msg_seq_num_reg_1, msg_seq_num_reg_0}),
         .wr_en (wr_in_fifo),             // Write enable
         .rd_en (rd_fix_seq_num),               // Read the next word
         .dout (fix_new_seq_num),
         .full (),
         .nearly_full (),
         .prog_full (),
         .empty (empty),
         .reset (reset),
         .clk (clk)
         );

/*
   fallthrough_small_fifo #(.WIDTH(24), .MAX_DEPTH_BITS(2))
      fix_checksum_fifo
        (.din ({msg_seq_num_reg_5,msg_seq_num_reg_4,msg_seq_num_reg_3,msg_seq_num_reg_2,msg_seq_num_reg_1,msg_seq_num_reg_0}),

         .wr_en (seq_num_done),             // Write enable
         .rd_en (rd_fix_seq_num),               // Read the next word
         .dout (fix_new_seq_num),
         .full (),
         .nearly_full (),
         .prog_full (),
         .empty (empty),
         .reset (reset),
         .clk (clk)
         );


*/

/*
assign hundred_thousand = new_msg_seq_num_5;
assign ten_thousand     = new_msg_seq_num_4;
assign thousand		= new_msg_seq_num_3;
assign hundred 		= new_msg_seq_num_2;
assign ten		= new_msg_seq_num_1;
assign one		= new_msg_seq_num_0;
*/
assign fix_seq_num_vld = !empty;


   //-------------------------- Logic ------------------------------

/*
   always @(*) begin
        resend_seq_0 = resend_seq_reg_0;
        resend_seq_1 = resend_seq_reg_1;
        resend_seq_2 = resend_seq_reg_2;
        resend_seq_3 = resend_seq_reg_3;
        resend_seq_4 = resend_seq_reg_4;
        resend_seq_5 = resend_seq_reg_5;
        resend_seq_6 = resend_seq_reg_6;
        resend_seq_7 = resend_seq_reg_7;

        if(resend_seq_0 == 4'hf) begin
                resend_seq_0 = 4'd9;
                resend_seq_1 = resend_seq_reg_1 - 4'd1;
        end
        if(resend_seq_0 == 4'he) begin
                resend_seq_0 = 4'd8;
                resend_seq_1 = resend_seq_reg_1 - 4'd1;
        end
        if(resend_seq_1 == 4'hf) begin
                resend_seq_1 = 4'd9;
                resend_seq_2 = resend_seq_reg_2 - 4'd1;
        end
        if(resend_seq_2 == 4'hf) begin
                resend_seq_2 = 4'd9;
                resend_seq_3 = resend_seq_reg_3 - 4'd1;
        end
        if(resend_seq_3 == 4'hf) begin
                resend_seq_3 = 4'd9;
                resend_seq_4 = resend_seq_reg_4 - 4'd1;
        end
        if(resend_seq_4 == 4'hf) begin
                resend_seq_4 = 4'd9;
                resend_seq_5 = resend_seq_reg_5 - 4'd1;
        end
        if(resend_seq_5 == 4'hf) begin
                resend_seq_5 = 4'd9;
                resend_seq_6 = resend_seq_reg_6 - 4'd1;
        end
        if(resend_seq_6 == 4'hf) begin
                resend_seq_6 = 4'd9;
                resend_seq_7 = resend_seq_reg_7 - 4'd1;
        end
        if(resend_seq_7 == 4'hf) begin
                resend_seq_7 = 4'd9;
        end
   end
*/


   // Message Sequence Counter : Logic Part
   always @(*) begin
         msg_seq_num_0 = msg_seq_num_reg_0;
         msg_seq_num_1 = msg_seq_num_reg_1;
         msg_seq_num_2 = msg_seq_num_reg_2;
         msg_seq_num_3 = msg_seq_num_reg_3;
         msg_seq_num_4 = msg_seq_num_reg_4;
         msg_seq_num_5 = msg_seq_num_reg_5;
         msg_seq_num_6 = msg_seq_num_reg_6;
         msg_seq_num_7 = msg_seq_num_reg_7;
         if(tvalid&&tlast&&(tuser[63:48]==16'h1f||tuser[63:48]==16'h7f)) begin
	//test
/*
           resend_counter = resend_counter_reg + 1'b1;
           if((resend_seq_0 == msg_seq_num_reg_0) && (resend_seq_1 == msg_seq_num_reg_1) && (resend_seq_2 == msg_seq_num_reg_2) && (resend_seq_3 == msg_seq_num_reg_3)) begin
                msg_seq_num_0 = msg_seq_num_reg_0 + 4'd2;
           end
           else begin
*/

           msg_seq_num_0 = msg_seq_num_reg_0 + 4'd1;
	end

//           end


           if(msg_seq_num_0 == 4'd10 || msg_seq_num_0 == 4'd11) begin
               msg_seq_num_0 = 4'd0;
               msg_seq_num_1 = msg_seq_num_reg_1 + 4'd1;
           end
           if(msg_seq_num_1 == 4'd10) begin
               msg_seq_num_1 = 4'd0;
               msg_seq_num_2 = msg_seq_num_reg_2 + 4'd1;
           end
           if(msg_seq_num_2 == 4'd10) begin
               msg_seq_num_2 = 4'd0;
               msg_seq_num_3 = msg_seq_num_reg_3 + 4'd1;
           end
           if(msg_seq_num_3 == 4'd10) begin
               msg_seq_num_3 = 4'd0;
               msg_seq_num_4 = msg_seq_num_reg_4 + 4'd1;
           end
           if(msg_seq_num_4 == 4'd10) begin
               msg_seq_num_4 = 4'd0;
               msg_seq_num_5 = msg_seq_num_reg_5 + 4'd1;
           end
           if(msg_seq_num_5 == 4'd10) begin
               msg_seq_num_5 = 4'd0;
               msg_seq_num_6 = msg_seq_num_reg_6 + 4'd1;
           end
           if(msg_seq_num_6 == 4'd10) begin
               msg_seq_num_6 = 4'd0;
               msg_seq_num_7 = msg_seq_num_reg_7 + 4'd1;
           end
           if(msg_seq_num_7 == 4'd10) begin
               msg_seq_num_7 = 4'd0;
           end
/*
	   if(wr_in_fifo)begin
	       new_msg_seq_num_0 = msg_seq_num_reg_0;
	       new_msg_seq_num_1 = msg_seq_num_reg_1;
	       new_msg_seq_num_2 = msg_seq_num_reg_2;
	       new_msg_seq_num_3 = msg_seq_num_reg_3;
	       new_msg_seq_num_4 = msg_seq_num_reg_4;
	       new_msg_seq_num_5 = msg_seq_num_reg_5;
	       new_msg_seq_num_6 = msg_seq_num_reg_6;
	       new_msg_seq_num_7 = msg_seq_num_reg_7;	
	   end
  */     
   end
    
   // Message Sequence Counter : Sequence Part

   always @(posedge clk) begin
       if(reset) begin
           msg_seq_num_reg_0 <= 4'd2;
           msg_seq_num_reg_1 <= 4'd0;
           msg_seq_num_reg_2 <= 4'd0;
           msg_seq_num_reg_3 <= 4'd0;
           msg_seq_num_reg_4 <= 4'd0;
           msg_seq_num_reg_5 <= 4'd0;
           msg_seq_num_reg_6 <= 4'd0;
           msg_seq_num_reg_7 <= 4'd0;
	   seq_num_done      <= 0;
	   wr_in_fifo        <= 0;
/*
           netfpga_seq_wr_ack <= 'b0;
           resend_ack        <= 'b0;
           resend_counter_reg    <=  'h2;
           resend_buffer     <= 'b0;
*/
       end
       else begin
/*
                        if(resend_req) begin
                                resend_ack <= 'b1;
                                netfpga_seq_wr_ack <= 'b0;
                                msg_seq_num_reg_0 <= resend_num[3:0];
                                msg_seq_num_reg_1 <= resend_num[7:4];
                                msg_seq_num_reg_2 <= resend_num[11:8];
                                msg_seq_num_reg_3 <= resend_num[15:12];
                                msg_seq_num_reg_4 <= resend_num[19:16];
                                msg_seq_num_reg_5 <= resend_num[23:20];
                                msg_seq_num_reg_6 <= resend_num[27:24];
                                msg_seq_num_reg_7 <= resend_num[31:28];
                                resend_seq_reg_0  <= msg_seq_num_reg_0 - 4'd2;
                                resend_seq_reg_1  <= msg_seq_num_reg_1;
                                resend_seq_reg_2  <= msg_seq_num_reg_2;
                                resend_seq_reg_3  <= msg_seq_num_reg_3;
                                resend_seq_reg_4  <= msg_seq_num_reg_4;
                                resend_seq_reg_5  <= msg_seq_num_reg_5;
                                resend_seq_reg_6  <= msg_seq_num_reg_6;
                                resend_seq_reg_7  <= msg_seq_num_reg_7;
                                resend_buffer <= resend_counter - 16'd1;
                        end
*/
                        /*if(netfpga_seq_wr_req) begin
                                netfpga_seq_wr_ack <= 'b1;
                                //resend_ack        <= 'b0;
                                msg_seq_num_reg_0 <= seq_num_0;
                                msg_seq_num_reg_1 <= seq_num_1;
                                msg_seq_num_reg_2 <= seq_num_2;
                                msg_seq_num_reg_3 <= seq_num_3;
                                msg_seq_num_reg_4 <= seq_num_4;
                                msg_seq_num_reg_5 <= seq_num_5;
                                msg_seq_num_reg_6 <= seq_num_6;
                                msg_seq_num_reg_7 <= seq_num_7;
                                //msg_seq_num_reg_0 <= 'h5;
                        end*/
//                        else begin
/*
		        if( tvalid || wr_in_fifo)begin
                       		msg_seq_num_reg_0 <= msg_seq_num_reg_0 + 1'd1;
				if(msg_seq_num_reg_0 == 4'd10 || msg_seq_num_reg_0 == 4'd11) begin
               				msg_seq_num_reg_0 <= 4'd0;
               				msg_seq_num_reg_1 <= msg_seq_num_reg_1 + 4'd1;
           			end
           			if(msg_seq_num_reg_1 == 4'd10) begin
              	 			msg_seq_num_reg_1 <= 4'd0;
               				msg_seq_num_reg_2 <= msg_seq_num_reg_2 + 4'd1;
           			end
           			if(msg_seq_num_reg_2 == 4'd10) begin
               				msg_seq_num_reg_2 <= 4'd0;
               				msg_seq_num_reg_3 <= msg_seq_num_reg_3 + 4'd1;
           			end
           			if(msg_seq_num_reg_3 == 4'd10) begin
               				msg_seq_num_reg_3 <= 4'd0;
               				msg_seq_num_reg_4 <= msg_seq_num_reg_4 + 4'd1;
           			end
           			if(msg_seq_num_reg_4 == 4'd10) begin
               				msg_seq_num_reg_4 <= 4'd0;
               				msg_seq_num_reg_5 <= msg_seq_num_reg_5 + 4'd1;
           			end
           			if(msg_seq_num_reg_5 == 4'd10) begin
               				msg_seq_num_reg_5 <= 4'd0;
               				msg_seq_num_reg_6 <= msg_seq_num_reg_6 + 4'd1;
           			end
           			if(msg_seq_num_reg_6 == 4'd10) begin
               				msg_seq_num_reg_6 <= 4'd0;
               				msg_seq_num_reg_7 <= msg_seq_num_reg_7 + 4'd1;
           			end
           			if(msg_seq_num_reg_7 == 4'd10) begin
               				msg_seq_num_reg_7 <= 4'd0;
           			end
				wr_in_fifo <= 1 ;
			end
*/
//			if(tvalid || wr_in_fifo)begin

				msg_seq_num_reg_0 <= msg_seq_num_0;
                                msg_seq_num_reg_1 <= msg_seq_num_1;
                                msg_seq_num_reg_2 <= msg_seq_num_2;
                                msg_seq_num_reg_3 <= msg_seq_num_3;
                                msg_seq_num_reg_4 <= msg_seq_num_4;
                                msg_seq_num_reg_5 <= msg_seq_num_5;

/*
                                msg_seq_num_reg_6 <= new_msg_seq_num_6;
                                msg_seq_num_reg_7 <= new_msg_seq_num_7;
*/
/*
				msg_seq_num_reg_0 <= one;
                                msg_seq_num_reg_1 <= ten;
                                msg_seq_num_reg_2 <= hundred;
                                msg_seq_num_reg_3 <= thousand;
                                msg_seq_num_reg_4 <= ten_thousand;
                                msg_seq_num_reg_5 <= hundred_thousand;
*/

//			end

			if(tlast&& tvalid)begin
				wr_in_fifo <= 1;
			end
			else begin
				wr_in_fifo <= 0;
			end

//
//                                resend_counter_reg <= resend_counter;

			//if(tlast&&tvalid)begin
/*			if(wr_in_fifo)begin
				seq_num_done <= 1;
			end
			else begin
				seq_num_done <= 0;
			end
  */                      //end

      end

   end



endmodule
 
