///////////////////////////////////////////////////////////////////////////////

//
// Module: tcp_checksum.v
// Description: Cauculate new tcp checksum
//              
//              
//
///////////////////////////////////////////////////////////////////////////////

module tcp_checksum
  #(parameter C_S_AXIS_DATA_WIDTH=256)
  (
   //--- datapath interface
   input  [C_S_AXIS_DATA_WIDTH-1:0]   tdata,
   input  [C_S_AXIS_DATA_WIDTH/8-1:0] tkeep, //in_ctrl
   input                              tlast, 
   input                              valid, // in_wr

   //--- interface to preprocess
   input                              word_IP_DST_HI,
   input                              word_IP_DST_LO,
   // --- interface to process
 //  output                             tcp_checksum_vld,
 //  output                             tcp_checksum_is_good,
   output     [15:0]                  tcp_new_checksum,     // new checksum assuming decremented TTL
   input                              rd_tcp_checksum,
   //output 			                   rd_fix_for_tcp, 
   //input   [63:0]	                 fix_new_checksum_for_tcp,         
   //input   	  		                 is_fix_out_for_tcp,
   
   // misc
   input reset,
   input clk
   );


   //---------------------- Wires and regs---------------------------
   reg  [25:0]  checksum_word_0, checksum_word_1,checksum_word_2,checksum_word_3;
   reg  [25:0]  checksum_word_4, checksum_word_5,checksum_word_6,checksum_word_7;
   reg  [25:0]  cksm_sum_t1 , cksm_sum_t2; 
   reg  [25:0]  cksm_sum_t3 , cksm_sum_t4;
   reg  [25:0]  cksm_sum_t5 , cksm_sum_t6;
   reg  [25:0]  cksm_sum_t7 , cksm_sum_t8;
   reg  [25:0]  cksm_sum_0, cksm_sum_1, cksm_sum_2,cksm_sum_3,cksm_sum_4, cksm_sum_5,cksm_sum_6, cksm_sum_7;
   reg  [25:0]  cksm_sum_8, cksm_sum_9, cksm_sum_10,cksm_sum_11,cksm_sum_12, cksm_sum_13,cksm_sum_14, cksm_sum_15; 
   wire [25:0]  cksm_temp0,cksm_temp1,cksm_temp2,cksm_temp3,cksm_temp4,cksm_temp5,cksm_temp6,cksm_temp7;
   reg  [25:0]  cksm_sum_final_1 ,cksm_sum_final_2 ,cksm_sum_final_3;
   wire [25:0]  cksm_final;
   reg  [25:0]  checksum_final;
   //---------------------- Wires and regs---------------------------
   reg    checksum_done;
   wire   empty;
   reg  [7:0]  protocol;
   reg  [15:0] length; 
   reg    add_carry_1,add_carry_2,add_carry_3;
   reg [15:0]  ip_header_len;



   
   //------------------------- Modules-------------------------------

   fallthrough_small_fifo #(.WIDTH(16), .MAX_DEPTH_BITS(2))
      tcp_checksum_fifo
        (.din (&checksum_final[15:0]),
         .wr_en (checksum_done),             // Write enable
         .rd_en (rd_tcp_checksum),               // Read the next word
         .dout (tcp_new_checksum),
         .full (),
         .nearly_full (),
         .prog_full (),
         .empty (empty),
         .reset (reset),
         .clk (clk)
         );

   //------------------------- Logic -------------------------------
   assign tcp_checksum_vld = !empty;


   /* MUX the additions to save adder logic */
   assign cksm_temp0  = cksm_sum_0  + cksm_sum_1 + cksm_sum_t1;
   assign cksm_temp1 =  cksm_sum_2  + cksm_sum_3 + cksm_sum_t2;
   assign cksm_temp2 =  cksm_sum_4  + cksm_sum_5 + cksm_sum_t3; 
   assign cksm_temp3 =  cksm_sum_6  + cksm_sum_7 + cksm_sum_t4;
   assign cksm_temp4 =  cksm_sum_8  + cksm_sum_9 + cksm_sum_t5;
   assign cksm_temp5 =  cksm_sum_10 + cksm_sum_11+ cksm_sum_t6;
   assign cksm_temp6 =  cksm_sum_12 + cksm_sum_13+ cksm_sum_t7;
   assign cksm_temp7 =  cksm_sum_14 + cksm_sum_15+ cksm_sum_t8;
   assign cksm_final =  cksm_sum_final_1 + cksm_sum_final_2 + cksm_sum_final_3 ;



   always @(*) begin
       cksm_sum_0  = {10'h0,tdata[255:240]};
      cksm_sum_1  = {10'h0,tdata[239:224]};
      cksm_sum_t1 = checksum_word_0;
      cksm_sum_2  = {10'h0,tdata[223:208]};
      cksm_sum_3  = {10'h0,tdata[207:192]};
      cksm_sum_t2 = checksum_word_1; 
      cksm_sum_4  = {10'h0,tdata[191:176]};
      cksm_sum_5  = {10'h0,tdata[175:160]};
      cksm_sum_t3 = checksum_word_2;
      cksm_sum_6  = {10'h0,tdata[159:144]};
      cksm_sum_7  = {10'h0,tdata[143:128]};
      cksm_sum_t4 = checksum_word_3;         
      cksm_sum_8  = {10'h0,tdata[127:112]};
      cksm_sum_9  = {10'h0,tdata[111:96]};
      cksm_sum_t5 = checksum_word_4;
      cksm_sum_10 = {10'h0,tdata[95:80]};
      cksm_sum_11 = {10'h0,tdata[79:64]};
      cksm_sum_t6 = checksum_word_5;
      cksm_sum_12 = {10'h0,tdata[63:48]};
      cksm_sum_13 = {10'h0,tdata[47:32]};
      cksm_sum_t7 = checksum_word_6;
      cksm_sum_14 = {10'h0,tdata[31:16]};
      cksm_sum_15 = {10'h0,tdata[15:0]};
      cksm_sum_t8 = checksum_word_7;

      cksm_sum_final_1 = 'h0;
      cksm_sum_final_2 = 'h0;
      cksm_sum_final_3 = 'h0;

      if(tkeep!=32'hFFFFFFFF) begin //tkeep[index] == 1'h ==4'b each bits-> to each bytes in tdata
    	  	  if(tkeep[3:0]!=4'hF)begin
    	  	  	   	case(tkeep[3:0])
				4'b1110: begin
					cksm_sum_14 = {10'h0, tdata[31:16]};
					cksm_sum_15 = {10'h0, tdata[15:8], 8'h0};
				end
				4'b1100: begin
					//chsm_sum_14 = {10'h0, tdata[31:16]};
					cksm_sum_15 = 26'h0;
				end
				4'b1000: begin
					cksm_sum_14 = {10'h0, tdata[31:24], 8'h0};
					cksm_sum_15 = 26'h0;
				end
				4'b0000: begin
					cksm_sum_14 = 26'h0;
					cksm_sum_15 = 26'h0;
				end
    	  	  	   	/*  4'b0001:  begin
    	  	  	   	  			cksm_sum_0 = {10'h0,tdata[255:248],8'h0};
    	              			cksm_sum_1 = 26'h0;
    	              			end 
    	              4'b0011: begin
    	              			cksm_sum_1 = 26'h0;
    	              		   end
    	              4'b0111: begin
    	              			cksm_sum_1 = {10'h0,tdata[239:232],8'h0};
    	              		   end
    	              4'b0000: begin
    	              			cksm_sum_0 = 26'h0;
    	              			cksm_sum_1 = 26'h0;
    	              		   end*/
    	          	endcase	          	

    	      end
    	      if(tkeep[7:4]!=4'hF)begin
    	  	  	   	case(tkeep[7:4])
				4'b1110: begin
					cksm_sum_12 = {10'h0, tdata[63:48]};
					cksm_sum_13 = {10'h0, tdata[47:40], 8'h0};
				end
				4'b1100: begin
					//chsm_sum_14 = {10'h0, tdata[31:16]};
					cksm_sum_13 = 26'h0;
				end
				4'b1000: begin
					cksm_sum_12 = {10'h0, tdata[63:56], 8'h0};
					cksm_sum_13 = 26'h0;
				end
				4'b0000: begin
					cksm_sum_12 = 26'h0;
					cksm_sum_13 = 26'h0;
				end
    	  	  	   	/*  4'b0001:  begin
    	  	  	   	  			cksm_sum_2 = {10'h0,tdata[223:216],8'h0};
    	              			cksm_sum_3 = 26'h0;
    	              			end 
    	              4'b0011: begin
    	              			cksm_sum_3 = 26'h0;
    	              		   end
    	              4'b0111: begin
    	              			cksm_sum_3 = {10'h0,tdata[207:200],8'h0};
    	              		   end
    	              4'b0000: begin
    	              			cksm_sum_2 = 26'h0;
    	              			cksm_sum_3 = 26'h0;
    	              		   end*/
    	          	endcase	          	
    	      end
    	      if(tkeep[11:8]!=4'hF)begin
    	  	  	   	case(tkeep[11:8])
				4'b1110: begin
					cksm_sum_10 = {10'h0, tdata[95:80]};
					cksm_sum_11 = {10'h0, tdata[79:72], 8'h0};
				end
				4'b1100: begin
					//chsm_sum_14 = {10'h0, tdata[31:16]};
					cksm_sum_11 = 26'h0;
				end
				4'b1000: begin
					cksm_sum_10 = {10'h0, tdata[95:88], 8'h0};
					cksm_sum_11 = 26'h0;
				end
				4'b0000: begin
					cksm_sum_10 = 26'h0;
					cksm_sum_11 = 26'h0;
				end
    	  	  	   	/*  4'b0001:  begin
    	  	  	   	  			cksm_sum_4 = {10'h0,tdata[191:184],8'h0};
    	              			cksm_sum_5 = 26'h0;
    	              			end 
    	              4'b0011: begin
    	              			cksm_sum_5 = 26'h0;
    	              		   end
    	              4'b0111: begin
    	              			cksm_sum_5 = {10'h0,tdata[175:168],8'h0};
    	              		   end
    	              4'b0000: begin
    	              			cksm_sum_4 = 26'h0;
    	              			cksm_sum_5 = 26'h0;
    	              		   end*/
    	          	endcase	          	
    	      end
    	      if(tkeep[15:12]!=4'hF)begin
    	  	  	   	case(tkeep[15:12])
				4'b1110: begin
					cksm_sum_8 = {10'h0, tdata[127:112]};
					cksm_sum_9 = {10'h0, tdata[111:104], 8'h0};
				end
				4'b1100: begin
					//chsm_sum_14 = {10'h0, tdata[31:16]};
					cksm_sum_9 = 26'h0;
				end
				4'b1000: begin
					cksm_sum_8 = {10'h0, tdata[127:120], 8'h0};
					cksm_sum_9 = 26'h0;
				end
				4'b0000: begin
					cksm_sum_8 = 26'h0;
					cksm_sum_9 = 26'h0;
				end
    	  	  	   	/*  4'b0001:  begin
    	  	  	   	  			cksm_sum_6 = {10'h0,tdata[159:152],8'h0};
    	              			cksm_sum_7 = 26'h0;
    	              			end 
    	              4'b0011: begin
    	              			cksm_sum_7 = 26'h0;
    	              		   end
    	              4'b0111: begin
    	              			cksm_sum_7 = {10'h0,tdata[143:136],8'h0};
    	              		   end
    	              4'b0000: begin
    	              			cksm_sum_6 = 26'h0;
    	              			cksm_sum_7 = 26'h0;
    	              		   end*/
    	          	endcase	          	
    	      end
    	      if(tkeep[19:16]!=4'hF)begin
    	  	  	   	case(tkeep[19:16])
				4'b1110: begin
					cksm_sum_6 = {10'h0, tdata[159:144]};
					cksm_sum_7 = {10'h0, tdata[143:136], 8'h0};
				end
				4'b1100: begin
					//chsm_sum_14 = {10'h0, tdata[31:16]};
					cksm_sum_7 = 26'h0;
				end
				4'b1000: begin
					cksm_sum_6 = {10'h0, tdata[159:152], 8'h0};
					cksm_sum_7 = 26'h0;
				end
				4'b0000: begin
					cksm_sum_6 = 26'h0;
					cksm_sum_7 = 26'h0;
				end
    	  	  	   	/*  4'b0001:  begin
    	  	  	   	  			cksm_sum_8 = {10'h0,tdata[127:120],8'h0};
    	              			cksm_sum_9 = 26'h0;
    	              			end 
    	              4'b0011: begin
    	              			cksm_sum_9 = 26'h0;
    	              		   end
    	              4'b0111: begin
    	              			cksm_sum_9 = {10'h0,tdata[111:104],8'h0};
    	              		   end
    	              4'b0000: begin
    	              			cksm_sum_8 = 26'h0;
    	              			cksm_sum_9 = 26'h0;
    	              		   end*/
    	          	endcase	          	
    	      end
    	      if(tkeep[23:20]!=4'hF)begin
    	  	  	   	case(tkeep[23:20])
				4'b1110: begin
					cksm_sum_4 = {10'h0, tdata[191:176]};
					cksm_sum_5 = {10'h0, tdata[175:168], 8'h0};
				end
				4'b1100: begin
					//chsm_sum_14 = {10'h0, tdata[31:16]};
					cksm_sum_5 = 26'h0;
				end
				4'b1000: begin
					cksm_sum_4 = {10'h0, tdata[191:184], 8'h0};
					cksm_sum_5 = 26'h0;
				end
				4'b0000: begin
					cksm_sum_4 = 26'h0;
					cksm_sum_5 = 26'h0;
				end
    	  	  	   	/*  4'b0001:  begin
    	  	  	   	  			cksm_sum_10 = {10'h0,tdata[95:88],8'h0};
    	              			cksm_sum_11 = 26'h0;
    	              			end 
    	              4'b0011: begin
    	              			cksm_sum_11 = 26'h0;
    	              		   end
    	              4'b0111: begin
    	              			cksm_sum_11 = {10'h0,tdata[79:72],8'h0};
    	              		   end
    	              4'b0000: begin
    	              			cksm_sum_10 = 26'h0;
    	              			cksm_sum_11 = 26'h0;
    	              		   end*/
    	          	endcase	          	
    	      end
    	      if(tkeep[27:24]!=4'hF)begin
    	  	  	   	case(tkeep[27:24])
				4'b1110: begin
					cksm_sum_2 = {10'h0, tdata[223:208]};
					cksm_sum_3 = {10'h0, tdata[207:200], 8'h0};
				end
				4'b1100: begin
					//chsm_sum_14 = {10'h0, tdata[31:16]};
					cksm_sum_3 = 26'h0;
				end
				4'b1000: begin
					cksm_sum_2 = {10'h0, tdata[223:216], 8'h0};
					cksm_sum_3 = 26'h0;
				end
				4'b0000: begin
					cksm_sum_2 = 26'h0;
					cksm_sum_3 = 26'h0;
				end
    	  	  	   	/*  4'b0001:  begin
    	  	  	   	  			cksm_sum_12 = {10'h0,tdata[63:56],8'h0};
    	              			cksm_sum_13 = 26'h0;
    	              			end 
    	              4'b0011: begin
    	              			cksm_sum_13 = 26'h0;
    	              		   end
    	              4'b0111: begin
    	              			cksm_sum_13 = {10'h0,tdata[47:40],8'h0};
    	              		   end
    	              4'b0000: begin
    	              			cksm_sum_12 = 26'h0;
    	              			cksm_sum_13 = 26'h0;
    	              		   end*/
    	          	endcase	          	
    	      end
    	      if(tkeep[31:28]!=4'hF)begin
    	  	  	   	case(tkeep[31:28])
				4'b1110: begin
					cksm_sum_0 = {10'h0, tdata[255:240]};
					cksm_sum_1 = {10'h0, tdata[239:232], 8'h0};
				end
				4'b1100: begin
					//chsm_sum_14 = {10'h0, tdata[31:16]};
					cksm_sum_1 = 26'h0;
				end
				4'b1000: begin
					cksm_sum_0 = {10'h0, tdata[255:248], 8'h0};
					cksm_sum_1 = 26'h0;
				end
				4'b0000: begin
					cksm_sum_0 = 26'h0;
					cksm_sum_1 = 26'h0;
				end
    	  	  	   	/*  4'b0001:  begin
    	  	  	   	  			cksm_sum_14 = {10'h0,tdata[31:24],8'h0};
    	              			cksm_sum_15 = 26'h0;
    	              			end 
    	              4'b0011: begin
    	              			cksm_sum_15 = 26'h0;
    	              		   end
    	              4'b0111: begin
    	              			cksm_sum_15 = {10'h0,tdata[15:8],8'h0};
    	              		   end
    	              4'b0000: begin
    	              			cksm_sum_14 = 26'h0;
    	              			cksm_sum_15 = 26'h0;
    	              		   end*/
    	          	endcase	          	
    	      end
    end
     if(word_IP_DST_HI) begin
           cksm_sum_0 = 26'h0;
           cksm_sum_1 = 26'h0;
           cksm_sum_2 = 26'h0;
           cksm_sum_3 = 26'h0;
           cksm_sum_4 = 26'h0;
           cksm_sum_5 = 26'h0;
           cksm_sum_6 = 26'h0;
           cksm_sum_7 = 26'h0;
           cksm_sum_8 = 26'h0;
           cksm_sum_9 = 26'h0;
           cksm_sum_10 = 26'h0;
           cksm_sum_11 =  {18'h0, protocol};         
           cksm_sum_12 = 26'h0; //change header checksum to protocol
           cksm_sum_t1 = 26'h0;            
           cksm_sum_t2 = 26'h0;
           cksm_sum_t3 = 26'h0;
           cksm_sum_t4 = 26'h0;
           cksm_sum_t5 = 26'h0;
           cksm_sum_t6 = 26'h0;
           cksm_sum_t7 = 26'h0;
           cksm_sum_t8 = 26'h0;          
      end
      if(word_IP_DST_LO) begin
	       cksm_sum_5 = {10'h0, 16'h00ff};
      end
      if(add_carry_1) begin
         cksm_sum_final_1 = checksum_word_0+checksum_word_1+checksum_word_2+checksum_word_3;
         cksm_sum_final_2 = checksum_word_4+checksum_word_5+checksum_word_6+checksum_word_7;
         cksm_sum_final_3 = {10'h0, length};
      end
      if(add_carry_2 || add_carry_3) begin
         cksm_sum_final_1 = 26'h0;
         cksm_sum_final_2 =  {16'h0,  checksum_final[25:16]};
         cksm_sum_final_3 = {10'h0,  checksum_final[15:0]};   
      end
   end

   always @(posedge clk) begin
	if(reset) begin
		protocol <= 'h0;
		ip_header_len <= 'h0;
		length   <= 'h0;
	end
	else begin
      if(word_IP_DST_HI) begin
         ip_header_len <= {6'h0, tdata[143:136], 2'h0}; 
         protocol <= tdata[71:64]; 
      end
      if(word_IP_DST_LO) begin
         length   <= tdata[207:192];
      end

	end
   end

   // checksum logic. 16bit 1's complement over the IP header.
   // --- see RFC1936 for guidance.
   // 1's compl add: do a 2's compl add and then add the carry out
   // as if it were a carry in.
   // Final checksum (computed over the whole header incl checksum)
   // is in checksum_a and valid when IP_checksum_valid is 1
   // If checksum is good then it should be 0xffff
   always @(posedge clk) begin
	if(reset) begin
           checksum_done     <= 0;
            add_carry_1 <= 0;
            add_carry_2    <= 0;
            add_carry_3 <= 0;
	/*
            cksm_sum_0     <= 0;
            cksm_sum_1     <= 0;
            cksm_sum_2     <= 0;
            cksm_sum_3     <= 0;
            cksm_sum_4     <= 0;
            cksm_sum_5     <= 0;
            cksm_sum_6     <= 0;
            cksm_sum_7     <= 0; 
            cksm_sum_8     <= 0;
            cksm_sum_9     <= 0;
            cksm_sum_10     <= 0;
            cksm_sum_11     <= 0;
            cksm_sum_12     <= 0;
            cksm_sum_13     <= 0;
            cksm_sum_14     <= 0;
            cksm_sum_15     <= 0; 
           cksm_sum_final_1<= 0;
           cksm_sum_final_2<= 0;
           cksm_sum_final_3<= 0; 
	*/
          checksum_word_0 <= 0;
          checksum_word_1 <= 0;
          checksum_word_2 <= 0;
          checksum_word_3 <= 0;
          checksum_word_4 <= 0;
          checksum_word_5 <= 0;
          checksum_word_6 <= 0;
          checksum_word_7 <= 0;
	  checksum_final <= 0; 
	end
	else begin
		if(valid || add_carry_1 || add_carry_2 || add_carry_3) begin
	        	checksum_final  <= cksm_final; 
	        	checksum_word_0 <= cksm_temp0;
	        	checksum_word_1 <= cksm_temp1;
	        	checksum_word_2 <= cksm_temp2;
	        	checksum_word_3 <= cksm_temp3;
	        	checksum_word_4 <= cksm_temp4;
	        	checksum_word_5 <= cksm_temp5;
	        	checksum_word_6 <= cksm_temp6;
	        	checksum_word_7 <= cksm_temp7;  
	 	end
	        if(tlast && valid)begin
	            add_carry_1 <= 1;
	        end
	        else begin
	            add_carry_1 <= 0;
	        end
        	if(add_carry_1)begin
            	    add_carry_2 <= 1;
        	end
        	else begin
         	   add_carry_2 <= 0;
        	end

         	if(add_carry_2) begin
         	   add_carry_3 <= 1;
         	end
         	else begin
         	   add_carry_3 <= 0;
         	end
         	if(add_carry_3) begin
         	   checksum_done <= 1;
         	end
         	else begin
         	   checksum_done <= 0;
         	end 

         // synthesis translate_off
         // If we have any carry left in top 4 bits then algorithm is wrong
         /*if (checksum_done && checksum_word_0[26:16] != 10'h0) begin
            $display("%t %m ERROR: top 10 bits of checksum_word_0 not zero - algo wrong???",
                     $time);
            #100 $stop;
         end*/
         // synthesis translate_on
	end
   end


endmodule
