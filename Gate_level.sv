`timescale 1ns / 1ps


interface Channel_micropipe;
    parameter WIDTH = 6;
    logic req, ack;
    logic [WIDTH-1:0] data;
endinterface


module data_generator (interface out);
    parameter WIDTH = 8;
    parameter ADDR = 4'd0;
    parameter NUM = 8;
//    logic [WIDTH-1:0] To_send [6:0] = {12'd14, 12'd5, 12'd118, 12'd51, 12'd27, 12'd8, 12'd77};
    logic [7:0] data2send;
    int interval;
    
    initial begin
        for (int i = 0; i<NUM-1; i = i+1) begin
            interval = $urandom_range(0,9);
            #interval;
            out.req = 1;
            data2send = $urandom_range(0,2**WIDTH-1);
            out.data = {ADDR, data2send};
            wait(out.ack==1)
            out.req = 0;
            wait(out.ack==0);
        end
    end
endmodule


module data_bucket (interface in);
    parameter WIDTH = 13;
    parameter WIDTH_PKT = 16;
    parameter LENGTH = 40;
    logic [WIDTH_PKT-1: 0] in_data;
    logic [WIDTH-1:0] ReceiveValue [LENGTH-1:0];
    logic [2:0] SrcAddr [LENGTH-1:0];
    int i = 0;
    
    always begin
        wait(in.req==1);
        in_data = in.data;
        ReceiveValue[i] = in_data[WIDTH-1:0];
        SrcAddr[i] = in_data[WIDTH_PKT-1:WIDTH];
        i=i+1;
        in.ack = 1;
        wait(in.req==0);
        in.ack = 0;
    end
endmodule


module Arbiter_gate_level(
    interface up_in, down_in, arb_out
);
    parameter WIDTH_PKT = 12;
    parameter FL = 4, BL = 2;
    logic [WIDTH_PKT-1:0] pkt_up, pkt_down;
//    logic [WIDTH_PKT-1:0] pkt_left, pkt_right, pkt_local;
    logic flag_up = 0, flag_down = 0;
//    logic flag_left = 0, flag_right = 0, flag_local = 0;

    always begin
        if (!flag_up) begin
            wait(up_in.req==1);
            pkt_up = up_in.data;
            up_in.ack = 1;
            wait(up_in.req==0);
            up_in.ack = 0;
            flag_up = 1;
        end
        #BL;
    end
    always begin
        if (!flag_down) begin
            wait(down_in.req==1);
            pkt_down = down_in.data;
            down_in.ack = 1;
            wait(down_in.req==0);
            down_in.ack = 0;
            flag_down = 1;
        end
        #BL;
    end

    always begin
        #FL;
        if(flag_up) begin
            arb_out.req = 1;
            arb_out.data = pkt_up;
            wait(arb_out.ack==1);
            arb_out.req = 0;
            wait(arb_out.ack==0);
            flag_up = 0;
        end
        if(flag_down) begin
            arb_out.req = 1;
            arb_out.data = pkt_down;
            wait(arb_out.ack==1);
            arb_out.req = 0;
            wait(arb_out.ack==0);
            flag_down = 0;
        end
    end
endmodule


module Arb_gatelevel_tb;
    parameter WIDTH = 8, WIDTH_PKT = 12, NUM = 8;
    Channel_micropipe #(.WIDTH(WIDTH_PKT)) up_in(), down_in(), arb_out();

    data_generator  #(.WIDTH(WIDTH), .ADDR(4'd0), .NUM(NUM)) dg0 (up_in);
    data_generator  #(.WIDTH(WIDTH), .ADDR(4'd1), .NUM(NUM)) dg1 (down_in);
//    data_generator  #(.WIDTH(WIDTH), .ADDR(3'd0)) dg2 (left_in);
//    data_generator  #(.WIDTH(WIDTH), .ADDR(3'd1)) dg3 (right_in);
//    data_generator  #(.WIDTH(WIDTH), .ADDR(3'd0)) dg4 (local_in);
    Arbiter_gate_level  #(.WIDTH_PKT(WIDTH_PKT), .FL(4), .BL(2)) arb (.up_in(up_in), .down_in(down_in), .arb_out(arb_out));
    data_bucket     #(.WIDTH(WIDTH), .LENGTH(40)) db0 (arb_out);
    
    initial begin
        #1000 $stop;
    end
    
endmodule