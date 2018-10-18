///////////////////////////////////////////////////////////////////////////////
//
// Module: fix_field_decoder.v
// Author: Chun-Yu, Li
// LAB;    CIAL
// Date:   2017-8-14
//
///////////////////////////////////////////////////////////////////////////////

module fix_field_decoder(
    input      [310:0] din,
    output reg [7:0]   MsgType,
    output     [71:0]  Price,
    output     [23:0]  OrderQty,
    output     [7:0]   TwseOrdType,
    output     [7:0]   TwseExCode,
    output     [55:0]  SenderCompID,
    output     [31:0]  TargetCompID,
    output     [7:0]   TargetSubID,
    output     [95:0]  ClOrdID,
    output     [39:0]  OrderID,
    output     [55:0]  Account
);

// price decoder
packbcd_to_ascii p2a_00(.din(din[308:305]), .dout(Price[71:64]));
packbcd_to_ascii p2a_01(.din(din[304:301]), .dout(Price[63:56]));
packbcd_to_ascii p2a_02(.din(din[300:297]), .dout(Price[55:48]));
packbcd_to_ascii p2a_03(.din(din[296:293]), .dout(Price[47:40]));
packbcd_to_ascii p2a_04(.din(din[292:289]), .dout(Price[39:32]));
packbcd_to_ascii p2a_05(.din(din[288:285]), .dout(Price[31:24]));
packbcd_to_ascii p2a_06(.din(din[284:281]), .dout(Price[23:16]));
packbcd_to_ascii p2a_07(.din(din[280:277]), .dout(Price[15:8]));
packbcd_to_ascii p2a_08(.din(din[276:273]), .dout(Price[7 :0]));

// qty decoder
packbcd_to_ascii p2a_09(.din(din[272:269]), .dout(OrderQty[23:16]));
packbcd_to_ascii p2a_10(.din(din[268:265]), .dout(OrderQty[15:8]));
packbcd_to_ascii p2a_11(.din(din[264:261]), .dout(OrderQty[7 :0]));

// order type decoder
packbcd_to_ascii p2a_12(.din(din[260:257]), .dout(TwseOrdType));

// excode decoder
packbcd_to_ascii p2a_13(.din(din[256:253]), .dout(TwseExCode));

// SenderCompID
assign SenderCompID = din[252:197];

// TargetCompID
assign TargetCompID = (din[196]) ? 32'b0101_1000_0101_0100_0100_0001_0100_1001
                                 : 32'b0101_0010_0100_1111_0100_0011_0100_1111;

// target sub decoder
packbcd_to_ascii p2a_14(.din(din[195:192]), .dout(TargetSubID));

//  ClOrdID
assign ClOrdID = din[191:96];

//  OrderID
assign OrderID = din[95:56];

//  Account
assign Account = din[55: 0];

//  --------  MsgType decoder  --------  //
always @(*) begin
    case(din[310:309])
    2'b01   : MsgType = 8'b0100_0111; // G
    2'b10   : MsgType = 8'b0100_0110; // F
    default : MsgType = 8'b0100_0100; // D
    endcase
end

endmodule