`timescale 1ns / 1ps
import SystemVerilogCSP::*;


module Arbiter ( // arbitrate inputs from 5 inputs, priority: up>down>left>right>local, send the output to Resend module
    interface up_in, down_in, left_in, right_in, local_in, arb_out
);
    parameter WIDTH_PKT = 32;
    parameter FL = 4, BL = 2;
    logic [WIDTH_PKT-1:0] pkt;

    always begin
        wait(up_in.status!=idle | down_in.status!=idle | left_in.status!=idle | right_in.status!=idle | local_in.status!=idle)
        if (up_in.status!=idle) begin
            up_in.Receive(pkt);
            #FL;
            arb_out.Send(pkt);
            #BL;
        end
        if (down_in.status!=idle) begin
            down_in.Receive(pkt);
            #FL;
            arb_out.Send(pkt);
            #BL;
        end
        if (left_in.status!=idle) begin
            left_in.Receive(pkt);
            #FL;
            arb_out.Send(pkt);
            #BL;
        end
        if (right_in.status!=idle) begin
            right_in.Receive(pkt);
            #FL;
            arb_out.Send(pkt);
            #BL;
        end
        if (local_in.status!=idle) begin
            local_in.Receive(pkt);
            #FL;
            arb_out.Send(pkt);
            #BL;
        end
    end
endmodule


module Resend ( // create a copy for the filter and ifmap packet if necessary
    interface in, out
);
    parameter WIDTH_PKT = 32;
    parameter FL = 4, BL = 2;
    parameter ADDRX = 3'd0, ADDRY = 5'd0;
    logic [WIDTH_PKT-1:0] pkt, pkt_new;
    logic [7:0] dst_addr, dst_addr_new;

    always begin
        in.Receive(pkt);
        #FL;
        out.Send(pkt);
        dst_addr = pkt[28:21];
        if(pkt[30:29]==2'b00 & dst_addr=={ADDRY, ADDRX} & ADDRY!=5'd2) begin // it's a filter packet, the new dst addr = y+1
            dst_addr_new[7:3] = dst_addr[7:3] + 1;
            dst_addr_new[2:0] = dst_addr[2:0];
            pkt_new = {pkt[31:29], dst_addr_new, pkt[20:0]};
            out.Send(pkt_new);
        end
        if(pkt[30:29]==2'b01 & dst_addr=={ADDRY, ADDRX} & ADDRY!=5'd0 & ADDRX!=3'd2) begin // it's a ifmap packet, the new dst addr is x+1, y-1
            dst_addr_new[2:0] = dst_addr[2:0] + 1;
            dst_addr_new[7:3] = dst_addr[7:3] - 1;
            pkt_new = {pkt[31:29], dst_addr_new, pkt[20:0]};
            out.Send(pkt_new);
        end
        #BL;
    end
endmodule


module Forward ( // send the packet to the corresponding output port
    interface forward_in, up_out, down_out, left_out, right_out, local_out
);
    parameter WIDTH_PKT = 32;
    parameter FL = 4, BL = 2;
    parameter ADDRX = 3'd0, ADDRY = 5'd0;

    logic [WIDTH_PKT-1:0] pkt;
    logic [7:0] dst_addr;

	always begin
        forward_in.Receive(pkt);
        dst_addr = pkt[28:21];
        #FL;
        if (dst_addr[2:0] == ADDRX && dst_addr[7:3] == ADDRY) begin
            local_out.Send(pkt);
        end
        else if (dst_addr[2:0] > ADDRX)
            right_out.Send(pkt);
        else if (dst_addr[2:0] < ADDRX)
            left_out.Send(pkt);
        else if (dst_addr[7:3] > ADDRY)
            down_out.Send(pkt);
        else
            up_out.Send(pkt);
        #BL;
	end
endmodule


module Router (
    interface up_in, down_in, left_in, right_in, local_in,
    interface up_out, down_out, left_out, right_out, local_out
);
    parameter WIDTH_PKT = 32;
    parameter ADDRX = 3'd0, ADDRY = 5'd0;
    parameter FL = 4, BL = 2;
    Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) arb_out(), forward_in();

    Arbiter #(.WIDTH_PKT(WIDTH_PKT), .FL(FL), .BL(BL))
        arb(.up_in(up_in), .down_in(down_in), .left_in(left_in), .right_in(right_in), .local_in(local_in), .arb_out(arb_out));
    Resend #(.WIDTH_PKT(WIDTH_PKT), .FL(FL), .BL(BL), .ADDRX(ADDRX), .ADDRY(ADDRY))
        resend(.in(arb_out), .out(forward_in));
    Forward #(.WIDTH_PKT(WIDTH_PKT), .FL(FL), .BL(BL), .ADDRX(ADDRX), .ADDRY(ADDRY))
        fwd(.forward_in(forward_in), .up_out(up_out), .down_out(down_out), .left_out(left_out), .right_out(right_out), .local_out(local_out));
endmodule


//module data_bucket (interface in);
//    parameter WIDTH = 32;
//    parameter BL = 0;
//    logic [WIDTH-1:0] ReceiveValue = 0;
//    always begin
//        in.Receive(ReceiveValue);
//        #BL;
//    end
//endmodule


//module Router_tb;
//    Channel #(.hsProtocol(P4PhaseBD),.WIDTH(32)) up_in(), down_in(), left_in(), right_in(), local_in(), up_out(), down_out(), left_out(), right_out(), local_out();

//    Router #(.WIDTH_PKT(32), .ADDRX(3'd2), .ADDRY(5'd13))
//        router (.up_in(up_in), .down_in(down_in), .left_in(left_in), .right_in(right_in), .local_in(local_in),
//            .up_out(up_out), .down_out(down_out), .left_out(left_out), .right_out(right_out), .local_out(local_out));
//    data_bucket db0(.in(up_out));
//    data_bucket db1(.in(down_out));
//    data_bucket db2(.in(left_out));
//    data_bucket db3(.in(right_out));
//    data_bucket db4(.in(local_out));

//    initial begin
//        fork
//            down_in.Send({3'b001, 5'd13, 3'd2, 8'b11111111, 13'd1});
//            up_in.Send({3'd0, 5'd13, 3'd2, 8'b11111111, 13'd57});
//            local_in.Send({3'b010, 5'd13, 3'd2, 8'b11111111, 13'd23});
//        join
//        #20;
//        $stop;
//    end
//endmodule