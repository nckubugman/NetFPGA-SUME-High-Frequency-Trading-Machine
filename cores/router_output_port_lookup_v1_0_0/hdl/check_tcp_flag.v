///////////////////////////////////////////////////////////////////////////////
// $Id: tcp_check.v 5089 2009-02-23 02:14:38Z grg $
//
// Module: check_tcp_flag.v
// Project: NF2.1
// Description: Detect the tcp syn,ack packet
//              
//
///////////////////////////////////////////////////////////////////////////////

  module check_tcp_flag
    #(parameter C_S_AXIS_DATA_WIDTH =  256,
      parameter C_S_AXIS_TUSER_WIDTH = 128
      //parameter NUM_QUEUES = 5
      )

    (
     input [C_S_AXIS_DATA_WIDTH-1:0]    tdata,
     input                              tvalid,
     input                              tlast,
     input [C_S_AXIS_TUSER_WIDTH-1:0]   tuser,
   
     input			   word_IP_DST_HI,
     input                         word_IP_DST_LO,
     input			   word_OPT_PAYLOAD,
     
     input			   rd_check,
 
     output                        hand_shake_vld,
     output			   is_tcp_hand_shake,
     output			   is_tcp_ack,
     output			   is_tcp_fin,
  
//     output			   is_fix,           
     output [31:0]		   ack_value,
     output [31:0]		   seq_value,
     output [31:0]		   ts_val,
     output [31:0]		   ecr_val,

     input                         reset,
     input                         clk
    );

// --- flag
     reg                           is_tcp;

     reg			   is_syn_ack;
     reg			   is_ack;
     reg			   is_fin;
     reg			   is_psh;
     reg 			   ip_correct;
     reg			   port_correct;
     reg 			   ack_correct;
     reg [31:0]		 	   ack_num;
     reg [31:0]			   ack_check;
     reg [31:0]			   seq_num;
     reg [31:0]			   ts_num;
     reg [31:0]			   ecr_num;
     reg [15:0]  		   pkt_len;

     reg			   is_eop_delay;
     reg			   ctrl_prev_is_0;
     reg			   check_done;
     wire			   empty;
     wire			   hand_shake_check;
     wire			   is_eop;
     wire			   hand_shake_ack;
     wire			   hand_shake_fin;
     wire			   fix_pkt;


/*fallthrough_small_fifo #(.WIDTH(132), .MAX_DEPTH_BITS(5))
   check_tcp_fifo
   (.din               ({hand_shake_check, hand_shake_ack, hand_shake_fin, fix_pkt, seq_num, ack_num, ts_num, ecr_num}),
    .wr_en             (check_done),
    .rd_en             (rd_check),
    .dout              ({is_tcp_hand_shake, is_tcp_ack, is_tcp_fin, is_fix,seq_value, ack_value, ts_val, ecr_val}),
    .full              (),
    .nearly_full       (),
    .prog_full         (),
    .empty             (empty),
    .reset             (reset),
    .clk               (clk)
   );*/
fallthrough_small_fifo #(.WIDTH(131), .MAX_DEPTH_BITS(5))
   check_tcp_fifo
   (.din               ({hand_shake_check, hand_shake_ack, hand_shake_fin, seq_num, ack_num, ts_num, ecr_num}),
    .wr_en             (check_done),
    .rd_en             (rd_check),
    .dout              ({is_tcp_hand_shake, is_tcp_ack, is_tcp_fin, seq_value, ack_value, ts_val, ecr_val}),
    .full              (),
    .nearly_full       (),
    .prog_full         (),
    .empty             (empty),
    .reset             (reset),
    .clk               (clk)
   );
//----------------------- Logic --------------------------//
     assign    hand_shake_vld = !empty;
     assign    hand_shake_check = is_tcp & is_syn_ack  ;//0606 & ack_correct;
     assign    hand_shake_ack   = is_tcp & is_ack;
     assign    hand_shake_fin   = is_tcp & is_fin;
     assign    fix_pkt		= is_tcp & is_psh;
    
 //    assign    is_tcp_hand_shake = 1'b1;




/* check flag */

always @(posedge clk) begin
    if(reset) begin
      is_tcp        <= 1'b0;
      is_syn_ack    <= 1'b0;
      is_ack	    <= 1'b0;
      is_fin	    <= 1'b0;
      ip_correct    <= 1'b0;
      port_correct  <= 1'b0;
      ack_correct   <= 1'b0;
      check_done    <= 1'b0;
      ack_num	    <= 0;
      ack_check     <= 1;
      seq_num	    <= 0;
      ts_num	    <= 0;
      ecr_num	    <= 0;
    end
    else begin


//      if(word_IP_FRAG_TTL_PROTO) begin
      if(word_IP_DST_HI)begin
	is_tcp      <= (tdata[71:64] == 8'h6) ? 1'b1 : 1'b0;
	pkt_len     <= tuser[15:0];
      end
//	is_tcp <= 1'b1;
//      end
      /*else if(word_IP_CHECKSUM_SRC_HI) begin
       
      end
      else if(word_IP_SRC_DST) begin

      end*/
      else if(word_IP_DST_LO) begin
                is_syn_ack  <= (tdata[139:128] == 12'b000000010010) ? 1'b1 : 1'b0;
                is_ack      <= (tdata[139:128] == 12'b000000010000) ? 1'b1 : 1'b0;
                is_fin      <= (tdata[139:128] == 12'b000000010001) ? 1'b1 : 1'b0;
                is_psh      <= (tdata[139:128] == 12'b000000011000) ? 1'b1 : 1'b0;
                ack_check   <= tdata[175:144] +1 ;

	if(is_tcp) begin
/*	
		seq_num[31:16] <= tdata[207:192]; //overflow
		seq_num[15:0]  <= ((tdata[139:128]== 12'b00000010010)||(tdata[139:128]==12'b0000001001))?(tdata[191:176]+1):(tdata[191:176]+pkt_len - 66);
*/	
		seq_num <= ((tdata[139:128]== 12'b00000010010)||(tdata[139:128]==12'b000000010001))?(tdata[207:176]+1):(tdata[207:176]+pkt_len - 66);

		ack_num <= tdata[175:144];
                ts_num <= (is_ack || is_fin || is_psh)? tdata[47:16]: {tdata[15:0], {16'h0000}};
                ecr_num[31:16] <= (is_ack || is_fin || is_psh)? tdata[15:0]: ecr_num[31:16];
	end
      end
      else if(word_OPT_PAYLOAD) begin
	if(is_tcp) begin
                ts_num[15:0] <= (is_syn_ack)? tdata[255:240]: ts_num[15:0];
                ecr_num <= (is_ack || is_fin || is_psh)? {ecr_num[31:16], tdata[255:240]}: tdata[239:208];//191 176 175 144
	end
	else begin
                ts_num <= ts_num + 1;
        end
        check_done <= 1'b1;

      end
      else begin
	check_done  <= 1'b0;
	//is_syn_ack <= 1'b0;
	//is_ack	   <= 1'b0;
      end
 

    end

end

/*always @(*) begin
    if(reset) begin
	hand_shake_check = 0;
    end
    else begin
        hand_shake_check = (is_tcp & is_syn_ack & ack_correct);
    end
end*/

endmodule
