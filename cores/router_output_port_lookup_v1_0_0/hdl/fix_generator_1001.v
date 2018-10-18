///////////////////////////////////////////////////////////////////////////////
//
// Module: decision_executor.v
// Author: 
// LAB:    CIAL
// Date:   2018-5-29
//
///////////////////////////////////////////////////////////////////////////////

module fix_generator
#(
    //Master AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH	= 256,
    parameter C_S_AXIS_DATA_WIDTH	= 256,
    parameter C_M_AXIS_TUSER_WIDTH	= 128,
    parameter C_S_AXIS_TUSER_WIDTH	= 128,
    parameter NUM_OUTPUT_QUEUES		= 8,
    parameter NUM_OUTPUT_QUEUES_WIDTH	= log2(NUM_OUTPUT_QUEUES),
    parameter LPM_LUT_DEPTH		= 32,
    parameter LPM_LUT_DEPTH_BITS 	= log2(LPM_LUT_DEPTH),
    parameter ARP_LUT_DEPTH 		= 32,
    parameter ARP_LUT_DEPTH_BITS	= log2(ARP_LUT_DEPTH),
    parameter FILTER_DEPTH		= 32,
    parameter FILTER_DEPTH_BITS		= log2(FILTER_DEPTH)
)
(
    // Global Ports
    input axis_aclk,
    input axis_resetn,

    // Master Stream Ports (interface to data path)
    output [C_M_AXIS_DATA_WIDTH - 1:0]		m_axis_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0]	m_axis_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]		m_axis_tuser,
    output m_axis_tvalid,
    input  m_axis_tready,
    output m_axis_tlast,

    // Slave Stream Ports (interface to RX queues)
    input [C_S_AXIS_DATA_WIDTH - 1:0]		s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0]	s_axis_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]		s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast,
 
     // --- interface to stock_id_mapping
    input [9:0]                                      stock_id_mapping_rd_addr,
    input                                            stock_id_mapping_rd_req,
    output [69:0]                                    stock_id_mapping_rd_data,
    output                                           stock_id_mapping_rd_ack,
    input [9:0]		                             stock_id_mapping_wr_addr,
    input                                            stock_id_mapping_wr_req,
    input [69:0]                                     stock_id_mapping_wr_data,
    output                                           stock_id_mapping_wr_ack,

    // --- interface to commodity_id_mapping
    input [10:0]                                     warrants_id_mapping_rd_addr,
    input                                            warrants_id_mapping_rd_req,
    output [11:0]                                    warrants_id_mapping_rd_data,
    output                                           warrants_id_mapping_rd_ack,
    input [10:0]		                     warrants_id_mapping_wr_addr,
    input                                            warrants_id_mapping_wr_req,
    input [11:0]                                     warrants_id_mapping_wr_data,
    output                                           warrants_id_mapping_wr_ack,
    
    // --- interface to order_id_mapping
    input [12:0]                                     order_id_mapping_rd_addr,
    input                                            order_id_mapping_rd_req,
    output [47:0]                                    order_id_mapping_rd_data,
    output                                           order_id_mapping_rd_ack,
    input [11:0]		                     order_id_mapping_wr_addr,
    input                                            order_id_mapping_wr_req,
    input [47:0]                                     order_id_mapping_wr_data,
    output                                           order_id_mapping_wr_ack,
    
    input [15:0]                  pkt_year,
    input [15:0]                  pkt_mon,
    input [15:0]                  pkt_day,
    input [15:0]                  pkt_hour,
    input [15:0]                  pkt_min,
    input [15:0]                  pkt_sec,
    input [15:0]                  pkt_ms,
   
    // counter wade
    output			  og_not_empty,

   //FIX Connection
    
    output                             order_sended,
    // --- connect_signal
//    input [31:0]                       cpu2ip_connect_signal_reg,

    //output                             connect_value,
    input                             syn_sended,
    input                             is_syn_ack,
    input                             logon_sended,
    input                             is_ack,
    input                             ack_sended,
    input                             is_fix_logon,
    input                             is_fix_report,

    input [31:0]		      fix_resend_num_begin,
    input [31:0]		      fix_resend_num_end,
    //input                              resend_req,
    output                             resend_ack,

    input				resend_mode_one,
    input				resend_mode_two,
    input				resend_mode_three,
    input				is_resend,

    input [31:0]		      cpu2ip_overwrite_fix_seq_num_reg,
    
    input				is_connect_pkt,
    input				is_order_pkt,
    // --- Reset Tables

    input [3:0]				 reset_tables
    //output [31:0]			is_og_pkt_counter

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

   //--------------------- Internal Parameter-------------------------


   //---------------------- Wires and regs----------------------------
/*
   wire [C_M_AXIS_DATA_WIDTH-1:0]	in_fifo_tdata;
   wire [C_M_AXIS_TUSER_WIDTH-1:0]	in_fifo_tuser;
   wire [C_M_AXIS_DATA_WIDTH/8-1:0]	in_fifo_tkeep;
   wire					in_fifo_tlast;

   wire                        		in_fifo_nearly_full;
   wire					in_fifo_empty;
   wire					in_fifo_rd_en;
*/
   wire 				fix_format_fifo_rd_en;

   wire					parse_all_rdy;

/*----------------For Wade Design-------------------------------------*/ 
   wire					parse_vld;
   wire					parse_rdy;
   wire					rd_preprocess_info;
   wire					commodity_fifo_rd;
   wire [47:0]				stock_code_out;
   wire [71:0]				commodity_index_out;
   wire					parse_order_vld;
   wire					parse_order_rdy;
   wire					commodity_id_mapping_vld;
   wire [216:0]				order_index_out;

   wire					order_vld;
   wire [215:0]				order_out;
   wire					order_rd;

   wire					sid_not_empty;
   wire					cid_not_empty;

   wire [255:0]                 stock_id_mapping_in_tdata;
   wire [31:0]                  stock_id_mapping_in_tkeep;
   wire [127:0]                 stock_id_mapping_in_tuser;
   wire                         stock_id_mapping_in_tvalid;
   wire                         stock_id_mapping_in_tlast;




   wire [255:0]                 seq_num_out_tdata_buf;
   wire [31:0]                  seq_num_out_tkeep_buf;
   wire [127:0]                 seq_num_out_tuser_buf;
   wire                         seq_num_out_tvalid_buf;
   wire                         seq_num_out_tlast_buf;


   wire [255:0]                 fix_out_tdata_buf;
   wire [31:0]                  fix_out_tkeep_buf;
   wire [127:0]			fix_out_tuser_buf;
   wire                         fix_out_tvalid_buf;
   wire                         fix_out_tlast_buf;


   wire [255:0]                 ip_tcp_out_tdata_buf;
   wire [31:0]                  ip_tcp_out_tkeep_buf;
   wire [127:0]                 ip_tcp_out_tuser_buf;
   wire                         ip_tcp_out_tvalid_buf;
   wire                         ip_tcp_out_tlast_buf;
  
   wire [255:0]            id_mapping_out_tdata_buf;
   wire [31:0]             id_mapping_out_tkeep_buf;
   wire [127:0]            id_mapping_out_tuser_buf;
   wire                    id_mapping_out_tvalid_buf;
   wire                    id_mapping_out_tlast_buf;

 
   //-----------------------------------------//

   //-------------out fifo----------------------//
   wire [31:0]                  seq_num_out_fifo_tkeep_buf;
   wire [255:0]                 seq_num_out_fifo_tdata_buf;
   wire                         seq_num_out_fifo_tlast_buf;
   wire [127:0]                 seq_num_out_fifo_tuser_buf;
   wire                         seq_num_out_fifo_rd_en;
   wire                         seq_num_out_fifo_nearly_full;
   wire                         seq_num_out_fifo_empty;



   wire [31:0]                  fix_out_fifo_tkeep_buf;
   wire [255:0]                 fix_out_fifo_tdata_buf;
   wire                         fix_out_fifo_tlast_buf;
   wire [127:0]			fix_out_fifo_tuser_buf;
   wire                         fix_out_fifo_rd_en;
   wire                         fix_out_fifo_nearly_full;
   wire				fix_out_fifo_empty;



   wire [31:0]                  ip_tcp_out_fifo_tkeep_buf;
   wire [255:0]                 ip_tcp_out_fifo_tdata_buf;
   wire                         ip_tcp_out_fifo_tlast_buf; 
   wire [127:0]			ip_tcp_out_fifo_tuser_buf;
   wire                         ip_tcp_out_fifo_rd_en;
   wire				ip_tcp_out_fifo_nearly_full;
   wire				ip_tcp_out_fifo_empty;

   wire [255:0]            	id_mapping_out_fifo_tdata_buf;
   wire [31:0]   	   	id_mapping_out_fifo_tkeep_buf;
   wire [127:0]            	id_mapping_out_fifo_tuser_buf;
   wire  		  	id_mapping_out_fifo_tlast_buf;
   wire				id_mapping_out_fifo_rd_en;
   wire				id_mapping_out_fifo_nearly_full;
   wire				id_mapping_out_fifo_empty;

   
  //--------------------------------------------//

  //----out data preprocess control ---------//

   wire           id_mapping_out_word_OPT_PAYLOAD;
   wire		  id_mapping_out_word_OPT_PAYLOAD_2;
   wire		  id_mapping_out_word_OPT_PAYLOAD_3;
   wire		  id_mapping_out_word_OPT_PAYLOAD_4;
   wire           id_mapping_out_word_IP_DST_LO;
   wire           id_mapping_out_word_IP_DST_HI;




   wire           seq_num_out_word_OPT_PAYLOAD;
   wire		  seq_num_out_word_OPT_PAYLOAD_2;
   wire		  seq_num_out_word_OPT_PAYLOAD_3;
   wire		  seq_num_out_word_OPT_PAYLOAD_4;
   wire           seq_num_out_word_IP_DST_LO;
   wire           seq_num_out_word_IP_DST_HI;


  
   wire           fix_out_word_OPT_PAYLOAD;
   wire		  fix_out_word_OPT_PAYLOAD_2;
   wire		  fix_out_word_OPT_PAYLOAD_3;
   wire		  fix_out_word_OPT_PAYLOAD_4;
   wire           fix_out_word_IP_DST_LO;
   wire           fix_out_word_IP_DST_HI;

   wire           ip_tcp_out_word_OPT_PAYLOAD;
   wire		  ip_tcp_out_word_OPT_PAYLOAD_2;
   wire		  ip_tcp_out_word_OPT_PAYLOAD_3;
   wire		  ip_tcp_out_word_OPT_PAYLOAD_4;
   wire           ip_tcp_out_word_IP_DST_LO;
   wire           ip_tcp_out_word_IP_DST_HI;



   wire                        rd_fix;
   wire			       rd_ip_tcp;
   wire			       rd_fix_seq_num;
 
 


   wire 		       ip_checksum_vld;
   wire	[15:0]		       ip_new_checksum;

   wire                        tcp_checksum_vld;
   wire [15:0]                 tcp_new_checksum;

   wire			       fix_checksum_vld;
   wire [11:0]		       fix_new_checksum;


   wire				fix_seq_num_vld;
   wire	[23:0]			fix_new_seq_num;



   wire                        fix_filter_vld;
   wire                        is_fix_order;
  // ----new check tcp flag
   wire                        hand_shake_vld;
   wire                        is_tcp_hand_shake;
   wire                        is_tcp_ack;
   wire                        is_tcp_fin;
   wire                        fix_filter_vld;
   wire                        is_fix;
   wire                        is_report;
   wire                        is_resend;
   wire [31:0]                 ack_value;
   wire [31:0]                 seq_value;
   wire [31:0]                 ts_val;
   wire [31:0]                 ecr_val;
   wire                        receive_tcp_checksum_is_good;
   wire                        receive_tcp_checksum_vld;


/*   
   wire [C_S_AXIS_DATA_WIDTH - 1:0]           id_mapping_out_tdata;
   wire [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0]   id_mapping_out_tkeep;
   wire [C_S_AXIS_TUSER_WIDTH-1:0]            id_mapping_out_tuser;
   wire  id_mapping_out_tvalid;
   wire  id_mapping_out_tready;
   wire  id_mapping_out_tlast;
*/





   // --- wade fix server seq
   //wire [31:0]           fix_server_seq;
   
   wire                   is_fix_out;


   //-------------------- Modules and Logic ---------------------------
   //assign s_axis_tready = ~in_fifo_nearly_full;
//    assign s_axis_tready = ~tcp_out_fifo_nearly_full;
//   assign s_axis_tready = parse_rdy & parse_order_rdy;

//   assign og_queue_empty = fix_queue_empty;
//    assign og_queue_empty = de_queue_empty & fix_queue_empty & out_fifo_empty & out_fifo_empty_2;

/*
   assign s_axis_tready = parse_rdy&fix_format_fifo_rd_en;
   assign og_not_empty = sid_not_empty;
*/

     assign s_axis_tready = parse_rdy & parse_order_rdy ;
//   assign s_axis_tready = fix_format_fifo_rd_en;
   
   assign og_not_empty = (sid_not_empty || cid_not_empty);


   //assign parse_all_rdy = parse_rdy & parse_order_rdy ;

   /* The size of this fifo has to be large enough to fit the previous modules' headers
    * and the ethernet header */
/*For Debug
   fallthrough_small_fifo #(.WIDTH(C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8+1), .MAX_DEPTH_BITS(6))
      input_fifo_1
        (.din ({s_axis_tlast, s_axis_tuser, s_axis_tkeep, s_axis_tdata}),	// Data in
         .wr_en (s_axis_tvalid ),				// Write enable
         .rd_en (in_fifo_rd_en),						// Read the next word
         .dout ({in_fifo_tlast, in_fifo_tuser, in_fifo_tkeep, in_fifo_tdata}),
         .full (),
         .prog_full (),
         .nearly_full (in_fifo_nearly_full),
         .empty (in_fifo_empty),
         .reset (~axis_resetn),
         .clk (axis_aclk)
         );
*/

/*
   fallthrough_small_fifo #(.WIDTH(1+C_S_AXIS_TUSER_WIDTH+ C_S_AXIS_DATA_WIDTH/8+C_S_AXIS_DATA_WIDTH), .MAX_DEPTH_BITS(6))
      seq_num_output_buff_fifo
        (.din           ({seq_num_out_tlast_buf,seq_num_out_tuser_buf,seq_num_out_tkeep_buf, seq_num_out_tdata_buf}),  // Data in
         .wr_en         (seq_num_out_tvalid_buf),             // Write enable
         .rd_en         (seq_num_out_fifo_rd_en),    // Read the next word
         .dout          ({seq_num_out_fifo_tlast_buf,seq_num_out_fifo_tuser_buf,seq_num_out_fifo_tkeep_buf, seq_num_out_fifo_tdata_buf}),
         .full          (),
         .nearly_full   (seq_num_out_fifo_nearly_full),
         .prog_full     (),
         .empty         (seq_num_out_fifo_empty),
         .reset         (~axis_resetn),
         .clk           (axis_aclk)
         );


   fallthrough_small_fifo #(.WIDTH(1+C_S_AXIS_TUSER_WIDTH+ C_S_AXIS_DATA_WIDTH/8+C_S_AXIS_DATA_WIDTH), .MAX_DEPTH_BITS(6))
      fix_output_buff_fifo
        (.din           ({fix_out_tlast_buf,fix_out_tuser_buf,fix_out_tkeep_buf, fix_out_tdata_buf}),  // Data in
         .wr_en         (fix_out_tvalid_buf),             // Write enable
         .rd_en         (fix_out_fifo_rd_en),    // Read the next word
         .dout          ({fix_out_fifo_tlast_buf,fix_out_fifo_tuser_buf,fix_out_fifo_tkeep_buf, fix_out_fifo_tdata_buf}),
         .full          (),
         .nearly_full   (fix_out_fifo_nearly_full),
         .prog_full     (),
         .empty         (fix_out_fifo_empty),
         .reset         (~axis_resetn),
         .clk           (axis_aclk)
         );



   fallthrough_small_fifo #(.WIDTH(1+C_S_AXIS_TUSER_WIDTH+C_S_AXIS_DATA_WIDTH/8+C_S_AXIS_DATA_WIDTH), .MAX_DEPTH_BITS(6))
      ip_tcp_output_buff_fifo
        (.din           ({ip_tcp_out_tlast_buf,ip_tcp_out_tuser_buf,ip_tcp_out_tkeep_buf, ip_tcp_out_tdata_buf}),  // Data in
         .wr_en         (ip_tcp_out_tvalid_buf ),             // Write enable
         .rd_en         (ip_tcp_out_fifo_rd_en),    // Read the next word
         .dout          ({ip_tcp_out_fifo_tlast_buf,ip_tcp_out_fifo_tuser_buf,ip_tcp_out_fifo_tkeep_buf, ip_tcp_out_fifo_tdata_buf}),
         .full          (),
         .nearly_full   (ip_tcp_out_fifo_nearly_full),
         .prog_full     (),
         .empty         (ip_tcp_out_fifo_empty),
         .reset         (~axis_resetn),
         .clk           (axis_aclk)
	);


   fallthrough_small_fifo #(.WIDTH(1+C_S_AXIS_TUSER_WIDTH+C_S_AXIS_DATA_WIDTH/8+C_S_AXIS_DATA_WIDTH), .MAX_DEPTH_BITS(6))
      fix_formatter_output_buff_fifo
        (.din           ({id_mapping_out_tlast,id_mapping_out_tuser,id_mapping_out_tkeep,id_mapping_out_tdata}),  // Data in
         .wr_en         (id_mapping_out_tvalid ),             // Write enable
         .rd_en         (id_mapping_out_fifo_rd_en),    // Read the next word
         .dout          ({id_mapping_out_fifo_tlast,id_mapping_out_fifo_tuser,id_mapping_out_fifo_tkeep,id_mapping_out_fifo_tdata}),
         .full          (),
         .nearly_full   (id_mapping_out_fifo_nearly_full),
         .prog_full     (),
         .empty         (id_mapping_out_fifo_empty),
         .reset         (~axis_resetn),
         .clk           (axis_aclk)
        );

*/

//coresspond to  input_fifo_1
/*For Debug
   preprocess_control
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH)
       ) id_mapping_preprocess_control
       ( // --- Interface to the previous stage
	 // --- Input
	  .tdata		    (s_axis_tdata),
          .valid		    (s_axis_tvalid),
	  .tlast		    (s_axis_tlast),

         // --- Interface to other preprocess blocks
	 // --- Output
         .word_IP_DST_HI            (id_mapping_out_word_IP_DST_HI),
         .word_IP_DST_LO            (id_mapping_out_word_IP_DST_LO),
	 .word_OPT_PAYLOAD          (id_mapping_out_word_OPT_PAYLOAD),
	 .word_OPT_PAYLOAD_2	    (id_mapping_out_word_OPT_PAYLOAD_2),
	 .word_OPT_PAYLOAD_3	    (id_mapping_out_word_OPT_PAYLOAD_3),
	 .word_OPT_PAYLOAD_4	    (id_mapping_out_word_OPT_PAYLOAD_4),

         // --- Misc
	 // --- Input
         .reset                     (~axis_resetn),
         .clk                       (axis_aclk)
         );
*/
/*
   preprocess_control
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH)
       ) id_mapping_preprocess_control
       ( // --- Interface to the previous stage
         // --- Input
          .tdata                    (stock_id_mapping_in_tdata),
          .valid                    (stock_id_mapping_in_tvalid),
          .tlast                    (stock_id_mapping_in_tlast),

         // --- Interface to other preprocess blocks
         // --- Output
         .word_IP_DST_HI            (id_mapping_out_word_IP_DST_HI),
         .word_IP_DST_LO            (id_mapping_out_word_IP_DST_LO),
         .word_OPT_PAYLOAD          (id_mapping_out_word_OPT_PAYLOAD),
         .word_OPT_PAYLOAD_2        (id_mapping_out_word_OPT_PAYLOAD_2),
         .word_OPT_PAYLOAD_3        (id_mapping_out_word_OPT_PAYLOAD_3),
         .word_OPT_PAYLOAD_4        (id_mapping_out_word_OPT_PAYLOAD_4),

         // --- Misc
         // --- Input
         .reset                     (~axis_resetn),
         .clk                       (axis_aclk)
         );
*/


/*
   preprocess_control
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH)
       ) seq_num_preprocess_control
       ( // --- Interface to the previous stage
         // --- Input
         .tdata               (seq_num_out_tdata_buf),
         .valid               (seq_num_out_tvalid_buf &~seq_num_out_fifo_nearly_full),
         .tlast               (seq_num_out_tlast_buf),

         // --- Interface to other preprocess blocks
         // --- Output
         .word_IP_DST_HI            (seq_num_out_word_IP_DST_HI),
         .word_IP_DST_LO            (seq_num_out_word_IP_DST_LO),
         .word_OPT_PAYLOAD          (seq_num_out_word_OPT_PAYLOAD),
	 .word_OPT_PAYLOAD_2        (seq_num_out_word_OPT_PAYLOAD_2),
	 .word_OPT_PAYLOAD_3	    (seq_num_out_word_OPT_PAYLOAD_3),
	 .word_OPT_PAYLOAD_4	    (seq_num_out_word_OPT_PAYLOAD_4),

         // --- Misc
         // --- Input
         .reset                     (~axis_resetn),
         .clk                       (axis_aclk)
         );

   preprocess_control
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH)
       ) fix_preprocess_control
       ( // --- Interface to the previous stage
         // --- Input
         .tdata               (fix_out_tdata_buf),
         .valid               (fix_out_tvalid_buf &~fix_out_fifo_nearly_full),
         .tlast               (fix_out_tlast_buf),

         // --- Interface to other preprocess blocks
         // --- Output
         .word_IP_DST_HI            (fix_out_word_IP_DST_HI),
         .word_IP_DST_LO            (fix_out_word_IP_DST_LO),
         .word_OPT_PAYLOAD          (fix_out_word_OPT_PAYLOAD),
	 .word_OPT_PAYLOAD_2	    (fix_out_word_OPT_PAYLOAD_2),
	 .word_OPT_PAYLOAD_3	    (fix_out_word_OPT_PAYLOAD_3),
	 .word_OPT_PAYLOAD_4        (fix_out_word_OPT_PAYLOAD_4),

         // --- Misc
         // --- Input
         .reset                     (~axis_resetn),
         .clk                       (axis_aclk)
         );


   preprocess_control
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH)
       ) 
	ip_tcp_preprocess_control
       ( // --- Interface to the previous stage
   // --- Input
         .tdata       (ip_tcp_out_tdata_buf),
         .valid       (ip_tcp_out_tvalid_buf & ~ip_tcp_out_fifo_nearly_full ),
         .tlast       (ip_tcp_out_tlast_buf),

         // --- Interface to other preprocess blocks
   // --- Output
         .word_IP_DST_HI            (ip_tcp_out_word_IP_DST_HI),
         .word_IP_DST_LO            (ip_tcp_out_word_IP_DST_LO),
         .word_OPT_PAYLOAD          (ip_tcp_out_word_OPT_PAYLOAD),
	 .word_OPT_PAYLOAD_2        (ip_tcp_out_word_OPT_PAYLOAD_2),
	 .word_OPT_PAYLOAD_3	    (ip_tcp_out_word_OPT_PAYLOAD_3),
	 .word_OPT_PAYLOAD_4	    (ip_tcp_out_word_OPT_PAYLOAD_4),


         // --- Misc
   // --- Input
         .reset                     (~axis_resetn),
         .clk                       (axis_aclk)

         );
*/
/*
   check_pkt_sm
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
       .C_S_AXIS_TUSER_WIDTH (C_S_AXIS_TUSER_WIDTH),
       .NUM_QUEUES(NUM_OUTPUT_QUEUES)
       ) check_pkt_sm
	(
         .in_fifo_vld                   (s_axis_tvalid),
         .in_fifo_tdata                 (s_axis_tdata),
         .in_fifo_tlast                 (s_axis_tlast),
         .in_fifo_tuser                 (s_axis_tuser),
         .in_fifo_tkeep                 (s_axis_tkeep),
         .in_fifo_rd_en                 (fix_format_fifo_rd_en),
*/
/*
         .out_tvalid                    (seq_num_out_tvalid_buf),
         .out_tlast                     (seq_num_out_tlast_buf),
         .out_tdata                     (seq_num_out_tdata_buf),
         .out_tuser                     (seq_num_out_tuser_buf),
         .out_tready                    (!seq_num_out_fifo_nearly_full),
         .out_keep                      (seq_num_out_tkeep_buf),
*/
/*
         .out_stock_id_tvalid           (stock_id_mapping_in_tvalid),
         .out_stock_id_tdata            (stock_id_mapping_in_tdata),
         .out_stock_id_tuser            (stock_id_mapping_in_tuser),
         .out_stock_id_keep             (stock_id_mapping_in_tkeep),
         .out_stock_id_tlast            (stock_id_mapping_in_tlast),
         //.out_stock_id_tready           (parse_rdy&parse_order_rdy),//parse_rdy&parse_order_rdy
	 .out_stock_id_tready		(parse_rdy),
	 //.out_stock_id_tready		(parse_all_rdy),
         .reset                         (~axis_resetn),
         .clk                           (axis_aclk)
         );

*/

   
   fix_formatter
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
       .C_S_AXIS_TUSER_WIDTH (C_S_AXIS_TUSER_WIDTH),
       .NUM_QUEUES(NUM_OUTPUT_QUEUES)
       ) fix_formatter
       ( // --- interface to input fifo - fallthrough
	/* 
         .out_tvalid                    (seq_num_out_tvalid_buf),
         .out_tlast                     (seq_num_out_tlast_buf),
         .out_tdata                     (seq_num_out_tdata_buf),
         .out_tuser                     (seq_num_out_tuser_buf),
         .out_tready                    (!seq_num_out_fifo_nearly_full),
         .out_keep                      (seq_num_out_tkeep_buf),
	*/
	/*
         .out_tvalid                    (id_mapping_out_tvalid_buf),
         .out_tlast                     (id_mapping_out_tlast_buf),
         .out_tdata                     (id_mapping_out_tdata_buf),
         .out_tuser                     (id_mapping_out_tuser_buf),
         .out_tready                    (!id_mapping_out_fifo_nearly_full),
         .out_keep                      (id_mapping_out_tkeep_buf),
	*/

          .out_tvalid(m_axis_tvalid),
          .out_tdata (m_axis_tdata),
          .out_keep (m_axis_tkeep),
          .out_tlast (m_axis_tlast),
          .out_tuser (m_axis_tuser),
          .out_tready(m_axis_tready),

         .pkt_ms(pkt_ms),
         .pkt_sec(pkt_sec),
         .pkt_min(pkt_min),
         .pkt_hour(pkt_hour),
         .pkt_day(pkt_day),
         .pkt_mon(pkt_mon),
         .pkt_year(pkt_year),

         .parse_order_vld		(parse_order_vld),
	 .order_index_out		(order_index_out),
	 .rd_preprocess_info		(rd_preprocess_info),

         // --- wade tcp verification

         // misc
         .reset                         (~axis_resetn),
         .clk                           (axis_aclk)
         );


/*

    tcp_checksum
    #(
        .C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
	.C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH)
     )
        tcp_checksum(
                .tdata(ip_tcp_out_tdata_buf),
                .tkeep(ip_tcp_out_tkeep_buf),
                .valid(ip_tcp_out_tvalid_buf),
                .tlast(ip_tcp_out_tlast_buf),
		.tuser(ip_tcp_out_tuser_buf),
                .word_IP_DST_LO(ip_tcp_out_word_IP_DST_LO),
                .word_IP_DST_HI(ip_tcp_out_word_IP_DST_HI),
		.word_OPT_PAYLOAD(ip_tcp_out_word_OPT_PAYLOAD),
                .rd_tcp_checksum(rd_ip_tcp),
                .tcp_new_checksum(tcp_new_checksum),
                .tcp_checksum_vld(tcp_checksum_vld),

                .reset(~axis_resetn),
                .clk(axis_aclk)
     );





    fix_checksum
    #(
        .C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
	.C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH)
     )
    fix_checksum(
              .tdata(fix_out_tdata_buf),
              .tkeep(fix_out_tkeep_buf),
	      .tuser(fix_out_tuser_buf),
              .valid(fix_out_tvalid_buf),
              .tlast(fix_out_tlast_buf),
              .word_IP_DST_LO(fix_out_word_IP_DST_LO),
              .word_IP_DST_HI(fix_out_word_IP_DST_HI),
              .word_OPT_PAYLOAD(fix_out_word_OPT_PAYLOAD),
	      .word_OPT_PAYLOAD_2(fix_out_word_OPT_PAYLOAD_2),
	      .word_OPT_PAYLOAD_3(fix_out_word_OPT_PAYLOAD_3),
	      .word_OPT_PAYLOAD_4(fix_out_word_OPT_PAYLOAD_4),
              .rd_fix_checksum(rd_fix),
              .fix_checksum_vld(fix_checksum_vld),
          //    .fix_checksum_is_good(fix_checksum_is_good),
              .fix_new_checksum(fix_new_checksum),
              .is_fix_out(is_fix_out),
              .reset(~axis_resetn),
              .clk(axis_aclk)

    );

*/

/*

    fix_seq_number_counter_sm
    #(
        .C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
        .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH)
     )
    fix_seq_number_counter_sm(

              .tdata(seq_num_out_tdata_buf),
              .tkeep(seq_num_out_tkeep_buf),
              .tuser(seq_num_out_tuser_buf),
              .tvalid(seq_num_out_tvalid_buf),
              .tlast(seq_num_out_tlast_buf),

              .seq_num_out_word_IP_DST_LO(seq_num_out_word_IP_DST_LO),
              .seq_num_out_word_IP_DST_HI(seq_num_out_word_IP_DST_HI),
              .seq_num_out_word_OPT_PAYLOAD(seq_num_out_word_OPT_PAYLOAD),

              .rd_fix_seq_num(rd_fix_seq_num),
              .fix_seq_num_vld(fix_seq_num_vld),
              .fix_new_seq_num(fix_new_seq_num),    

	      .fix_resend_num_begin(fix_resend_num_begin),
	      .fix_resend_num_end(fix_resend_num_end),
	     // .resend_req(resend_req),
	      .resend_ack(resend_ack),
	      .resend_mode_one(resend_mode_one),
	      .resend_mode_two(resend_mode_two),
	      .resend_mode_three(resend_mode_three),
	      //.is_resend(is_resend),
	      .cpu2ip_overwrite_fix_seq_num_reg(cpu2ip_overwrite_fix_seq_num_reg),

              .reset(~axis_resetn),
              .clk(axis_aclk)

    );






    pkt_buffer_fix_seq_num
    #(
        .C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
        .C_M_AXIS_DATA_WIDTH (C_M_AXIS_DATA_WIDTH),
        .C_M_AXIS_TUSER_WIDTH(C_M_AXIS_TUSER_WIDTH),
        .C_S_AXIS_TUSER_WIDTH (C_S_AXIS_TUSER_WIDTH)
     )
       pkt_buffer_seq_number(


          
         .s_axis_tdata(seq_num_out_fifo_tdata_buf),
         .s_axis_tkeep(seq_num_out_fifo_tkeep_buf),
         .s_axis_tlast(seq_num_out_fifo_tlast_buf),
         .s_axis_tuser(seq_num_out_fifo_tuser_buf),
         .s_axis_tvalid(!seq_num_out_fifo_empty),
         .out_fifo_rd_en(seq_num_out_fifo_rd_en),


         .m_axis_tvalid(fix_out_tvalid_buf),
         .m_axis_tlast (fix_out_tlast_buf),
         .m_axis_tdata (fix_out_tdata_buf),
         .m_axis_tuser (fix_out_tuser_buf),
         .m_axis_tready(!fix_out_fifo_nearly_full),
         .m_axis_tkeep  (fix_out_tkeep_buf),



          .fix_seq_num_vld(fix_seq_num_vld),
          .fix_new_seq_num(fix_new_seq_num),


          .rd_fix_seq_num(rd_fix_seq_num),

          .reset(~axis_resetn),
          .clk(axis_aclk)
        );


*/

/*
    pkt_buffer_fix_checksum
    #(
        .C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
        .C_M_AXIS_DATA_WIDTH (C_M_AXIS_DATA_WIDTH),
        .C_M_AXIS_TUSER_WIDTH(C_M_AXIS_TUSER_WIDTH),
        .C_S_AXIS_TUSER_WIDTH (C_S_AXIS_TUSER_WIDTH)
     )
       pkt_buffer_fix_checksum(
*/

/* For Debug          
          .m_axis_tvalid(m_axis_tvalid),
          .m_axis_tdata (m_axis_tdata),
          .m_axis_tkeep (m_axis_tkeep),
          .m_axis_tlast (m_axis_tlast),
          .m_axis_tuser (m_axis_tuser),
          .m_axis_tready(m_axis_tready),
*/


/*
          .m_axis_tvalid(ip_tcp_out_tvalid_buf),
          .m_axis_tdata (ip_tcp_out_tdata_buf),
          .m_axis_tkeep (ip_tcp_out_tkeep_buf),
          .m_axis_tlast (ip_tcp_out_tlast_buf),
          .m_axis_tuser (ip_tcp_out_tuser_buf),
          .m_axis_tready(!ip_tcp_out_fifo_nearly_full),

          .s_axis_tdata(fix_out_fifo_tdata_buf),
          .s_axis_tkeep(fix_out_fifo_tkeep_buf),
          .s_axis_tlast(fix_out_fifo_tlast_buf),
	  .s_axis_tuser(fix_out_fifo_tuser_buf),
          .s_axis_tvalid(!fix_out_fifo_empty), 

          .out_fifo_rd_en(fix_out_fifo_rd_en),

          .fix_checksum_vld(fix_checksum_vld),
          .fix_new_checksum(fix_new_checksum),


          .rd_fix(rd_fix),
          .is_fix(is_fix_out) ,

          .reset(~axis_resetn),
          .clk(axis_aclk)
        );

*/

/*
     pkt_buffer_ip_tcp_checksum
    #(
      .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
      .C_M_AXIS_DATA_WIDTH(C_M_AXIS_DATA_WIDTH),
      .C_M_AXIS_TUSER_WIDTH(C_M_AXIS_TUSER_WIDTH),
      .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH)
     )pkt_buffer_ip_tcp_checksum(
          .s_axis_tdata (ip_tcp_out_fifo_tdata_buf),
          .s_axis_tkeep (ip_tcp_out_fifo_tkeep_buf),
          .s_axis_tlast (ip_tcp_out_fifo_tlast_buf),
	  .s_axis_tuser (ip_tcp_out_fifo_tuser_buf),
          .s_axis_tvalid(!ip_tcp_out_fifo_empty),
*/
	  /*
          .m_axis_tvalid(m_axis_tvalid),
          .m_axis_tdata (m_axis_tdata),
          .m_axis_tkeep (m_axis_tkeep),
	  .m_axis_tlast (m_axis_tlast),
	  .m_axis_tuser (m_axis_tuser),
          .m_axis_tready(m_axis_tready),
	  */


/*

          .out_fifo_rd_en(ip_tcp_out_fifo_rd_en),

	//tcp checksum
          .tcp_checksum_vld(tcp_checksum_vld),
          .tcp_new_checksum(tcp_new_checksum),
          

	//ip checksum
          .ip_checksum_vld(ip_checksum_vld),
          .ip_new_checksum(ip_new_checksum),     // new checksum assuming decremented TTL
	  
	  .rd_ip_tcp(rd_ip_tcp),
          .reset(~axis_resetn),
          .clk(axis_aclk)
      );


*/

/*
   ip_checksum_check
    #(.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH))
    ip_out_checksum

    ( //--- datapath interface



	 .tdata			    (ip_tcp_out_tdata_buf),
	 .valid			    (ip_tcp_out_tvalid_buf),
	 .word_IP_DST_HI	    (ip_tcp_out_word_IP_DST_HI),
	 .word_IP_DST_LO	    (ip_tcp_out_word_IP_DST_LO),

         // --- interface to process
         .ip_checksum_vld           (ip_checksum_vld),
         .ip_new_checksum           (ip_new_checksum),     // new checksum assuming decremented TTL
         .rd_ip_checksum               (rd_ip_tcp),

         // misc
         .reset                     (~axis_resetn),
         .clk                       (axis_aclk)
         );
*/

stock_id_mapping
     stock_id_mapping
       ( // --- Interface to the previous stage

         .tdata              (s_axis_tdata),
         .tkeep              (s_axis_tkeep),
         .tuser              (s_axis_tuser),
         .valid              (s_axis_tvalid),
         .tlast              (s_axis_tlast),



/*
	 .tdata		     (stock_id_mapping_in_tdata),
	 .tkeep		     (stock_id_mapping_in_tkeep),
	 .tuser		     (stock_id_mapping_in_tuser),
	 .valid		     (stock_id_mapping_in_tvalid),
	 .tlast		     (stock_id_mapping_in_tlast),
*/
        // .word_IP_DST_LO            (id_mapping_out_word_IP_DST_LO),

         // --- Interface to registers
         // --- Read port
        .stock_id_mapping_rd_addr       (stock_id_mapping_rd_addr),
        .stock_id_mapping_rd_req        (stock_id_mapping_rd_req),
        .stock_id_mapping_rd_data         (stock_id_mapping_rd_data),
        .stock_id_mapping_rd_ack        (stock_id_mapping_rd_ack),
         // --- Write port
        .stock_id_mapping_wr_addr       (stock_id_mapping_wr_addr),
        .stock_id_mapping_wr_req        (stock_id_mapping_wr_req),
        .stock_id_mapping_wr_data         (stock_id_mapping_wr_data),
        .stock_id_mapping_wr_ack        (stock_id_mapping_wr_ack),


        .parse_vld                      (parse_vld),
        .parse_rdy                      (parse_rdy),
        .in_fifo_rd_ci                  (warrants_fifo_rd),
        .warrants_index_out                     (warrants_index_out),
//      .in_fifo_rd                     (rd_preprocess_info),
//      .stock_code_out                 (stock_code_out),

        .order_vld                      (order_vld),
        .order_out                      (order_out),
        .in_fifo_rd_order               (order_rd),

        .sid_not_empty                  (sid_not_empty),
         // --- Misc
         .reset                    (~axis_resetn),
         .clk                      (axis_aclk)
         );



warrants_id_mapping
        warrants_id_mapping
       (
         // --- Interface to registers
         // --- Read port
        .warrants_id_mapping_rd_addr       (warrants_id_mapping_rd_addr),
        .warrants_id_mapping_rd_req        (warrants_id_mapping_rd_req),
        .warrants_id_mapping_rd_data       (warrants_id_mapping_rd_data),
        .warrants_id_mapping_rd_ack        (warrants_id_mapping_rd_ack),
         // --- Write port
        .warrants_id_mapping_wr_addr       (warrants_id_mapping_wr_addr),
        .warrants_id_mapping_wr_req        (warrants_id_mapping_wr_req),
        .warrants_id_mapping_wr_data       (warrants_id_mapping_wr_data),
        .warrants_id_mapping_wr_ack        (warrants_id_mapping_wr_ack),

        .parse_vld                      (parse_vld),
        .warrants_fifo_rd                       (warrants_fifo_rd),
        .warrants_index_out                     (warrants_index_out),
        .order_index_out                        (order_index_out),
//      .commodity_id_mapping_vld           (commodity_id_mapping_vld),
        .in_fifo_rd             (rd_preprocess_info),
        .parse_order_vld                        (parse_order_vld),
        .parse_order_rdy                        (parse_order_rdy),

        // --- Read port
        .order_id_mapping_rd_addr       (order_id_mapping_rd_addr),
        .order_id_mapping_rd_req        (order_id_mapping_rd_req),
        .order_id_mapping_rd_data       (order_id_mapping_rd_data),
        .order_id_mapping_rd_ack        (order_id_mapping_rd_ack),
         // --- Write port
        .order_id_mapping_wr_addr       (order_id_mapping_wr_addr),
        .order_id_mapping_wr_req        (order_id_mapping_wr_req),
        .order_id_mapping_wr_data       (order_id_mapping_wr_data),
        .order_id_mapping_wr_ack        (order_id_mapping_wr_ack),

        // --- order content
        .order_vld                      (order_vld),
        .order_out                      (order_out),
        .order_rd                       (order_rd),

        .cid_not_empty                  (cid_not_empty),
         // --- Misc
         .reset                    (~axis_resetn),
         .clk                      (axis_aclk)
         );

/*
  always @(*) begin
        fix_seq_num_in_tvalid_next = 0;
        fix_seq_num_in_tlast_next  = 0;
        fix_seq_num_in_tdata_next  = 0;
        fix_seq_num_in_tuser_next  = 0;
        fix_seq_num_in_keep_next   = 0;
        state_next = state;

        if(!seq_num_out_fifo_empty&&)begin //priorty encoder
        end
        else if()begin
        end



        case(state)
        endcase
  end


   always @(posedge clk) begin
      if(reset) begin
         state             <= WAIT_PREPROCESS_RDY;
         fix_seq_num_in_tvalid        <= 0;
         fix_seq_num_in_tdata         <= 0;
         fix_seq_num_in_tuser         <= 0;
         fix_seq_num_in_keep          <= 0;
         fix_seq_num_in_tlast         <= 0;

      end
      else begin
         state             <= state_next;
         fix_seq_num_in_tvalid        <= fix_seq_num_in_tvalid_next;
         fix_seq_num_in_tlast         <= fix_seq_num_in_tlast_next;
         fix_seq_num_in_tdata         <= fix_seq_num_in_tdata_next;
         fix_seq_num_in_tuser         <= fix_seq_num_in_tuser_next;
         fix_seq_num_in_keep          <= fix_seq_num_in_keep_next;


      end // else: !if(reset)
   end // always @ (posedge clk)

*/


endmodule // decision_executor

