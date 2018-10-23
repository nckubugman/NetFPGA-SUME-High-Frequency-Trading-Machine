module fix_seq_number_counter_sm
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
    input[C_S_AXIS_TUSER_WIDTH-1:0]                tuser,

   // --- interface to process
   output                             fix_seq_num_vld,
   output     [23:0]                  fix_new_seq_num,     // new checksum assuming decremented TTL
   input                              rd_fix_seq_num,

   input [31:0]                       fix_resend_num_begin,
   input [31:0]                       fix_resend_num_end,
   output reg                         resend_ack,
//   input                            resend_req,
   input                              resend_mode_one,
   input                              resend_mode_two,
   input                              resend_mode_three,
   input [31:0]                        cpu2ip_overwrite_fix_seq_num_reg,
   input                              seq_num_out_word_OPT_PAYLOAD,
   input                              seq_num_out_word_IP_DST_LO,
   input                              seq_num_out_word_IP_DST_HI

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
   reg    resend_ack_next;
   reg    wr_delay ;


//----------------For Resend Mode Two ------------------
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

   reg  [3:0]              seq_num_keep_reg_0;
   reg  [3:0]              seq_num_keep_reg_1;
   reg  [3:0]              seq_num_keep_reg_2;
   reg  [3:0]              seq_num_keep_reg_3;
   reg  [3:0]              seq_num_keep_reg_4;
   reg  [3:0]              seq_num_keep_reg_5;
   reg  [3:0]              seq_num_keep_reg_6;
   reg  [3:0]              seq_num_keep_reg_7;

   reg  [3:0]              seq_num_keep_0;
   reg  [3:0]              seq_num_keep_1;
   reg  [3:0]              seq_num_keep_2;
   reg  [3:0]              seq_num_keep_3;
   reg  [3:0]              seq_num_keep_4;
   reg  [3:0]              seq_num_keep_5;
   reg  [3:0]              seq_num_keep_6;
   reg  [3:0]              seq_num_keep_7;

   reg  [3:0]                        resend_end_reg_0;
   reg  [3:0]                        resend_end_reg_1;
   reg  [3:0]                        resend_end_reg_2;
   reg  [3:0]                        resend_end_reg_3;
   reg  [3:0]                        resend_end_reg_4;
   reg  [3:0]                        resend_end_reg_5;
   reg  [3:0]                        resend_end_reg_6;
   reg  [3:0]                        resend_end_reg_7;

   reg  [3:0]                        resend_end_0;
   reg  [3:0]                        resend_end_1;
   reg  [3:0]                        resend_end_2;
   reg  [3:0]                        resend_end_3;
   reg  [3:0]                        resend_end_4;
   reg  [3:0]                        resend_end_5;
   reg  [3:0]                        resend_end_6;
   reg  [3:0]                        resend_end_7;




//---------------------------------------------


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
   reg                     wr_in_fifo;


   reg                     resend_flag;

   reg                     seq_hold;

   reg[NUM_STATES-1:0]     state;
   reg[NUM_STATES-1:0]     state_next;

   fallthrough_small_fifo #(.WIDTH(24), .MAX_DEPTH_BITS(6))
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

   localparam NUM_STATES          = 16;
   localparam WAIT                = 1;
   localparam FIX_PKT_SEQ_NUM     = 2;
   localparam RESEND_MODE_THREE   = 4;
   localparam RESEND_MODE_TWO     = 8;
   localparam RESEND_MODE_ONE     = 16;
   localparam CHECK_CARRY         = 32;
   localparam PASS_PKT            = 64;
   localparam SET_SEQ_NUM         = 128;

assign fix_seq_num_vld = !empty;

always@(tlast,tuser[35:32])begin
	case({tlast,tuser[35:32]})
		5'b10010:begin
		   if(resend_mode_one||resend_mode_two||resend_mode_three)begin
                        msg_seq_num_0 = msg_seq_num_reg_0;
                        msg_seq_num_1 = msg_seq_num_reg_1;
                        msg_seq_num_2 = msg_seq_num_reg_2;
                        msg_seq_num_3 = msg_seq_num_reg_3;
                        msg_seq_num_4 = msg_seq_num_reg_4;
                        msg_seq_num_5 = msg_seq_num_reg_5;
                        msg_seq_num_6 = msg_seq_num_reg_6;
                        msg_seq_num_7 = msg_seq_num_reg_7;
		   end
		   else begin
		      msg_seq_num_0 = msg_seq_num_reg_0 + 4'd1;
   		      msg_seq_num_1 = msg_seq_num_reg_1;
		      msg_seq_num_2 = msg_seq_num_reg_2;
		      msg_seq_num_3 = msg_seq_num_reg_3;
		      msg_seq_num_4 = msg_seq_num_reg_4;
		      msg_seq_num_5 = msg_seq_num_reg_5;
		      msg_seq_num_6 = msg_seq_num_reg_6;
		      msg_seq_num_7 = msg_seq_num_reg_7; 
		  end
		end
		5'b00010:begin
			msg_seq_num_0 = msg_seq_num_reg_0;
			msg_seq_num_1 = msg_seq_num_reg_1;
                        msg_seq_num_2 = msg_seq_num_reg_2;
                        msg_seq_num_3 = msg_seq_num_reg_3;
                        msg_seq_num_4 = msg_seq_num_reg_4;
                        msg_seq_num_5 = msg_seq_num_reg_5;
                        msg_seq_num_6 = msg_seq_num_reg_6;
                        msg_seq_num_7 = msg_seq_num_reg_7;
		end
		5'b10001:begin
			msg_seq_num_0 = msg_seq_num_reg_0;
                        msg_seq_num_1 = msg_seq_num_reg_1;
                        msg_seq_num_2 = msg_seq_num_reg_2;
                        msg_seq_num_3 = msg_seq_num_reg_3;
                        msg_seq_num_4 = msg_seq_num_reg_4;
                        msg_seq_num_5 = msg_seq_num_reg_5;
                        msg_seq_num_6 = msg_seq_num_reg_6;
                        msg_seq_num_7 = msg_seq_num_reg_7;
		end
		5'b00001:begin
			msg_seq_num_0 = msg_seq_num_reg_0;
                        msg_seq_num_1 = msg_seq_num_reg_1;
                        msg_seq_num_2 = msg_seq_num_reg_2;
                        msg_seq_num_3 = msg_seq_num_reg_3;
                        msg_seq_num_4 = msg_seq_num_reg_4;
                        msg_seq_num_5 = msg_seq_num_reg_5;
                        msg_seq_num_6 = msg_seq_num_reg_6;
                        msg_seq_num_7 = msg_seq_num_reg_7;			
		end
		5'b00000:begin
                        msg_seq_num_0 = msg_seq_num_reg_0;
                        msg_seq_num_1 = msg_seq_num_reg_1;
                        msg_seq_num_2 = msg_seq_num_reg_2;
                        msg_seq_num_3 = msg_seq_num_reg_3;
                        msg_seq_num_4 = msg_seq_num_reg_4;
                        msg_seq_num_5 = msg_seq_num_reg_5;
                        msg_seq_num_6 = msg_seq_num_reg_6;
                        msg_seq_num_7 = msg_seq_num_reg_7;
		end
	endcase
end

/*
always@(tlast,tuser[35:32],resend_mode_one,resend_mode_two,resend_mode_three)begin
        case({tlast,tuser[35:32],resend_mode_one,resend_mode_two,resend_mode_three})
                5'b10010001 :begin
                      msg_seq_num_0 = msg_seq_num_reg_0;
                      msg_seq_num_1 = msg_seq_num_reg_1;
                      msg_seq_num_2 = msg_seq_num_reg_2;
                      msg_seq_num_3 = msg_seq_num_reg_3;
                      msg_seq_num_4 = msg_seq_num_reg_4;
                      msg_seq_num_5 = msg_seq_num_reg_5;
                      msg_seq_num_6 = msg_seq_num_reg_6;
                      msg_seq_num_7 = msg_seq_num_reg_7;
                end
                5'b10010010 :begin
                      msg_seq_num_0 = msg_seq_num_reg_0;
                      msg_seq_num_1 = msg_seq_num_reg_1;
                      msg_seq_num_2 = msg_seq_num_reg_2;
                      msg_seq_num_3 = msg_seq_num_reg_3;
                      msg_seq_num_4 = msg_seq_num_reg_4;
                      msg_seq_num_5 = msg_seq_num_reg_5;
                      msg_seq_num_6 = msg_seq_num_reg_6;
                      msg_seq_num_7 = msg_seq_num_reg_7;
                end
                5'b10010100 :begin
                      msg_seq_num_0 = msg_seq_num_reg_0;
                      msg_seq_num_1 = msg_seq_num_reg_1;
                      msg_seq_num_2 = msg_seq_num_reg_2;
                      msg_seq_num_3 = msg_seq_num_reg_3;
                      msg_seq_num_4 = msg_seq_num_reg_4;
                      msg_seq_num_5 = msg_seq_num_reg_5;
                      msg_seq_num_6 = msg_seq_num_reg_6;
                      msg_seq_num_7 = msg_seq_num_reg_7;
                end
                5'b10010000 :begin
                      msg_seq_num_0 = msg_seq_num_reg_0 + 4'd1;
                      msg_seq_num_1 = msg_seq_num_reg_1;
                      msg_seq_num_2 = msg_seq_num_reg_2;
                      msg_seq_num_3 = msg_seq_num_reg_3;
                      msg_seq_num_4 = msg_seq_num_reg_4;
                      msg_seq_num_5 = msg_seq_num_reg_5;
                      msg_seq_num_6 = msg_seq_num_reg_6;
                      msg_seq_num_7 = msg_seq_num_reg_7;
                end


                5'b00010000:begin
                        msg_seq_num_0 = msg_seq_num_reg_0;
                        msg_seq_num_1 = msg_seq_num_reg_1;
                        msg_seq_num_2 = msg_seq_num_reg_2;
                        msg_seq_num_3 = msg_seq_num_reg_3;
                        msg_seq_num_4 = msg_seq_num_reg_4;
                        msg_seq_num_5 = msg_seq_num_reg_5;
                        msg_seq_num_6 = msg_seq_num_reg_6;
                        msg_seq_num_7 = msg_seq_num_reg_7;
                end

                5'b10001000:begin
                        msg_seq_num_0 = msg_seq_num_reg_0;
                        msg_seq_num_1 = msg_seq_num_reg_1;
                        msg_seq_num_2 = msg_seq_num_reg_2;
                        msg_seq_num_3 = msg_seq_num_reg_3;
                        msg_seq_num_4 = msg_seq_num_reg_4;
                        msg_seq_num_5 = msg_seq_num_reg_5;
                        msg_seq_num_6 = msg_seq_num_reg_6;
                        msg_seq_num_7 = msg_seq_num_reg_7;
                end
                5'b00001000:begin
                        msg_seq_num_0 = msg_seq_num_reg_0;
                        msg_seq_num_1 = msg_seq_num_reg_1;
                        msg_seq_num_2 = msg_seq_num_reg_2;
                        msg_seq_num_3 = msg_seq_num_reg_3;
                        msg_seq_num_4 = msg_seq_num_reg_4;
                        msg_seq_num_5 = msg_seq_num_reg_5;
                        msg_seq_num_6 = msg_seq_num_reg_6;
                        msg_seq_num_7 = msg_seq_num_reg_7;
                end
                5'b00000000:begin
                        msg_seq_num_0 = msg_seq_num_reg_0;
                        msg_seq_num_1 = msg_seq_num_reg_1;
                        msg_seq_num_2 = msg_seq_num_reg_2;
                        msg_seq_num_3 = msg_seq_num_reg_3;
                        msg_seq_num_4 = msg_seq_num_reg_4;
                        msg_seq_num_5 = msg_seq_num_reg_5;
                        msg_seq_num_6 = msg_seq_num_reg_6;
                        msg_seq_num_7 = msg_seq_num_reg_7;
                end
        endcase
end
*/

always@(resend_mode_one,resend_mode_two,resend_mode_three)begin
	case({resend_mode_one,resend_mode_two,resend_mode_three})
		3'b100:begin
	              seq_num_keep_0 = msg_seq_num_reg_0;
	              seq_num_keep_1 = msg_seq_num_reg_1;
	              seq_num_keep_2 = msg_seq_num_reg_2;
	              seq_num_keep_3 = msg_seq_num_reg_3;
	      	      seq_num_keep_4 = msg_seq_num_reg_4;
	              seq_num_keep_5 = msg_seq_num_reg_5;
	              seq_num_keep_6 = msg_seq_num_reg_6;
	              seq_num_keep_7 = msg_seq_num_reg_7;

		end
		3'b010:begin
	              seq_num_keep_0 = msg_seq_num_reg_0;
	              seq_num_keep_1 = msg_seq_num_reg_1;
	              seq_num_keep_2 = msg_seq_num_reg_2;
	              seq_num_keep_3 = msg_seq_num_reg_3;
	              seq_num_keep_4 = msg_seq_num_reg_4;
	              seq_num_keep_5 = msg_seq_num_reg_5;
	              seq_num_keep_6 = msg_seq_num_reg_6;
	              seq_num_keep_7 = msg_seq_num_reg_7;
		end
		3'b001:begin
	              //resend_ack_next = 'b1;
	              seq_num_keep_0 = msg_seq_num_reg_0;
	              seq_num_keep_1 = msg_seq_num_reg_1;
	              seq_num_keep_2 = msg_seq_num_reg_2;
	              seq_num_keep_3 = msg_seq_num_reg_3;
	              seq_num_keep_4 = msg_seq_num_reg_4;
	              seq_num_keep_5 = msg_seq_num_reg_5;
	              seq_num_keep_6 = msg_seq_num_reg_6;
	              seq_num_keep_7 = msg_seq_num_reg_7;
		end
		3'b000:begin
		      //resend_ack_next = 'b0;
                      seq_num_keep_0 = msg_seq_num_reg_0;
                      seq_num_keep_1 = msg_seq_num_reg_1;
                      seq_num_keep_2 = msg_seq_num_reg_2;
                      seq_num_keep_3 = msg_seq_num_reg_3;
                      seq_num_keep_4 = msg_seq_num_reg_4;
                      seq_num_keep_5 = msg_seq_num_reg_5;
                      seq_num_keep_6 = msg_seq_num_reg_6;
                      seq_num_keep_7 = msg_seq_num_reg_7;
		end		
	endcase
end



always @(posedge clk) begin
        if(reset)begin
           msg_seq_num_reg_0 <= 4'd0;
           msg_seq_num_reg_1 <= 4'd0;
           msg_seq_num_reg_2 <= 4'd0;
           msg_seq_num_reg_3 <= 4'd0;
           msg_seq_num_reg_4 <= 4'd0;
           msg_seq_num_reg_5 <= 4'd0;
           msg_seq_num_reg_6 <= 4'd0;
           msg_seq_num_reg_7 <= 4'd0;

           resend_end_reg_0  <= 4'd0;
           resend_end_reg_1  <= 4'd0;
           resend_end_reg_2  <= 4'd0;
           resend_end_reg_3  <= 4'd0;
           resend_end_reg_4  <= 4'd0;
           resend_end_reg_5  <= 4'd0;
           resend_end_reg_6  <= 4'd0;
           resend_end_reg_7  <= 4'd0;

           seq_num_keep_reg_0 <= 4'd0;
           seq_num_keep_reg_1 <= 4'd0;
           seq_num_keep_reg_2 <= 4'd0;
           seq_num_keep_reg_3 <= 4'd0;
           seq_num_keep_reg_4 <= 4'd0;
           seq_num_keep_reg_5 <= 4'd0;
           seq_num_keep_reg_6 <= 4'd0;
           seq_num_keep_reg_7 <= 4'd0;



           seq_num_done      <= 0;
           wr_in_fifo        <= 0;
           resend_ack        <= 'b0;
           resend_counter_reg<= 'h2;
           resend_buffer     <= 'b0;
           resend_flag       <= 'b0;
           seq_hold          <= 'b0;
           wr_delay          <= 0;
      end
      else begin
            //if(tvalid||wr_delay)begin
             // state             <= state_next;
              msg_seq_num_reg_0 <= msg_seq_num_0;
              msg_seq_num_reg_1 <= msg_seq_num_1;
              msg_seq_num_reg_2 <= msg_seq_num_2;
              msg_seq_num_reg_3 <= msg_seq_num_3;
              msg_seq_num_reg_4 <= msg_seq_num_4;
              msg_seq_num_reg_5 <= msg_seq_num_5;
              msg_seq_num_reg_6 <= msg_seq_num_6;
              msg_seq_num_reg_7 <= msg_seq_num_7;

              seq_num_keep_reg_0<= seq_num_keep_0;
              seq_num_keep_reg_1<= seq_num_keep_1;
              seq_num_keep_reg_2<= seq_num_keep_2;
              seq_num_keep_reg_3<= seq_num_keep_3;
              seq_num_keep_reg_4<= seq_num_keep_4;
              seq_num_keep_reg_5<= seq_num_keep_5;
              seq_num_keep_reg_6<= seq_num_keep_6;
              seq_num_keep_reg_7<= seq_num_keep_7;


              resend_end_reg_0  <= resend_end_0 ;
              resend_end_reg_1  <= resend_end_1 ;
              resend_end_reg_2  <= resend_end_2 ;
              resend_end_reg_3  <= resend_end_3 ;
              resend_end_reg_4  <= resend_end_4 ;
              resend_end_reg_5  <= resend_end_5 ;
              resend_end_reg_6  <= resend_end_6 ;
              resend_end_reg_7  <= resend_end_7 ;

              //resend_ack        <= resend_ack_next;
           //end

	    if(resend_mode_one)begin
	      resend_ack        <= 1'b1; 
              msg_seq_num_reg_0 <= fix_resend_num_begin[3:0];
              msg_seq_num_reg_1 <= fix_resend_num_begin[7:4];
              msg_seq_num_reg_2 <= fix_resend_num_begin[11:8];
              msg_seq_num_reg_3 <= fix_resend_num_begin[15:12];
              msg_seq_num_reg_4 <= fix_resend_num_begin[19:16];
              msg_seq_num_reg_5 <= fix_resend_num_begin[23:20];
              msg_seq_num_reg_6 <= fix_resend_num_begin[27:24];
              msg_seq_num_reg_7 <= fix_resend_num_begin[31:28];
	    end
	    else if(resend_mode_two)begin
	       resend_ack	 <= 1'b1;
               msg_seq_num_reg_0 <= fix_resend_num_begin[3:0];
               msg_seq_num_reg_1 <= fix_resend_num_begin[7:4];
               msg_seq_num_reg_2 <= fix_resend_num_begin[11:8];
               msg_seq_num_reg_3 <= fix_resend_num_begin[15:12];
               msg_seq_num_reg_4 <= fix_resend_num_begin[19:16];
               msg_seq_num_reg_5 <= fix_resend_num_begin[23:20];
               msg_seq_num_reg_6 <= fix_resend_num_begin[27:24];
               msg_seq_num_reg_7 <= fix_resend_num_begin[31:28];

               resend_end_reg_0 <= fix_resend_num_end[3:0];
               resend_end_reg_1 <= fix_resend_num_end[7:4];
               resend_end_reg_2 <= fix_resend_num_end[11:8];
               resend_end_reg_3 <= fix_resend_num_end[15:12];
               resend_end_reg_4 <= fix_resend_num_end[19:16];
               resend_end_reg_5 <= fix_resend_num_end[23:20];
               resend_end_reg_6 <= fix_resend_num_end[27:24];
               resend_end_reg_7 <= fix_resend_num_end[31:28];

	    end
	    else if(resend_mode_three)begin
              resend_ack        <= 1'b1;
              msg_seq_num_reg_0 <= fix_resend_num_begin[3:0];
              msg_seq_num_reg_1 <= fix_resend_num_begin[7:4];
              msg_seq_num_reg_2 <= fix_resend_num_begin[11:8];
              msg_seq_num_reg_3 <= fix_resend_num_begin[15:12];
              msg_seq_num_reg_4 <= fix_resend_num_begin[19:16];
              msg_seq_num_reg_5 <= fix_resend_num_begin[23:20];
              msg_seq_num_reg_6 <= fix_resend_num_begin[27:24];
              msg_seq_num_reg_7 <= fix_resend_num_begin[31:28];
	    end

            if(msg_seq_num_reg_0 == 4'd10) begin
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


           if(tlast&& tvalid)begin
                        wr_delay   <= 1;
                        //wr_in_fifo <= 1;
           end
           else begin
                        wr_delay   <= 0;
                        //wr_in_fifo <= 0;
           end
           if(wr_delay)begin
                        wr_in_fifo <= 1;
           end
           else begin
                        wr_in_fifo <= 0;
           end
        end
end


endmodule	
