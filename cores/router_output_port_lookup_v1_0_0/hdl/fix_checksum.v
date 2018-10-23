///////////////////////////////////////////////////////////////////////////////

//
// Module: tcp_checksum.v
// Description: Cauculate new tcp checksum
//              
//              
//
///////////////////////////////////////////////////////////////////////////////

module fix_checksum
  #(parameter C_S_AXIS_DATA_WIDTH=256,
     parameter C_S_AXIS_TUSER_WIDTH= 128 
   )

  (
   //--- datapath interface
   input  [C_S_AXIS_DATA_WIDTH-1:0]   tdata,
   input  [C_S_AXIS_DATA_WIDTH/8-1:0] tkeep, //in_ctrl
   input                              tlast, 
   input  [C_S_AXIS_TUSER_WIDTH-1:0]  tuser,
   input                              valid, // in_wr


   //--- interface to preprocess
   input                              word_IP_DST_HI,
   input                              word_IP_DST_LO,
   input			      word_OPT_PAYLOAD, 
   input			      word_OPT_PAYLOAD_2,
   input			      word_OPT_PAYLOAD_3,
   input			      word_OPT_PAYLOAD_4,
   // --- interface to process
   output                             fix_checksum_vld,
//   output                             fix_checksum_is_good,
   output     [11:0]                  fix_new_checksum,     // new checksum assuming decremented TTL
   input                              rd_fix_checksum,
   output			      is_fix_out, 
   // misc
   input reset,
   input clk
   );


   //---------------------- Wires and regs---------------------------
   reg  [7:0]  checksum_word_0, checksum_word_1,checksum_word_2,checksum_word_3;
   reg  [7:0]  checksum_word_4, checksum_word_5,checksum_word_6,checksum_word_7;
   reg  [7:0]  cksm_sum_t1 , cksm_sum_t2; 
   reg  [7:0]  cksm_sum_t3 , cksm_sum_t4;
   reg  [7:0]  cksm_sum_t5 , cksm_sum_t6;
   reg  [7:0]  cksm_sum_t7 , cksm_sum_t8;
   reg  [7:0]  cksm_sum_0, cksm_sum_1, cksm_sum_2,cksm_sum_3,cksm_sum_4, cksm_sum_5,cksm_sum_6, cksm_sum_7;
   reg  [7:0]  cksm_sum_8, cksm_sum_9, cksm_sum_10,cksm_sum_11,cksm_sum_12, cksm_sum_13,cksm_sum_14, cksm_sum_15; 
   wire [7:0]  cksm_temp0,cksm_temp1,cksm_temp2,cksm_temp3,cksm_temp4,cksm_temp5,cksm_temp6,cksm_temp7;
   reg  [7:0]  cksm_sum_final_1 ,cksm_sum_final_2 ,cksm_sum_final_3;
   wire [7:0]  cksm_final;
   reg  [11:0]  checksum_final;
   //---------------------- Wires and regs---------------------------
   reg    checksum_done;
   wire   empty;
   
   reg    add_carry_1,add_carry_2,add_carry_3;
  
   reg [15:0]fix_checksum_begin;
   reg	 is_fix;
   wire  is_fix_wire;

   wire [3:0] thousand, hundred, ten, one;
 
   //------------------------- Modules-------------------------------
        binary_to_bcd bcd_checksum(.binary(checksum_final), .thousand(thousand), .hundred(hundred), .ten(ten), .one(one));

   fallthrough_small_fifo #(.WIDTH(13), .MAX_DEPTH_BITS(2))
      fix_checksum_fifo
        (.din ({hundred, ten, one, is_fix_wire}),
         .wr_en (checksum_done),             // Write enable
         .rd_en (rd_fix_checksum),               // Read the next word
         .dout ({fix_new_checksum, is_fix_out}),
         .full (),
         .nearly_full (),
         .prog_full (),
         .empty (empty),
         .reset (reset),
         .clk (clk)
         );

   //------------------------- Logic -------------------------------
   assign fix_checksum_vld = !empty;
   assign is_fix_wire  = is_fix;

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
/*
      if(tuser[63:48]<=16'h38&&tlast=='b0&&valid)begin //small than 56(decimal)  Heartbeat
          fix_checksum_begin= tuser[63:48];

	  tdata[fix_checksum_begin:0]='h0;
      end
*/
      cksm_sum_0  = tdata[255:248]+tdata[247:240]; //tdata[255:240];
      cksm_sum_1   = tdata[239:232]+tdata[231:224];//tdata[239:224];
      cksm_sum_t1 = checksum_word_0;
      cksm_sum_2  =  tdata[223:216]+tdata[215:208];// tdata[223:208];
      cksm_sum_3  =  tdata[207:200]+tdata[199:192];//tdata[207:192];
      cksm_sum_t2 = checksum_word_1; 
      cksm_sum_4  =  tdata[191:184]+tdata[183:176];//tdata[191:176];
      cksm_sum_5  =  tdata[175:168]+tdata[167:160];//tdata[175:160];
      cksm_sum_t3 = checksum_word_2;
      cksm_sum_6  =  tdata[159:152]+tdata[151:144];//tdata[159:144];
      cksm_sum_7  =  tdata[143:136]+tdata[135:128];//tdata[143:128];
      cksm_sum_t4 = checksum_word_3;         
      cksm_sum_8  =  tdata[127:120]+tdata[119:112];//tdata[127:112];
      cksm_sum_9  =  tdata[111:104]+tdata[103:96 ];//tdata[111:96];
      cksm_sum_t5 = checksum_word_4;
      cksm_sum_10 =  tdata[95 :88] +tdata[87:80];//tdata[95:80];
      cksm_sum_11 =  tdata[79 :72] +tdata[71:64];//tdata[79:64];
      cksm_sum_t6 = checksum_word_5;
      cksm_sum_12 =  tdata[63:56] + tdata[55:48];//tdata[63:48];
      cksm_sum_13 =  tdata[47:40] + tdata[39:32];//tdata[47:32];
      cksm_sum_t7 = checksum_word_6;
      cksm_sum_14 =  tdata[31:24] + tdata[23:16];//tdata[31:16];
      cksm_sum_15 =  tdata[15:8]  + tdata[7:0];//tdata[15:0];
      cksm_sum_t8 = checksum_word_7;

      cksm_sum_final_1 = 'h0;
      cksm_sum_final_2 = 'h0;
      cksm_sum_final_3 = 'h0;

      if(tkeep!=32'hFFFFFFFF) begin //tkeep[index] == 1'h ==4'b each bits-> to each bytes in tdata
    	  	  if(tkeep[3:0]!=4'hF)begin
    	  	  	 case(tkeep[3:0])
				4'b1110: begin
					
					cksm_sum_12 = 8'h0;
					cksm_sum_13 = 8'h0;
					cksm_sum_14 = 8'h0;
					cksm_sum_15 = 8'h0;
					
				end
				4'b1100: begin
					//cksm_sum_11 = tdata[71:64];
					cksm_sum_11 = tdata[79:72];
					cksm_sum_12 = 8'h0;
					cksm_sum_13 = 8'h0;
					cksm_sum_14 = 8'h0;
					
				end
				4'b1000: begin
                                        cksm_sum_11 = 8'h0;
                                        cksm_sum_12 = 8'h0;
                                        cksm_sum_13 = 8'h0;				
                                        cksm_sum_14 = 8'h0;
                                  
				end
				4'b0000: begin
					cksm_sum_14 = 8'h0;
					cksm_sum_15 = 8'h0;
				end
    	  
    	          	endcase	          	

    	      end
    	      if(tkeep[7:4]!=4'hF)begin
    	  	  	   	case(tkeep[7:4])
				4'b1110: begin
                                        cksm_sum_10 = 8'h0;
                                        cksm_sum_11 = 8'h0;
                                        cksm_sum_12 = 8'h0;
                                        cksm_sum_13 = 8'h0;					
				end
				4'b1100: begin
					
                                        //cksm_sum_9 = tdata[103:96];
					cksm_sum_9 = tdata[111:104];
                                        cksm_sum_10 = 8'h0;
                                        cksm_sum_11 = 8'h0;
                                        cksm_sum_12 = 8'h0;

				end
				4'b1000: begin
                                        cksm_sum_9 = 8'h0;
                                        cksm_sum_10 = 8'h0;
                                        cksm_sum_11 = 8'h0;
                                        cksm_sum_12 = 8'h0;
				end
				4'b0000: begin
					cksm_sum_12 = 8'h0;
					cksm_sum_13 = 8'h0;
				end
    	          	endcase	          	
    	      end
    	      if(tkeep[11:8]!=4'hF)begin
    	  	  	   	case(tkeep[11:8])
				4'b1110: begin
                                        cksm_sum_8 = 8'h0;
                                        cksm_sum_9 = 8'h0;
                                        cksm_sum_10 = 8'h0;
                                        cksm_sum_11 = 8'h0;
				end
				4'b1100: begin
                                        //cksm_sum_7  = tdata[135:128];
					cksm_sum_7  = tdata[143:136];

                                        cksm_sum_8  = 8'h0;
                                        cksm_sum_9  = 8'h0;
                                        cksm_sum_10 = 8'h0;

				end
				4'b1000: begin
                                        cksm_sum_7 = 8'h0;
                                        cksm_sum_8 = 8'h0;
                                        cksm_sum_9 = 8'h0;
                                        cksm_sum_10 = 8'h0;

				end
				4'b0000: begin
					cksm_sum_11=8'h0;
					cksm_sum_10=8'h0;
				end
    	          	endcase	          	
    	      end
    	      if(tkeep[15:12]!=4'hF)begin
    	  	  	   	case(tkeep[15:12])
				4'b1110: begin
                                        cksm_sum_6 = 8'h0;
                                        cksm_sum_7 = 8'h0;
                                        cksm_sum_8 = 8'h0;
                                        cksm_sum_9 = 8'h0;
				end
				4'b1100: begin
                                       // cksm_sum_5  = tdata[167:160];
					cksm_sum_5  = tdata[175:168];
                                        cksm_sum_6  = 8'h0;
                                        cksm_sum_7  = 8'h0;
                                        cksm_sum_8 = 8'h0;

				end
				4'b1000: begin
                                        cksm_sum_5 = 8'h0;
                                        cksm_sum_6 = 8'h0;
                                        cksm_sum_7 = 8'h0;
                                        cksm_sum_8 = 8'h0;
				end
				4'b0000: begin
					cksm_sum_9=8'h0;
					cksm_sum_8=8'h0;
				end
    	          	endcase	          	
    	      end
    	      if(tkeep[19:16]!=4'hF)begin
    	  	  	   	case(tkeep[19:16])
                                4'b1110: begin
                                        cksm_sum_4 = 8'h0;
                                        cksm_sum_5 = 8'h0;
                                        cksm_sum_6 = 8'h0;
                                        cksm_sum_7 = 8'h0;
                                end
                                4'b1100: begin
                                        //cksm_sum_3  = tdata[199:192];
					cksm_sum_3  = tdata[207:200];
                                        cksm_sum_4  = 8'h0;
                                        cksm_sum_5  = 8'h0;
                                        cksm_sum_6 = 8'h0;

                                end
                                4'b1000: begin
                                        cksm_sum_3 = 8'h0;
                                        cksm_sum_4 = 8'h0;
                                        cksm_sum_5 = 8'h0;
                                        cksm_sum_6 = 8'h0;
                                end
				4'b0000: begin
					cksm_sum_7 =8'h0;
					cksm_sum_6 =8'h0;
				end
    	          	endcase	          	
    	      end
    	      if(tkeep[23:20]!=4'hF)begin
    	  	  	   	case(tkeep[23:20])
                                4'b1110: begin
                                        cksm_sum_2 = 8'h0;
                                        cksm_sum_3 = 8'h0;
                                        cksm_sum_4 = 8'h0;
                                        cksm_sum_5 = 8'h0;
                                end
                                4'b1100: begin
                                        //cksm_sum_1  = tdata[231:224];
					cksm_sum_1  = tdata[239:232];
                                        cksm_sum_2  = 8'h0;
                                        cksm_sum_3  = 8'h0;
                                        cksm_sum_4  = 8'h0;

                                end
                                4'b1000: begin
                                        cksm_sum_1 = 8'h0;
                                        cksm_sum_2 = 8'h0;
                                        cksm_sum_3 = 8'h0;
                                        cksm_sum_4 = 8'h0;
                                end
				4'b0000: begin
					cksm_sum_4 = 8'h0;
					cksm_sum_5 = 8'h0;
				end
    	          	endcase	          	
    	      end
    	      if(tkeep[27:24]!=4'hF)begin // fix_checksum is possible split into two space between two 256 bits words
    	  	  	   	case(tkeep[27:24])
				4'b1110: begin   //checksum isnt split 
					cksm_sum_0 = 8'h0;
					cksm_sum_1 = 8'h0;
					cksm_sum_2 = 8'h0;
					cksm_sum_3 = 8'h0;
				end
				4'b1100: begin  //checksum is split 8bits in last word
                                        cksm_sum_0 = 8'h0;
                                        cksm_sum_1 = 8'h0;
					cksm_sum_2 = 8'h0;
					cksm_sum_3 = 8'h0;
				end
				4'b1000: begin  //checksum is split 16bits in last word
                                        cksm_sum_0 = 8'h0;
                                        cksm_sum_1 = 8'h0;
					cksm_sum_2 = 8'h0;
					cksm_sum_3 = 8'h0;
				end
				4'b0000: begin //checksum is split 24bits in last word
                                        cksm_sum_0 = 8'h0;
                                        cksm_sum_1 = 8'h0;
                                        cksm_sum_2 = 8'h0;
                                        cksm_sum_3 = 8'h0;
				end
    	  	  	 
    	          	endcase	          	
    	      end
    	      if(tkeep[31:28]!=4'hF)begin// fix_checksum is possible split into two space between two 256 bits words
    	  	  	   	case(tkeep[31:28])
				4'b1110: begin //32 in last word
                                      cksm_sum_0= 8'h0;
                                      cksm_sum_1= 8'h0;
					
				end
				4'b1100: begin //40in last word
                                      cksm_sum_0= 8'h0;
                                      cksm_sum_1= 8'h0;

				end
				4'b1000: begin //48in last word
                                      cksm_sum_0= 8'h0;
                                      cksm_sum_1= 8'h0;

				end
				4'b0000: begin
				      cksm_sum_0= 8'h0;
				      cksm_sum_1= 8'h0;
				end
    	          	endcase	          	
    	      end

	
    end
    if(tkeep==32'hFFFFFFFF&&tlast==1'b1) begin
	cksm_sum_12 = tdata[63:56];
	cksm_sum_13 = 8'h0;
	cksm_sum_14 = 8'h0;
	cksm_sum_15 = 8'h0;
    end
                       
     if(word_IP_DST_HI) begin
           cksm_sum_0 =  8'h0;
           cksm_sum_1 =  8'h0;
           cksm_sum_2 =  8'h0;
           cksm_sum_3 =  8'h0;
           cksm_sum_4 =  8'h0;
           cksm_sum_5 =  8'h0;
           cksm_sum_6 =  8'h0;
           cksm_sum_7 =  8'h0;
           cksm_sum_8 =  8'h0;
           cksm_sum_9 =  8'h0;
           cksm_sum_10 = 8'h0;
	   cksm_sum_11 = 8'h0;        
           cksm_sum_12 = 8'h0; //change header checksum to protocol
           cksm_sum_13 = 8'h0;
	   cksm_sum_14 = 8'h0;
	   cksm_sum_15 = 8'h0;

           cksm_sum_t1 = 8'h0;            
           cksm_sum_t2 = 8'h0;
           cksm_sum_t3 = 8'h0;
           cksm_sum_t4 = 8'h0;
           cksm_sum_t5 = 8'h0;
           cksm_sum_t6 = 8'h0;
           cksm_sum_t7 = 8'h0;
           cksm_sum_t8 = 8'h0;          
      end
      if(word_IP_DST_LO) begin                                                         
           cksm_sum_0 =  8'h0;
           cksm_sum_1 =  8'h0;
           cksm_sum_2 =  8'h0;
           cksm_sum_3 =  8'h0;
           cksm_sum_4 =  8'h0;
           cksm_sum_5 =  8'h0;
           cksm_sum_6 =  8'h0;
           cksm_sum_7 =  8'h0;
           cksm_sum_8 =  8'h0;
           cksm_sum_9 =  8'h0;
           cksm_sum_10 = 8'h0;
           cksm_sum_11 = 8'h0;
           cksm_sum_12 = 8'h0; //change header checksum to protocol
           cksm_sum_13 = 8'h0;
           cksm_sum_14 = 8'h0;
           cksm_sum_15 = 8'h0;

           cksm_sum_t1 = 8'h0;
           cksm_sum_t2 = 8'h0;
           cksm_sum_t3 = 8'h0;
           cksm_sum_t4 = 8'h0;
           cksm_sum_t5 = 8'h0;
           cksm_sum_t6 = 8'h0;
           cksm_sum_t7 = 8'h0;
           cksm_sum_t8 = 8'h0;

      end
      
      if(word_OPT_PAYLOAD)begin
	   cksm_sum_0 =  8'h0;
      end
 
     
   
      if(add_carry_1) begin
         cksm_sum_final_1 = checksum_word_0+checksum_word_1+checksum_word_2+checksum_word_3;
         cksm_sum_final_2 = checksum_word_4+checksum_word_5+checksum_word_6+checksum_word_7;
         cksm_sum_final_3 = 8'h0;
	 
      end

    

end


   always @(posedge clk) begin
	if(reset) begin
		is_fix <= 'h0;
	end
	else begin
	       if(word_IP_DST_LO) begin
	         if(tdata[223:208]==16'h138a &&tdata[139:128] == 12'b000000011000) begin
	                    is_fix <= 1'b1;
	         end
	         else begin
	                    is_fix <= 1'b0;
	         end
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
		if(valid || add_carry_1 ) begin
	        	checksum_final  <= {4'b0,cksm_final}; 
	        	checksum_word_0 <= cksm_temp0;
	        	checksum_word_1 <= cksm_temp1;
	        	checksum_word_2 <= cksm_temp2;
	        	checksum_word_3 <= cksm_temp3;
	        	checksum_word_4 <= cksm_temp4;
	        	checksum_word_5 <= cksm_temp5;
	        	checksum_word_6 <= cksm_temp6;
	        	checksum_word_7 <= cksm_temp7;  
	 	end
		if(is_fix==1'b0)begin
			checksum_done <= 1;
		end
		else begin
			checksum_done <= 0;
		end


	        if(tlast && valid)begin
	            add_carry_1 <= 1;
	        end
	        else begin
	            add_carry_1 <= 0;
	        end
        	if(add_carry_1)begin
		    checksum_done <=1;
        	end
        	else begin
         	    checksum_done <= 0;
        	end

/*
         	if(add_carry_2) begin
         	 //  add_carry_3 <= 1;
		    checksum_done <= 1 ;
         	end
         	else begin
         	//  add_carry_3 <= 0;
		    checksum_done <= 0 ;
         	end
*/
/*
         	if(add_carry_3) begin
         	   checksum_done <= 1;
         	end
         	else begin
         	   checksum_done <= 0;
         	end 
*/
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
