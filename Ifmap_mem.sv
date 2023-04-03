`timescale 1ns / 1ps
import SystemVerilogCSP::*;


module Ifmap_mem (
   interface ifmap_in, ifmap_in_addr, ifmap_out, load_done
);
    parameter WIDTH_DATA = 13;
    parameter DEPTH_I = 25, WIDTH_I = 25;
	parameter FL = 4, BL = 2;

    logic [WIDTH_DATA-1: 0] ifmap [WIDTH_I*DEPTH_I-1: 0];
    logic [WIDTH_DATA-1: 0] ifmap_value_receive, ifmap_value_send;
    logic [9:0] write_addr;
    logic [31:0] pkt;
    logic done_sig;
    bit [1:0] data_type = 2'b01;
    bit [7:0] dst_addr;

    initial begin
        for(int i=0; i<DEPTH_I*DEPTH_I; i++) begin
			// timestep.Receive(ts);
			// if (ts == 1) begin
            fork
                ifmap_in_addr.Receive(write_addr);
                ifmap_in.Receive(ifmap_value_receive);
            join
            ifmap[write_addr] = ifmap_value_receive;
            #1;
            // end
        end

        // for(integer i=0; i<DEPTH_I*DEPTH_I; i++) begin
        //     timestep.Receive(ts);
        //     if (ts == 2) begin
        //         fork
        //             ifmap_in_addr.Receive(write_addr);
        //             ifmap_in.Receive(ifmap_value_receive);
        //         join
        //         ifmap[write_addr] = ifmap_value_receive;
        //         #1;
        //     end
        // end
    end
    
    always begin
        load_done.Receive(done_sig);
        for (int i = 0; i<DEPTH_I; i++) begin // send data line by line
            for (int j = 0; j<WIDTH_I; j++) begin
                ifmap_value_send = ifmap[i*WIDTH_I+j];
                if (i<3) begin
                    dst_addr = {i[4:0], 3'b0};
                end
                else
                    dst_addr = {5'd2, i[2:0]-3'd2};
                pkt = {1'b0, data_type, dst_addr, j[7:0], ifmap_value_send};
                ifmap_out.Send(pkt);
                #BL;
            end
        end
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
