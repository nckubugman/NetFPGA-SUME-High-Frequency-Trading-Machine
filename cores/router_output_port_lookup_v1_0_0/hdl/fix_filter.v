///////////////////////////////////////////////////////////////////////////////
// $Id: fix_filter.v 5089 2009-02-23 02:14:38Z grg $
//
// Module: fix_filter.v
// Project: NF2.1
// Description: Detect the fix packet
//              
//
///////////////////////////////////////////////////////////////////////////////

  module fix_filter
    #(C_S_AXIS_DATA_WIDTH     = 256
      )

    (
     input [C_S_AXIS_DATA_WIDTH-1:0]        tdata,
     input [C_S_AXIS_DATA_WIDTH/8-1:0]	    tkeep,
     input			            valid,
     input			            tlast,
     input			            rd_check,
   
     output			   fix_filter_vld, 
    // output			   is_fix_order,
     output			   is_fix,
     output                        is_logon,
     output                        is_report,
     output                        is_resend,

     output			   is_heartbeat,
     output			   is_testReq,
     output			   is_logout,   
     output			   is_fix_order,
     output			   is_session_reject,
     output			   is_order_cancel_reject,
 
//     output reg [31:0]             recv_fix_server_seq, // parse recieve fix server sequence number
     output reg [31:0]             resend_begin,
     output reg [31:0]		   resend_end,
     output reg [31:0]             resend_num,
     //output reg                    resend_req,  
     input                         resend_ack,

     output reg 		   resend_mode_one,
     output reg			   resend_mode_two,
     output reg			   resend_mode_three,

     //output reg	[31:0]		   ip2cpu_fix_logout_trigger_reg,
//     output reg			   fix_logout_signal,
//	output reg			   fix_logout_trigger,
//     output reg [31:0]	          
     output reg [31:0]		   resend_begin_fix_seq_num,
     output reg [31:0]		   resend_end_fix_seq_num,

     input                         reset,
     input                         clk
    );

// --- flag
     reg [2:0]			   counter;
     reg			   tcp_pkt;
     reg			   fix_pkt;
//     reg			   order_pkt;
     reg			   check_done;
     reg                           logon_pkt;
     reg                           report_pkt;
     reg                           resend_pkt;
     reg			   heartbeat_pkt;
     reg			   testrequest_pkt;
     reg			   logout_pkt;   
     reg			   session_reject_pkt;
     reg			   order_cancel_reject_pkt;	   
     reg			   order_pkt;

     reg                           end_state;
  

     wire			   empty;

     reg			   resend_end_check_one;
     reg			   resend_end_check_two;
     reg			   resend_non_dup;

     reg [255:0]		   resend_pkt_tdata;
     reg [255:0]	           resend_pkt_tdata_two;

     reg [3:0]			   resend_posi;
     reg [7:0]			   resend_mux;
     reg 			   resend_cal_delay_one;
     reg			   resend_cal_delay_two;
     reg			   resend_cal_delay_three;

     reg [7:0]			   resend_begin_add_reg_t2;
     reg [7:0]			   resend_begin_add_reg_t3;
     reg [7:0]			   resend_begin_add_reg_t4;
     reg [7:0]			   resend_begin_add_reg_t5;
     reg [7:0]			   resend_begin_add_reg_t6;
     reg [7:0]			   resend_begin_add_reg_t7;
     reg [7:0]                     resend_begin_add_reg_t8;
     reg [7:0]                     resend_begin_add_reg_t9;
     reg [11:0]                     resend_begin_add_reg_t10;
     reg [11:0]                     resend_begin_add_reg_t11;
     reg [11:0]                     resend_begin_add_reg_t12;
     reg [11:0]                     resend_begin_add_reg_t13;
     reg [11:0]                     resend_begin_add_reg_t14;
     reg [11:0]                     resend_begin_add_reg_t15;
     reg [11:0]                     resend_begin_add_reg_t16;
     reg [11:0]                     resend_begin_add_reg_t17;

     reg [7:0]			   resend_end_add_reg_t1;
     reg [7:0]                     resend_end_add_reg_t2;
     reg [7:0]                     resend_end_add_reg_t3;
     reg [7:0]                     resend_end_add_reg_t4;
     reg [7:0]                     resend_end_add_reg_t5;
     reg [7:0]                     resend_end_add_reg_t6;
     reg [7:0]                     resend_end_add_reg_t7;
     reg [7:0]                     resend_end_add_reg_t8;
     reg [7:0]                     resend_end_add_reg_t9;
     reg [7:0]                     resend_end_add_reg_t10;
     reg [7:0]                     resend_end_add_reg_t11;
     reg [7:0]                     resend_end_add_reg_t12;

     reg [11:0]                     resend_end_add_reg_t17;
     reg [11:0]                     resend_end_add_reg_t18;
     reg [11:0]                     resend_end_add_reg_t19;
     reg [11:0]                     resend_end_add_reg_t20;
     reg [11:0]                     resend_end_add_reg_t21;
     reg [11:0]                     resend_end_add_reg_t22;
     reg [11:0]                     resend_end_add_reg_t23;
     reg [11:0]                     resend_end_add_reg_t24;
     
     reg 			    resend_mode_one_reg;
     reg			    resend_mode_two_reg;
     reg			    resend_mode_three_reg;

     reg			    resend_num_wr;
/*
     reg [7:0]			   resend_end_add_reg_one;
     reg [7:0]			   resend_end_add_reg_two;
     reg [11:0]                    resend_end_add_reg_three;
     reg [11:0]                    resend_end_add_reg_four;
*/


fallthrough_small_fifo #(.WIDTH(10), .MAX_DEPTH_BITS(9))
   check_tcp_fifo
   (.din               ({is_fix_pkt, logon_pkt, report_pkt , resend_pkt , heartbeat_pkt , testrequest_pkt , logout_pkt , fix_order_in , session_reject_pkt, order_cancel_reject_pkt}),
    .wr_en             (check_done),
    .rd_en             (rd_check),
    .dout              ({is_fix, is_logon, is_report, is_resend , is_heartbeat , is_testReq , is_logout,is_fix_order,is_session_reject,is_order_cancel_reject}),
    .full              (),
    .nearly_full       (),
    .prog_full         (),
    .empty             (empty),
    .reset             (reset),
    .clk               (clk)
   );

//----------------------- Logic --------------------------//
     assign    fix_filter_vld   = !empty;
     assign    fix_order_in = tcp_pkt & fix_pkt & order_pkt;
//     assign    fix_order_in = tcp_pkt & fix_pkt ;
     assign is_fix_pkt = tcp_pkt & fix_pkt;


/* check flag */
always @(posedge clk) begin
    if(reset) begin
	counter <= 3'b0;
	tcp_pkt <= 1'b0;
	fix_pkt <= 1'b0;
	//order_pkt <= 1'b0;
	check_done <= 1'b0;
        logon_pkt  <= 1'b0;
        report_pkt <= 1'b0;
        resend_pkt <= 1'b0;
	heartbeat_pkt <= 1'b0;
	testrequest_pkt<= 1'b0;
	logout_pkt <= 1'b0;
	order_pkt  <= 1'b0;
	session_reject_pkt <= 1'b0;
	order_cancel_reject_pkt<= 1'b0;
        //recv_fix_server_seq <= 'h0;
        resend_begin   <= 'h0;
	resend_end     <= 'h0;
	resend_end_check_one<=1'b0;
	resend_end_check_two<=1'b0;
        resend_non_dup <= 1'b1;
	//fix_logout_trigger <=1'b0;
	resend_posi <= 4'd0;
	resend_mux <= 8'd0;
	resend_pkt_tdata <= 0;
	resend_pkt_tdata_two <= 0;
	resend_cal_delay_one<=0;
	resend_cal_delay_two<=0;
	resend_cal_delay_three<=0;	
	resend_begin_add_reg_t2 <= 0;
	resend_begin_add_reg_t3 <= 0;
	resend_begin_add_reg_t4 <=0;
	resend_begin_add_reg_t5 <= 0;
        resend_begin_add_reg_t6 <= 0;
        resend_begin_add_reg_t7 <= 0;
        resend_begin_add_reg_t8 <=0;
        resend_begin_add_reg_t9 <= 0;
        resend_begin_add_reg_t10 <= 0;
        resend_begin_add_reg_t11 <= 0;
        resend_begin_add_reg_t12 <=0;
        resend_begin_add_reg_t13 <= 0;
        resend_begin_add_reg_t14 <= 0;
        resend_begin_add_reg_t15 <= 0;
        resend_begin_add_reg_t16 <=0;
        resend_begin_add_reg_t17 <= 0;

	resend_end_add_reg_t1 <= 0;
        resend_end_add_reg_t2 <= 0;
        resend_end_add_reg_t3 <= 0;
        resend_end_add_reg_t4 <=0;
        resend_end_add_reg_t5 <= 0;
        resend_end_add_reg_t6 <= 0;
        resend_end_add_reg_t7 <= 0;
        resend_end_add_reg_t8 <=0;
        resend_end_add_reg_t9 <= 0;
        resend_end_add_reg_t10 <= 0;
        resend_end_add_reg_t11 <= 0;
        resend_end_add_reg_t12 <=0;
        resend_end_add_reg_t17 <= 0;
        resend_end_add_reg_t18 <= 0;
        resend_end_add_reg_t19 <= 0;
        resend_end_add_reg_t20 <=0;
        resend_end_add_reg_t21 <= 0;
        resend_end_add_reg_t22 <= 0;
        resend_end_add_reg_t23 <=0;
        resend_end_add_reg_t24 <= 0;

	resend_mode_one_reg    <= 0;
	resend_mode_two_reg    <= 0;
	resend_num_wr	       <= 0;
//	resend_mode_three_reg  <= 0;

/*
	resend_end_add_reg_one <= 0;
	resend_end_add_reg_two <= 0;
	resend_end_add_reg_three <= 0;
	resend_end_add_reg_four  <= 0;
	resend_end_add_reg_five	 <= 0;
	resend_end_add_reg_six   <= 0;
*/
    end
    else begin
	if(valid) begin
		counter <= counter + 1'b1;
	end
	if(counter == 8'd0 && valid) begin
		if(tdata[71:64] == 8'h06) begin
			tcp_pkt <= 1'b1;
		end
	end
	if(counter == 8'd1 && tcp_pkt && valid) begin
		//fix_pkt <= 1'b1;
		//if(tdata[143:128] == 16'h8018 || tdata[143:128] == 16'h8019 ) begin
		//if(tdata[223:208]==16'he704 && (tdata[143:128]==16'h8018||tdata[143:128]==16'h8019))begin //Dst port
		if(tdata[223:208==16'he704])begin
			fix_pkt <= 1'b1;
		end
	end
        if(counter == 8'd2 && fix_pkt&&valid) begin
                if(tdata[119:80] == 40'h33353d3001) begin 
                        heartbeat_pkt <= 1'b1;
                end
                else if(tdata[119:80] == 40'h33353d3101) begin
                        testrequest_pkt <= 1'b1;
                end
                else if(tdata[119:80] == 40'h33353d3201) begin
                        resend_pkt <= 1'b1;
                end
		else if(tdata[119:80] == 40'h33353d3301) begin
			session_reject_pkt<= 1'b1;
		end
		else if(tdata[119:80] == 40'h33353d3501) begin
			logout_pkt  <= 1'b1;
			//fix_logout_trigger<= 1'b1;
		end
                else if(tdata[111:72] == 40'h33353d3801) begin
                        report_pkt <= 1'b1;
                end
		else if(tdata[111:72] == 40'h33353d3901) begin
			order_cancel_reject_pkt <= 1'b1;
		end
                else if(tdata[119:80] == 40'h33353d4101) begin
                        logon_pkt <= 1'b1;
                end

		else if(tdata[223:168]==56'h4649582e342e34 && tdata[87:80]==8'h44)begin
			order_pkt <= 1'b1;
		end
		

        end

	if(counter == 8'd4 && valid && resend_pkt)begin
		//resend_non_dup <= 1'b1;
                resend_pkt_tdata<= tdata;
		//resend_begin_add_reg_t1  <= {tdata[83:80],tdata[75,72]};
                resend_begin_add_reg_t2  <= {tdata[91:88],tdata[83:80]};
                resend_begin_add_reg_t3  <= {tdata[99:96],tdata[91:88]};
                resend_begin_add_reg_t4  <= {tdata[107:104],tdata[99:96]};
                resend_begin_add_reg_t5  <= {tdata[115:112],tdata[107:104]};
                resend_begin_add_reg_t6  <= {tdata[123:120],tdata[115:112]};
                resend_begin_add_reg_t7  <= {tdata[131:128],tdata[123:120]};
                resend_begin_add_reg_t8  <= {tdata[139:136],tdata[131:128]};
                resend_begin_add_reg_t9  <= {tdata[147:144],tdata[139:136]};
                resend_begin_add_reg_t10 <= {resend_begin_add_reg_t2 ,tdata[ 75: 72]};
                resend_begin_add_reg_t11 <= {resend_begin_add_reg_t3 ,tdata[ 83: 80]};
                resend_begin_add_reg_t12 <= {resend_begin_add_reg_t4 ,tdata[ 91: 88]};
                resend_begin_add_reg_t13 <= {resend_begin_add_reg_t5 ,tdata[ 99: 96]};
                resend_begin_add_reg_t14 <= {resend_begin_add_reg_t6 ,tdata[107:104]};
                resend_begin_add_reg_t15 <= {resend_begin_add_reg_t7 ,tdata[115:112]};
                resend_begin_add_reg_t16 <= {resend_begin_add_reg_t8 ,tdata[123:120]};
                resend_begin_add_reg_t17 <= {resend_begin_add_reg_t9 ,tdata[131:128]};
                
        	if(tdata[167:152] == 16'h373d)begin
			resend_posi <= 1;
			if(tdata[143:136] == 8'h01 ) begin
                                resend_begin <= {28'h0, tdata[147:144]};
				resend_mux   <= 1;
			end
			else if(tdata[135:128] == 8'h01) begin
                                resend_begin <= {24'h0,resend_begin_add_reg_t9};
				resend_mux   <= 2;
			end
			else if(tdata[127:120] == 8'h01 ) begin;
				resend_begin <= {20'h0,resend_begin_add_reg_t17};
				resend_mux   <= 3;
			end
			else if(tdata[119:112] == 8'h01 ) begin
                                resend_begin <= {16'h0,resend_begin_add_reg_t9,resend_begin_add_reg_t7};
				resend_mux   <= 4;
			end
			else if(tdata[111:104] == 8'h01 ) begin
        	                resend_begin <= {12'h0,resend_begin_add_reg_t17,resend_begin_add_reg_t6};
				resend_mux   <= 5;
			end
			else if(tdata[103:96] == 8'h01 ) begin
	                        resend_begin <= {8'h0,resend_begin_add_reg_t17 ,resend_begin_add_reg_t14};
				resend_mux   <= 6;
			end
		end
		else if(tdata[159:144] == 16'h373d)begin
			resend_posi <= 2;
			if(tdata[135:128]==8'h01)begin
				resend_begin <= {28'h0, tdata[139:136]};
				resend_mux   <= 7;
			end
			else if(tdata[127:120]==8'h01)begin
				resend_begin <= {24'h0, resend_begin_add_reg_t8};
				resend_mux   <= 8;
			end
			else if(tdata[119:112]==8'h01)begin
				resend_begin <= {20'h0,resend_begin_add_reg_t16};
				resend_mux   <= 9;
			end
			else if(tdata[111:104]==8'h01)begin
				resend_begin <= {16'h0,resend_begin_add_reg_t8,resend_begin_add_reg_t6};
				resend_mux   <= 10;
			end
			else if(tdata[103:96]==8'h01)begin
				resend_begin <= {12'h0,resend_begin_add_reg_t16,resend_begin_add_reg_t5};
				resend_mux   <= 11;
			end
			else if(tdata[95:88]==8'h01)begin
				resend_begin <= {8'h0,resend_begin_add_reg_t16,resend_begin_add_reg_t13};
				resend_mux   <= 12;
			end
		end
		else if(tdata[151:136] == 16'h373d)begin
			resend_posi <= 3;
                        if(tdata[127:120]==8'h01)begin
                                resend_begin <= {28'h0, tdata[131:128]};
				resend_mux   <= 13;
                        end
                        else if(tdata[119:112]==8'h01)begin
                                resend_begin <= {24'h0, resend_begin_add_reg_t7};
				resend_mux   <= 14;
                        end
                        else if(tdata[111:104]==8'h01)begin
                                resend_begin <= {20'h0,resend_begin_add_reg_t15};
				resend_mux   <= 15;
                        end
                        else if(tdata[103:96]==8'h01)begin
                                resend_begin <= {16'h0,resend_begin_add_reg_t7,resend_begin_add_reg_t5};
				resend_mux   <= 16;
                        end
                        else if(tdata[95:88]==8'h01)begin
                                resend_begin <= {12'h0,resend_begin_add_reg_t15,resend_begin_add_reg_t4};
				resend_mux   <= 17;
                        end
                        else if(tdata[87:80]==8'h01)begin
                                resend_begin <= {8'h0,resend_begin_add_reg_t15,resend_begin_add_reg_t12};
				resend_mux   <= 18;
                        end
		end
		else if(tdata[143:128] == 16'h373d)begin
			resend_posi <= 4;
                        if(tdata[119:112]==8'h01)begin
                                resend_begin <= {28'h0, tdata[123:120]};
				resend_mux   <= 19;
                        end
                        else if(tdata[111:104]==8'h01)begin
                                resend_begin <= {24'h0, resend_begin_add_reg_t6};
				resend_mux   <= 20;
                        end
                        else if(tdata[103:96]==8'h01)begin
                                resend_begin <= {20'h0, resend_begin_add_reg_t14};
				resend_mux   <= 21;
                        end
                        else if(tdata[95:88]==8'h01)begin
                                resend_begin <= {16'h0,resend_begin_add_reg_t6,resend_begin_add_reg_t4};
				resend_mux   <= 22;
                        end
                        else if(tdata[87:80]==8'h01)begin
                                resend_begin <= {12'h0,resend_begin_add_reg_t14,resend_begin_add_reg_t3};
				resend_mux   <= 23;
                        end
                        else if(tdata[79:72]==8'h01)begin
                                resend_begin <= {8'h0, resend_begin_add_reg_t14,resend_begin_add_reg_t11};
				resend_mux   <= 24;
                        end

		end
		else begin//if(tdata[135:120] == 16'h373d)begin
			resend_posi <= 5;
                        if(tdata[111:104]==8'h01)begin
                                resend_begin <= {28'h0, tdata[115:112]};
				resend_mux   <= 25;
                        end
                        else if(tdata[103:96]==8'h01)begin
                                resend_begin <= {24'h0, resend_begin_add_reg_t5};
				resend_mux   <= 26;
                        end
                        else if(tdata[95:88]==8'h01)begin
                                resend_begin <= {20'h0, resend_begin_add_reg_t13};
				resend_mux   <= 27;
                        end
                        else if(tdata[87:80]==8'h01)begin
                                resend_begin <= {16'h0, resend_begin_add_reg_t5,resend_begin_add_reg_t3};
				resend_mux   <= 28;
                        end
                        else if(tdata[79:72]==8'h01)begin
                                resend_begin <= {12'h0, resend_begin_add_reg_t13,resend_begin_add_reg_t2};
				resend_mux   <= 29;
                        end
                        else if(tdata[71:64]==8'h01)begin
                                resend_begin <= {8'h0, resend_begin_add_reg_t13,resend_begin_add_reg_t10};
				resend_mux   <= 30;
                        end

		end
	end

	if(counter == 8'd5 && valid  && resend_pkt)begin
		//resend_pkt_tdata_two<= tdata;
		resend_end_add_reg_t1  <= {resend_pkt_tdata[27:24],resend_pkt_tdata[19:16]};
		resend_end_add_reg_t2  <= {resend_pkt_tdata[35:32],resend_pkt_tdata[27:24]};
		resend_end_add_reg_t3  <= {resend_pkt_tdata[43:40],resend_pkt_tdata[35:32]};
		resend_end_add_reg_t4  <= {resend_pkt_tdata[51:48],resend_pkt_tdata[43:40]};
                resend_end_add_reg_t5  <= {resend_pkt_tdata[59:56],resend_pkt_tdata[51:48]};
                resend_end_add_reg_t6  <= {resend_pkt_tdata[67:64],resend_pkt_tdata[59:56]};
                resend_end_add_reg_t7  <= {resend_pkt_tdata[75:72],resend_pkt_tdata[67:64]};
                resend_end_add_reg_t8  <= {resend_pkt_tdata[83:80],resend_pkt_tdata[75:72]};
                resend_end_add_reg_t9  <= {resend_pkt_tdata[91:88],resend_pkt_tdata[83:80]};
                resend_end_add_reg_t10 <= {resend_pkt_tdata[99:96],resend_pkt_tdata[91:88]};
                resend_end_add_reg_t11 <= {resend_pkt_tdata[107:104],resend_pkt_tdata[99:96]};
                resend_end_add_reg_t12 <= {resend_pkt_tdata[115:112],resend_pkt_tdata[107:104]};
/*
                resend_end_add_reg_t13 <= {resend_end_add_reg_t1 ,resend_pkt_tdata[ 11:  8]};
                resend_end_add_reg_t14 <= {resend_end_add_reg_t2 ,resend_pkt_tdata[ 19: 16]};
                resend_end_add_reg_t15 <= {resend_end_add_reg_t3 ,resend_pkt_tdata[ 27: 24]};
                resend_end_add_reg_t16 <= {resend_end_add_reg_t4 ,resend_pkt_tdata[ 35: 32]};
*/
                resend_end_add_reg_t17 <= {resend_end_add_reg_t5 ,resend_pkt_tdata[ 43: 40]};
                resend_end_add_reg_t18 <= {resend_end_add_reg_t6 ,resend_pkt_tdata[ 51: 48]};
                resend_end_add_reg_t19 <= {resend_end_add_reg_t7 ,resend_pkt_tdata[ 59: 56]};
                resend_end_add_reg_t20 <= {resend_end_add_reg_t8 ,resend_pkt_tdata[ 67: 64]};
                resend_end_add_reg_t21 <= {resend_end_add_reg_t9 ,resend_pkt_tdata[ 75: 72]};
                resend_end_add_reg_t22 <= {resend_end_add_reg_t10,resend_pkt_tdata[ 83: 80]};
                resend_end_add_reg_t23 <= {resend_end_add_reg_t11,resend_pkt_tdata[ 91: 88]};
                resend_end_add_reg_t24 <= {resend_end_add_reg_t12,resend_pkt_tdata[ 99: 96]};

		case(resend_mux)
			//--167:152
			8'd1 : begin
				if(resend_pkt_tdata[111:104]==8'h01)begin
					resend_mode_one_reg <= 1;
					resend_end <= {28'h0,resend_pkt_tdata[115:112]}; 
				end
				else if(resend_pkt_tdata[103:96]==8'h01)begin
					resend_mode_two_reg <= 1;
					resend_end <= {24'h0,resend_end_add_reg_t12};
				end
				else if(resend_pkt_tdata[95:88]==8'h01)begin
					resend_mode_two_reg <= 1;
					resend_end <= {20'h0,resend_end_add_reg_t24};
				end
				else if(resend_pkt_tdata[87:80]==8'h01)begin
					resend_mode_two_reg <= 1;
					resend_end <= {16'h0,resend_end_add_reg_t12,resend_end_add_reg_t10};
				end
				else if(resend_pkt_tdata[79:72]==8'h01)begin
					resend_mode_two_reg <= 1;
					resend_end <= {12'h0,resend_end_add_reg_t24,resend_end_add_reg_t9};
				end
				else if(resend_pkt_tdata[71:64]==8'h01)begin
					resend_mode_two_reg <= 1;
					resend_end <= {8'h0,resend_end_add_reg_t24,resend_end_add_reg_t21};
				end
			end
			8'd2 : begin
                                if(resend_pkt_tdata[103:96]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {24'h0,resend_end_add_reg_t12};
                                end
                                else if(resend_pkt_tdata[95:88]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t24};
                                end
                                else if(resend_pkt_tdata[87:80]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t12,resend_end_add_reg_t10};
                                end
                                else if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t24,resend_end_add_reg_t9};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0, resend_end_add_reg_t24,resend_end_add_reg_t21};
                                end
			end
			8'd3 : begin
                                if(resend_pkt_tdata[95:88]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t24};
                                end
                                else if(resend_pkt_tdata[87:80]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t12,resend_end_add_reg_t10};
                                end
                                else if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t24,resend_end_add_reg_t9};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t24,resend_end_add_reg_t21};
                                end
			end
			8'd4 : begin
                                if(resend_pkt_tdata[87:80]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t12,resend_end_add_reg_t10};
                                end
                                else if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t24,resend_end_add_reg_t9};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t24,resend_end_add_reg_t21};
                                end
			end
			8'd5 : begin
                                if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t24,resend_end_add_reg_t9};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0, resend_end_add_reg_t24,resend_end_add_reg_t21};
                                end

			end
                        8'd6 : begin
				if(resend_pkt_tdata[71:64]==8'h01)begin
					resend_mode_one_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t24,resend_end_add_reg_t21};
				end
                        end
			//159:144
                        8'd7 : begin
                                if(resend_pkt_tdata[103:96]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {28'h0,resend_pkt_tdata[107:104]};
                                end
                                else if(resend_pkt_tdata[95:88]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {24'h0,resend_end_add_reg_t11};
                                end
                                else if(resend_pkt_tdata[87:80]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t23};
                                end
                                else if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t11,resend_end_add_reg_t9};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
					resend_end <= {12'h0,resend_end_add_reg_t23,resend_end_add_reg_t8};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t23,resend_end_add_reg_t20};
                                end
                        end
                        8'd8 : begin
                                if(resend_pkt_tdata[95:88]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {24'h0,resend_end_add_reg_t11};
                                end
                                else if(resend_pkt_tdata[87:80]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t23};
                                end
                                else if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t11,resend_end_add_reg_t9};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t23,resend_end_add_reg_t8};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t23,resend_end_add_reg_t20};
                                end
                        end
                        8'd9 : begin
                                if(resend_pkt_tdata[87:80]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t23};
                                end
                                else if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t11,resend_end_add_reg_t9};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t23,resend_end_add_reg_t8};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t23,resend_end_add_reg_t20};
                                end
                        end
                        8'd10 : begin
                                if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t11,resend_end_add_reg_t9};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t23,resend_end_add_reg_t8};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t23,resend_end_add_reg_t20};
                                end
                        end
                        8'd11 : begin
                                if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t23,resend_end_add_reg_t8};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t23,resend_end_add_reg_t20};
                                end
                        end
			8'd12 : begin
				if(resend_pkt_tdata[63:56]==8'h01)begin 
					resend_mode_one_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t23,resend_end_add_reg_t20};
				end
			end
                        8'd13 : begin
                                if(resend_pkt_tdata[95:88]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {28'h0,resend_pkt_tdata[99:96]};
                                end
                                else if(resend_pkt_tdata[87:80]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {24'h0,resend_end_add_reg_t10};
                                end
                                else if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t22};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t10,resend_end_add_reg_t8};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t22,resend_end_add_reg_t7};
                                end
                                else if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t22,resend_end_add_reg_t19};
                                end
                        end
                        8'd14 : begin
                                if(resend_pkt_tdata[87:80]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {24'h0,resend_end_add_reg_t10};
                                end
                                else if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t22};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t10,resend_end_add_reg_t8};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t22,resend_end_add_reg_t7};
                                end
                                else if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t22,resend_end_add_reg_t19};
                                end
                        end
                        8'd15 : begin
                                if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t22};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t10,resend_end_add_reg_t8};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t22,resend_end_add_reg_t7};
                                end
                                else if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t22,resend_end_add_reg_t19};
                                end
                        end
                        8'd16 : begin
                                if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t10,resend_end_add_reg_t8};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t22,resend_end_add_reg_t7};
                                end
                                else if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t22,resend_end_add_reg_t19};
                                end
                        end
                        8'd17 : begin
                                if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t22,resend_end_add_reg_t7};
                                end
                                else if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t22,resend_end_add_reg_t19};
                                end
                        end
                        8'd18 : begin
				if(resend_pkt_tdata[55:48]==8'h01)begin
					resend_mode_one_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t22,resend_end_add_reg_t19};
				end
                        end
                        8'd19 : begin
                                if(resend_pkt_tdata[87:80]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {28'h0,resend_pkt_tdata[91:88]};
                                end
                                else if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {24'h0,resend_end_add_reg_t9};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t21};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t9,resend_end_add_reg_t7};
                                end
                                else if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t21,resend_end_add_reg_t6};
                                end
                                else if(resend_pkt_tdata[47:40]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t21,resend_end_add_reg_t18};
                                end
                        end
                        8'd20 : begin
                                if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {24'h0,resend_end_add_reg_t9};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t21};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t9,resend_end_add_reg_t7};
                                end
                                else if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t21,resend_end_add_reg_t6};
                                end
                                else if(resend_pkt_tdata[47:40]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t21,resend_end_add_reg_t18};
                                end

                        end
                        8'd21 : begin
                                if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t21};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t9,resend_end_add_reg_t7};
                                end
                                else if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t21,resend_end_add_reg_t6};
                                end
                                else if(resend_pkt_tdata[47:40]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t21,resend_end_add_reg_t18};
                                end

                        end
                        8'd22 : begin
                                if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t9,resend_end_add_reg_t7};
                                end
                                else if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t21,resend_end_add_reg_t6};
                                end
                                else if(resend_pkt_tdata[47:40]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t21,resend_end_add_reg_t18};
                                end

                        end
                        8'd23 : begin
                                if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t21,resend_end_add_reg_t6};
                                end
				//else if(tdata[255:248]==8'h01) begin
				else if(resend_pkt_tdata[47:40]==8'h01)begin
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t21,resend_end_add_reg_t18};
				end
                        end
                        8'd24 : begin
				//if(tdata[247:240]==8'h01)begin
				if(resend_pkt_tdata[47:40]==8'h01)begin
					resend_mode_one_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t21,resend_end_add_reg_t18};
				end
                        end
                        8'd25 : begin
                                if(resend_pkt_tdata[79:72]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {28'h0,resend_pkt_tdata[83:80]};
                                end
                                else if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {24'h0,resend_end_add_reg_t8};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t20};
                                end
                                else if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t8,resend_end_add_reg_t6};
                                end
                                else if(resend_pkt_tdata[47:40]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t20,resend_end_add_reg_t5};
                                end
                                else if(resend_pkt_tdata[39:32]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t20,resend_end_add_reg_t17};
                                end
                        end
                        8'd26 : begin
                                if(resend_pkt_tdata[71:64]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {24'h0,resend_end_add_reg_t8};
                                end
                                else if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t20};
                                end
                                else if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t8,resend_end_add_reg_t6};
                                end
                                else if(resend_pkt_tdata[47:40]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t20,resend_end_add_reg_t5};
                                end
                                else if(resend_pkt_tdata[39:32]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t20,resend_end_add_reg_t17};
                                end

      

                        end
                        8'd27 : begin
                                if(resend_pkt_tdata[63:56]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {20'h0,resend_end_add_reg_t20};
                                end
                                else if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t8,resend_end_add_reg_t6};
                                end
                                else if(resend_pkt_tdata[47:40]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t20,resend_end_add_reg_t5};
                                end
                                else if(resend_pkt_tdata[39:32]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t20,resend_end_add_reg_t17};
                                end

                        end
                        8'd28 : begin
                                if(resend_pkt_tdata[55:48]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {16'h0,resend_end_add_reg_t8,resend_end_add_reg_t6};
                                end
                                else if(resend_pkt_tdata[47:40]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t20,resend_end_add_reg_t5};
                                end
                                //else if(tdata[255:248]==8'h01)begin
                                else if(resend_pkt_tdata[39:32]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t20,resend_end_add_reg_t17};
                                end
                           
                        end
                        8'd29 : begin
                                if(resend_pkt_tdata[47:40]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {12'h0,resend_end_add_reg_t20,resend_end_add_reg_t5};
                                end
				//else if(tdata[247:240]==8'h01)begin
                                else if(resend_pkt_tdata[39:32]==8'h01)begin //resend_end
					resend_mode_two_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t20,resend_end_add_reg_t17};
				end

                        end
                        8'd30 : begin
				//if(tdata[239:232]==8'h01)begin
                                if(resend_pkt_tdata[39:32]==8'h01)begin //resend_end
					resend_mode_one_reg <= 1;
                                        resend_end <= {8'h0,resend_end_add_reg_t20,resend_end_add_reg_t17};
				end
                        end

	     endcase
	     resend_cal_delay_two<= 1 ;
	     resend_num_wr <= 1;
	end
	if(resend_num_wr)begin
                resend_begin_fix_seq_num <= resend_begin ;
                resend_end_fix_seq_num   <= resend_end;
                resend_mode_two          <= resend_mode_two_reg;
                if(resend_end==0&&resend_mode_one_reg)begin
                        resend_mode_three <=resend_mode_one_reg;
                        resend_mode_one   <= 0;
                end
                else begin
                        resend_mode_one  <= resend_mode_one_reg;
                        resend_mode_three <= 0;
                end
	end
       if(tlast && valid ) begin
/*
                resend_begin_fix_seq_num <= resend_begin ;
                resend_end_fix_seq_num   <= resend_end;
		resend_mode_two 	 <= resend_mode_two_reg;
		if(resend_end==0&&resend_mode_one_reg)begin
			resend_mode_three <=resend_mode_one_reg;
			resend_mode_one   <= 0;
		end
		else begin
			resend_mode_one  <= resend_mode_one_reg;
			resend_mode_three <= 0;
		end
*/
		check_done <= 1'b1;
		end_state  <= 1'b1;
       end 
       if(end_state) begin
                check_done <= 1'b0;
                fix_pkt    <= 1'b0;
                logon_pkt <= 1'b0;
                report_pkt <= 1'b0;
                resend_pkt <= 1'b0;
		heartbeat_pkt <= 1'b0;
		testrequest_pkt <= 1'b0; 
		logout_pkt <= 1'b0;
		order_pkt  <= 1'b0;
		session_reject_pkt <= 1'b0;
		order_cancel_reject_pkt <= 1'b0;
                counter    <= 3'b0;
		resend_end_check_one <=1'b0;
		resend_end_check_two <=1'b0;
		//fix_logout_signal<=1'b0;
		//fix_logout_trigger <=1'b0;
		resend_non_dup <= 1'b0;
                end_state        <= 1'b0;
		resend_mux    <= 0;
		resend_pkt_tdata <= 0;
		resend_pkt_tdata_two<=0;
		resend_cal_delay_one<=0;
		resend_cal_delay_two<=0;
		resend_cal_delay_three<=0;
	        resend_begin_add_reg_t2 <= 0;
	        resend_begin_add_reg_t3 <= 0;
	        resend_begin_add_reg_t4 <=0;
	        resend_begin_add_reg_t5 <= 0;
	        resend_begin_add_reg_t6 <= 0;
	        resend_begin_add_reg_t7 <= 0;
	        resend_begin_add_reg_t8 <=0;
	        resend_begin_add_reg_t9 <= 0;
	        resend_begin_add_reg_t10 <= 0;
	        resend_begin_add_reg_t11 <= 0;
	       	resend_begin_add_reg_t12 <=0;
	        resend_begin_add_reg_t13 <= 0;
	        resend_begin_add_reg_t14 <= 0;
	        resend_begin_add_reg_t15 <= 0;
	        resend_begin_add_reg_t16 <=0;
	        resend_begin_add_reg_t17 <= 0;
        	
		resend_end_add_reg_t1 <= 0;
       		resend_end_add_reg_t2 <= 0;
       		resend_end_add_reg_t3 <= 0;
	        resend_end_add_reg_t4 <=0;
	        resend_end_add_reg_t5 <= 0;
	        resend_end_add_reg_t6 <= 0;
	        resend_end_add_reg_t7 <= 0;
	        resend_end_add_reg_t8 <=0;
	        resend_end_add_reg_t9 <= 0;
	        resend_end_add_reg_t10 <= 0;
	        resend_end_add_reg_t11 <= 0;
	        resend_end_add_reg_t12 <=0;
	        resend_end_add_reg_t17 <= 0;
	        resend_end_add_reg_t18 <= 0;
	        resend_end_add_reg_t19 <= 0;
	        resend_end_add_reg_t20 <=0;
	        resend_end_add_reg_t21 <= 0;
	        resend_end_add_reg_t22 <= 0;
	        resend_end_add_reg_t23 <=0;
	        resend_end_add_reg_t24 <= 0;
	
		resend_mode_one_reg    <= 0;
		resend_mode_two_reg    <= 0;		
		resend_num_wr 	       <= 0;
/*
		resend_end_add_reg_one<=0;
		resend_end_add_reg_two<=0;
		resend_end_add_reg_three<=0;
		resend_end_add_reg_four<=0;
*/
        end

	if(resend_ack)begin
		resend_mode_one <= 0;
		resend_mode_two <= 0;
		resend_mode_three <= 0;
	end


    end
end

/*
always @(posedge clk) begin
        if(reset) begin
                //resend_req <= 'b0;
		resend_mode_one<= 'b0;
		resend_mode_two<= 'b0;
		resend_mode_three<='b0;
                //resend_num <= 'h0;
        end
        else begin
	    if(resend_pkt&&tlast&&valid)begin	
                resend_begin_fix_seq_num <= resend_begin ;
                resend_end_fix_seq_num   <= resend_end;	
	        if(resend_end=='b0)begin //end =0
			resend_mode_three <='b1;
*/
/*
			resend_begin_fix_seq_num[3:0] <= resend_begin[3:0];
			resend_begin_fix_seq_num[7:4] <= resend_begin[7:4];
			resend_begin_fix_seq_num[11:8]<= resend_begin[11:8];
			resend_begin_fix_seq_num[15:12]<= resend_begin[15:12];
			resend_begin_fix_seq_num[19:16]<= resend_begin[19:16];
			resend_begin_fix_seq_num[23:20]<= resend_begin[23:20];
			resend_begin_fix_seq_num[27:24]<= resend_begin[27:24];
			resend_begin_fix_seq_num[31:28]<= resend_begin[31:28];


                        resend_end_fix_seq_num[3:0] <= resend_end[3:0];
                        resend_end_fix_seq_num[7:4] <= resend_end[7:4];
                        resend_end_fix_seq_num[11:8]<= resend_end[11:8];
                        resend_end_fix_seq_num[15:12]<= resend_end[15:12];
                        resend_end_fix_seq_num[19:16]<= resend_end[19:16];
                        resend_end_fix_seq_num[23:20]<= resend_end[23:20];
                        resend_end_fix_seq_num[27:24]<= resend_end[27:24];
                        resend_end_fix_seq_num[31:28]<= resend_end[31:28];
*/			
/*			
	        end
        	else begin
                	if(resend_begin<resend_end)begin //begin < end
				resend_mode_two<='b1;
*/
/*
                	        resend_begin_fix_seq_num[3:0] <= resend_begin[3:0];
                	        resend_begin_fix_seq_num[7:4] <= resend_begin[7:4];
       		                resend_begin_fix_seq_num[11:8]<= resend_begin[11:8];
       	                        resend_begin_fix_seq_num[15:12]<= resend_begin[15:12];
        	                resend_begin_fix_seq_num[19:16]<= resend_begin[19:16];
        	                resend_begin_fix_seq_num[23:20]<= resend_begin[23:20];
        	                resend_begin_fix_seq_num[27:24]<= resend_begin[27:24];
        	                resend_begin_fix_seq_num[31:28]<= resend_begin[31:28];


	                        resend_end_fix_seq_num[3:0] <= resend_end[3:0];
	                        resend_end_fix_seq_num[7:4] <= resend_end[7:4];
	                        resend_end_fix_seq_num[11:8]<= resend_end[11:8];
	                        resend_end_fix_seq_num[15:12]<= resend_end[15:12];
	                        resend_end_fix_seq_num[19:16]<= resend_end[19:16];
	                        resend_end_fix_seq_num[23:20]<= resend_end[23:20];
	                        resend_end_fix_seq_num[27:24]<= resend_end[27:24];
	                        resend_end_fix_seq_num[31:28]<= resend_end[31:28];
*/				
/*
                	end
                	else  begin // begin = end
				resend_mode_one<='b1;
*/
/*
                                resend_begin_fix_seq_num[3:0] <= resend_begin[3:0];
                                resend_begin_fix_seq_num[7:4] <= resend_begin[7:4];
                                resend_begin_fix_seq_num[11:8]<= resend_begin[11:8];
                                resend_begin_fix_seq_num[15:12]<= resend_begin[15:12];
                                resend_begin_fix_seq_num[19:16]<= resend_begin[19:16];
                                resend_begin_fix_seq_num[23:20]<= resend_begin[23:20];
                                resend_begin_fix_seq_num[27:24]<= resend_begin[27:24];
                                resend_begin_fix_seq_num[31:28]<= resend_begin[31:28];


                                resend_end_fix_seq_num[3:0] <= resend_end[3:0];
                                resend_end_fix_seq_num[7:4] <= resend_end[7:4];
                                resend_end_fix_seq_num[11:8]<= resend_end[11:8];
                                resend_end_fix_seq_num[15:12]<= resend_end[15:12];
                                resend_end_fix_seq_num[19:16]<= resend_end[19:16];
                                resend_end_fix_seq_num[23:20]<= resend_end[23:20];
                                resend_end_fix_seq_num[27:24]<= resend_end[27:24];
                                resend_end_fix_seq_num[31:28]<= resend_end[31:28];
*/
/*
                	end
        	end
	    end
	    if(resend_ack == 'b1)begin
		//resend_req <= 'b0;
		resend_mode_one<= 'b0;
		resend_mode_two<= 'b0;
		resend_mode_three<='b0;
	    end

       end
end
*/

endmodule
