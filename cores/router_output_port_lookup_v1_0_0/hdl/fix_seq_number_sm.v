module fix_seq_number_sm
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
   input 		              seq_num_out_word_OPT_PAYLOAD,
   input           		      seq_num_out_word_IP_DST_LO,
   input           		      seq_num_out_word_IP_DST_HI

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
   reg	  resend_ack_next;
   reg	  wr_delay ;
//   wire [3:0] hundred_thousand,ten_thousand,thousand, hundred, ten, one;


/*
   wire [23:0]            seq_num;
   wire  [3:0]              seq_num_0;
   wire  [3:0]              seq_num_1;
   wire  [3:0]              seq_num_2;
   wire  [3:0]              seq_num_3;
   wire  [3:0]              seq_num_4;
   wire  [3:0]              seq_num_5;
   wire  [3:0]              seq_num_6;
   wire  [3:0]              seq_num_7;
*/
   // --- wade resend seq num temp


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

   reg	[3:0]		   seq_num_keep_0;
   reg  [3:0]		   seq_num_keep_1;
   reg	[3:0]		   seq_num_keep_2;
   reg	[3:0]		   seq_num_keep_3;
   reg	[3:0]		   seq_num_keep_4;
   reg	[3:0]		   seq_num_keep_5;
   reg	[3:0]		   seq_num_keep_6;
   reg	[3:0]		   seq_num_keep_7;


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
   reg[NUM_STATES-1:0]	   state_next;



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


   localparam NUM_STATES          = 16;
   localparam WAIT		  = 1;
   localparam FIX_PKT_SEQ_NUM     = 2;
   localparam RESEND_MODE_THREE   = 4;
   localparam RESEND_MODE_TWO     = 8;
   localparam RESEND_MODE_ONE     = 16;
   localparam CHECK_CARRY	  = 32;  
   localparam PASS_PKT  	  = 64;
   localparam SET_SEQ_NUM	  = 128;




assign fix_seq_num_vld = !empty;



always@(*)begin
/*
      msg_seq_num_0 = msg_seq_num_reg_0;
      msg_seq_num_1 = msg_seq_num_reg_1;
      msg_seq_num_2 = msg_seq_num_reg_2;
      msg_seq_num_3 = msg_seq_num_reg_3;
      msg_seq_num_4 = msg_seq_num_reg_4;
      msg_seq_num_5 = msg_seq_num_reg_5;
      msg_seq_num_6 = msg_seq_num_reg_6;
      msg_seq_num_7 = msg_seq_num_reg_7;
*/
      case(state)
        WAIT: begin
/*		
	      msg_seq_num_0 = msg_seq_num_reg_0;
	      msg_seq_num_1 = msg_seq_num_reg_1;
	      msg_seq_num_2 = msg_seq_num_reg_2;
	      msg_seq_num_3 = msg_seq_num_reg_3;
	      msg_seq_num_4 = msg_seq_num_reg_4;
	      msg_seq_num_5 = msg_seq_num_reg_5;
	      msg_seq_num_6 = msg_seq_num_reg_6;
	      msg_seq_num_7 = msg_seq_num_reg_7;
*/		
//	      if(seq_num_out_word_IP_DST_HI&&(tuser[63:48]==16'h1f||tuser[63:48]==16'h7f||tuser[63:48]==16'h3f)&&tvalid) begin
	      if(tlast&&(tuser[63:48]==16'h05||tuser[63:48]==16'h07)&&tvalid)begin //test_req_heartbeat , 

		     msg_seq_num_0 = msg_seq_num_reg_0 + 4'd1;
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
	
			//state_next = FIX_PKT_SEQ_NUM ;
		     state_next = WAIT;
/*
			if()begin
			end			
*/
	      end

	      else if (tuser[47:32]==16'h01)begin
			state_next = PASS_PKT;
	      end

	      else if(resend_mode_one)begin
			state_next = RESEND_MODE_ONE;
	      end  
	      else if(resend_mode_two)begin
			state_next = RESEND_MODE_TWO;
	      end
	      else if(resend_mode_three)begin
			state_next = RESEND_MODE_THREE;
	      end
		
	end
	PASS_PKT: begin
		if(tlast && tvalid)begin
			state_next = WAIT;
		end
	end
	FIX_PKT_SEQ_NUM:begin
	      msg_seq_num_0 = msg_seq_num_reg_0 + 4'd1;

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
		state_next = WAIT;
	    //  state_next    =  CHECK_CARRY ; 
	end	
	RESEND_MODE_THREE:begin
	      
	      resend_ack_next = 'b1;
              seq_num_keep_0 = msg_seq_num_reg_0; 
              seq_num_keep_1 = msg_seq_num_reg_1; 
              seq_num_keep_2 = msg_seq_num_reg_2;
              seq_num_keep_3 = msg_seq_num_reg_3;
              seq_num_keep_4 = msg_seq_num_reg_4;
              seq_num_keep_5 = msg_seq_num_reg_5; 
              seq_num_keep_6 = msg_seq_num_reg_6;
              seq_num_keep_7 = msg_seq_num_reg_7;

              msg_seq_num_0 = fix_resend_num_begin[3:0];
              msg_seq_num_1 = fix_resend_num_begin[7:4];
              msg_seq_num_2 = fix_resend_num_begin[11:8];
              msg_seq_num_3 = fix_resend_num_begin[15:12];
              msg_seq_num_4 = fix_resend_num_begin[19:16];
              msg_seq_num_5 = fix_resend_num_begin[23:20];
              msg_seq_num_6 = fix_resend_num_begin[27:24];
              msg_seq_num_7 = fix_resend_num_begin[31:28];

	      state_next    =  WAIT;
	end
	RESEND_MODE_TWO:begin
	      resend_ack_next = 'b1;
              seq_num_keep_0 = msg_seq_num_reg_0;
              seq_num_keep_1 = msg_seq_num_reg_1;
              seq_num_keep_2 = msg_seq_num_reg_2;
              seq_num_keep_3 = msg_seq_num_reg_3;
              seq_num_keep_4 = msg_seq_num_reg_4;
              seq_num_keep_5 = msg_seq_num_reg_5;
              seq_num_keep_6 = msg_seq_num_reg_6;
              seq_num_keep_7 = msg_seq_num_reg_7;

              msg_seq_num_0 = fix_resend_num_begin[3:0];
              msg_seq_num_1 = fix_resend_num_begin[7:4];
              msg_seq_num_2 = fix_resend_num_begin[11:8];
              msg_seq_num_3 = fix_resend_num_begin[15:12];
              msg_seq_num_4 = fix_resend_num_begin[19:16];
              msg_seq_num_5 = fix_resend_num_begin[23:20];
              msg_seq_num_6 = fix_resend_num_begin[27:24];
              msg_seq_num_7 = fix_resend_num_begin[31:28];
  
              resend_end_0 = fix_resend_num_end[3:0];
              resend_end_1 = fix_resend_num_end[7:4];
              resend_end_2 = fix_resend_num_end[11:8];
              resend_end_3 = fix_resend_num_end[15:12];
              resend_end_4 = fix_resend_num_end[19:16];
              resend_end_5 = fix_resend_num_end[23:20];
              resend_end_6 = fix_resend_num_end[27:24];
              resend_end_7 = fix_resend_num_end[31:28];


              state_next = WAIT;
	end
	RESEND_MODE_ONE:begin
	      resend_ack_next = 'b1;
              seq_num_keep_0 = msg_seq_num_reg_0;
              seq_num_keep_1 = msg_seq_num_reg_1;
              seq_num_keep_2 = msg_seq_num_reg_2;
              seq_num_keep_3 = msg_seq_num_reg_3;
              seq_num_keep_4 = msg_seq_num_reg_4;
              seq_num_keep_5 = msg_seq_num_reg_5;
              seq_num_keep_6 = msg_seq_num_reg_6;
              seq_num_keep_7 = msg_seq_num_reg_7;

              msg_seq_num_0 = fix_resend_num_begin[3:0];
              msg_seq_num_1 = fix_resend_num_begin[7:4];
              msg_seq_num_2 = fix_resend_num_begin[11:8];
              msg_seq_num_3 = fix_resend_num_begin[15:12];
              msg_seq_num_4 = fix_resend_num_begin[19:16];
              msg_seq_num_5 = fix_resend_num_begin[23:20];
              msg_seq_num_6 = fix_resend_num_begin[27:24];
              msg_seq_num_7 = fix_resend_num_begin[31:28];

              state_next = WAIT;
              
	end
	CHECK_CARRY:begin
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
	      state_next = WAIT;
	    /*
	      if(tlast&&tvalid)begin
	      		state_next = WAIT;
	      end
	      else begin
			state_next = CHECK_CARRY;
	      end
	    */
	end
	SET_SEQ_NUM : begin
              msg_seq_num_0 = cpu2ip_overwrite_fix_seq_num_reg[3:0];
              msg_seq_num_1 = cpu2ip_overwrite_fix_seq_num_reg[7:4];
              msg_seq_num_2 = cpu2ip_overwrite_fix_seq_num_reg[11:8];
              msg_seq_num_3 = cpu2ip_overwrite_fix_seq_num_reg[15:12];
              msg_seq_num_4 = cpu2ip_overwrite_fix_seq_num_reg[19:16];
              msg_seq_num_5 = cpu2ip_overwrite_fix_seq_num_reg[23:20];
              msg_seq_num_6 = cpu2ip_overwrite_fix_seq_num_reg[27:24];
              msg_seq_num_7 = cpu2ip_overwrite_fix_seq_num_reg[31:28];
	      state_next    = WAIT;
	end


	default : begin
		state_next = WAIT; 
	end
    endcase	
end



always @(posedge clk) begin
	if(reset)begin
	   state 	     <= WAIT;
           msg_seq_num_reg_0 <= 4'd1;
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
	   wr_delay 	     <= 0;
	end
	else begin
	    //if(tvalid||wr_delay)begin 
	      state	        <= state_next;
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

	      resend_ack 	<= resend_ack_next;
	   //end
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
