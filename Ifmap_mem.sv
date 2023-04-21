`timescale 1ns / 1ps
import SystemVerilogCSP::*;


module Ifmap_mem (
   interface ifmap_in, ifmap_in_addr, ifmap_out
);
    parameter WIDTH_DATA = 13;
    parameter DEPTH_I = 25, WIDTH_I = 25;
	parameter FL = 4, BL = 2;
    parameter DEPTH_R = 21;

    logic [WIDTH_I*DEPTH_I-1: 0] [WIDTH_DATA-1: 0] ifmap;
    logic [WIDTH_DATA-1: 0] data_receive, data_send;
    logic [9:0] write_addr;
    logic [31:0] pkt;
    logic load_done;
    bit [1:0] data_type = 2'b01;
    bit [7:0] dst_addr;

    always begin
        for (int i=0; i<DEPTH_I*DEPTH_I; i++) begin
            fork
                ifmap_in_addr.Receive(write_addr);
                ifmap_in.Receive(data_receive);
            join
            ifmap[write_addr] = data_receive;
            #BL;
        end
        load_done = 1;
    end
    
//    always begin
//        wait(load_done==1);
//        for (int i = 0; i<DEPTH_I; i++) begin // send data line by line
//            for (int j = 0; j<WIDTH_I; j++) begin
//                #FL;
//                data_send = ifmap[i*WIDTH_I+j];
//                if (i<DEPTH_R)
//                    dst_addr = {i[4:0], 3'b0};
//                else
//                    dst_addr = {DEPTH_R[4:0]-3'd1, i[2:0]-DEPTH_R[2:0]+3'd1}; // reaches the last line
//                pkt = {1'b0, data_type, dst_addr, j[7:0], data_send};
//                ifmap_out.Send(pkt);
//            end
//        end
//        load_done = 0;
//    end

    logic [12:0] data2send;
    always begin
        wait(load_done==1);
        for (int i = 0; i<DEPTH_I; i++) begin // send data line by line
            #FL;
            if (i<DEPTH_R)
                dst_addr = {i[4:0], 3'b0};
            else
                dst_addr = {DEPTH_R[4:0]-3'd1, i[2:0]-DEPTH_R[2:0]+3'd1}; // reaches the last line
                
            data2send = {ifmap[i*WIDTH_I+12], ifmap[i*WIDTH_I+11], ifmap[i*WIDTH_I+10], ifmap[i*WIDTH_I+9], ifmap[i*WIDTH_I+8], ifmap[i*WIDTH_I+7], ifmap[i*WIDTH_I+6], ifmap[i*WIDTH_I+5], ifmap[i*WIDTH_I+4], ifmap[i*WIDTH_I+3], ifmap[i*WIDTH_I+2], ifmap[i*WIDTH_I+1], ifmap[i*WIDTH_I]};
            pkt = {1'b0, data_type, dst_addr, 8'b0, data2send};
            ifmap_out.Send(pkt);
            #FL;
            data2send = {1'b0, ifmap[i*WIDTH_I+24], ifmap[i*WIDTH_I+23], ifmap[i*WIDTH_I+22], ifmap[i*WIDTH_I+21], ifmap[i*WIDTH_I+20], ifmap[i*WIDTH_I+19], ifmap[i*WIDTH_I+18], ifmap[i*WIDTH_I+17], ifmap[i*WIDTH_I+16], ifmap[i*WIDTH_I+15], ifmap[i*WIDTH_I+14], ifmap[i*WIDTH_I+13]};
            pkt = {1'b0, data_type, dst_addr, 8'b1, data2send};
            ifmap_out.Send(pkt);
        end
        load_done = 0;
    end

endmodule


//module Ifmap_mem_tb;
//    logic [9:0] i_addr = 0;
//	logic [7:0] i_data;
//	integer fpi_i, status;

//    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(32)) out();
//    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1)) load_done();
//    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(13)) in();
//    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(10)) in_addr();
    
//    Ifmap_mem #(.WIDTH_DATA(13), .DEPTH_I(25), .WIDTH_I(25), .FL(4), .BL(2))
//        f_mem (.ifmap_out(out), .ifmap_in(in), .ifmap_in_addr(in_addr), .load_done(load_done));
////    data_bucket db (.in(out));

//    initial begin
//		fpi_i = $fopen("ifmap.txt","r");

//        for(integer i=0; i<625; i++) begin
//            if(!$feof(fpi_i)) begin
//                status = $fscanf(fpi_f,"%d\n", i_data);
//                $display("ifmap data read:%d", i_data);
//                in_addr.Send(i_addr);
//                in.Send(i_data); 
//                i_addr++;
//            end
//        end

//		load_done.Send(1);
//    end
//endmodule
