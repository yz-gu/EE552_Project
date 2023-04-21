`timescale 1ns / 1ps
import SystemVerilogCSP::*;


module Arbiter ( // round robin
    interface up_in, down_in, left_in, right_in, local_in, arb_out
);
    parameter WIDTH_PKT = 32;
    parameter FL = 4, BL = 2;
    logic [WIDTH_PKT-1:0] pkt_up, pkt_down, pkt_left, pkt_right, pkt_local;
    logic flag_up = 0, flag_down = 0, flag_left = 0, flag_right = 0, flag_local = 0;

    always begin
        if (!flag_up) begin
            up_in.Receive(pkt_up);
            flag_up = 1;
        end
        #BL;
    end
    always begin
        if (!flag_down) begin
            down_in.Receive(pkt_down);
            flag_down = 1;
        end
        #BL;
    end
    always begin
        if (!flag_left) begin
            left_in.Receive(pkt_left);
            flag_left = 1;
        end
        #BL;
    end
    always begin
        if (!flag_right) begin
            right_in.Receive(pkt_right);
            flag_right = 1;
        end
        #BL;
    end
    always begin
        if (!flag_local) begin
            local_in.Receive(pkt_local);
            flag_local = 1;
        end
        #BL;
    end

    always begin
        #FL;
        if(flag_up) begin
            arb_out.Send(pkt_up);
            flag_up = 0;
        end
        if(flag_down) begin
            arb_out.Send(pkt_down);
            flag_down = 0;
        end
        if(flag_left) begin
            arb_out.Send(pkt_left);
            flag_left = 0;
        end
        if(flag_right) begin
            arb_out.Send(pkt_right);
            flag_right = 0;
        end
        if(flag_local) begin
            arb_out.Send(pkt_local);
            flag_local = 0;
        end
    end
endmodule


module Resend ( // create a copy for the filter and ifmap packet if necessary
    interface in, out
);
    parameter WIDTH_PKT = 32;
    parameter FL = 4, BL = 2;
    parameter ADDRX = 3'd0, ADDRY = 5'd0;
    parameter DEPTH_R = 21, DEPTH_F = 5;
    logic [WIDTH_PKT-1:0] pkt, pkt_new;
    logic [7:0] dst_addr, dst_addr_new;

    always begin
        in.Receive(pkt);
        #FL;
        out.Send(pkt);
        dst_addr = pkt[28:21];
        if(pkt[30:29]==2'b00 & dst_addr=={ADDRY, ADDRX} & ADDRY!=DEPTH_R[4:0]-5'd1) begin // it's a filter packet, the new dst addr = y+1
            dst_addr_new[2:0] = dst_addr[2:0];
            dst_addr_new[7:3] = dst_addr[7:3] + 1;
            pkt_new = {pkt[31:29], dst_addr_new, pkt[20:0]};
            out.Send(pkt_new);
        end
        if(pkt[30:29]==2'b01 & dst_addr=={ADDRY, ADDRX} & ADDRY!=5'd0 & ADDRX!=DEPTH_F[2:0]-3'd1) begin // it's a ifmap packet, the new dst addr is x+1, y-1
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
        if (dst_addr[2:0] == ADDRX && dst_addr[7:3] == ADDRY)
            local_out.Send(pkt);
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
    parameter DEPTH_R = 21, DEPTH_F = 5;
    Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) arb_out(), forward_in();

    Arbiter #(.WIDTH_PKT(WIDTH_PKT), .FL(FL), .BL(BL))
        arb(.up_in(up_in), .down_in(down_in), .left_in(left_in), .right_in(right_in), .local_in(local_in), .arb_out(arb_out));
    Resend #(.WIDTH_PKT(WIDTH_PKT), .FL(FL), .BL(BL), .ADDRX(ADDRX), .ADDRY(ADDRY), .DEPTH_R(DEPTH_R), .DEPTH_F(DEPTH_F))
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