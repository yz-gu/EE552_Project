`timescale 1ns / 1ps
import SystemVerilogCSP::*;


module Filter_mem (
   interface filter_in, filter_in_addr, filter_out
);
    parameter WIDTH_DATA = 13;
    parameter DEPTH_F = 5, WIDTH_F = 5;
	parameter FL = 4, BL = 2;

    logic [WIDTH_DATA-1: 0] filter [WIDTH_F*DEPTH_F-1: 0];
    logic [WIDTH_DATA-1: 0] data_receive, data_send;
    logic [4:0] write_addr;
    logic [31:0] pkt;
    logic load_done;
    bit [1:0] data_type = 2'b00;
    bit [7:0] dst_addr;

    always begin
        for (int i=0; i<DEPTH_F*DEPTH_F; i++) begin
            fork
                filter_in_addr.Receive(write_addr);
                filter_in.Receive(data_receive);
            join
            filter[write_addr] = data_receive;
            #BL;
        end
        load_done = 1;
    end

    always begin
        wait(load_done==1);
        for (int i = 0; i<DEPTH_F; i++) begin // send data line by line
            dst_addr = {5'b0, i[2:0]}; // data on the nth line is sent to the 1st PE on nth column
            for (int j = 0; j<WIDTH_F; j++) begin
                #FL;
                data_send = filter[i*WIDTH_F+j];
                pkt = {1'b0, data_type, dst_addr, j[7:0], data_send};
                filter_out.Send(pkt);
            end
        end
        load_done = 0;
        // $stop;
    end

    // always begin
    //     for (int i = 0; i<DEPTH_F; i++) begin // send data line by line
    //         dst_addr = {5'b0, i[2:0]}; // data on the nth line is sent to the 1st PE on nth column
    //         for (int j = 0; j<WIDTH_F; j++) begin
    //             fork
    //                 filter_in_addr.Receive(write_addr);
    //                 filter_in.Receive(data_receive);
    //             join
    //             filter[write_addr] = data_receive;
    //             #FL;

    //             pkt = {1'b0, data_type, dst_addr, j[7:0], data_receive};
    //             filter_out.Send(pkt);
    //             #BL;
    //         end
    //     end
    //     // $stop;
    // end

endmodule


//module Filter_mem_tb;
//    logic [5:0] f_addr = 0;
//	logic [7:0] f_data;
//	integer fpi_f, status;

//    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(32)) out();
//    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1)) load_done();
//    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(13)) in();
//    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(5)) in_addr();
    
//    Filter_mem #(.WIDTH_DATA(13), .DEPTH_F(5), .WIDTH_F(5), .FL(4), .BL(2))
//        f_mem (.filter_out(out), .filter_in(in), .filter_in_addr(in_addr), .load_done(load_done));
//        // data_bucket db (.in(out));

//    initial begin
//		fpi_f = $fopen("filter.txt","r");

//		for(integer i=0; i<25; i++) begin
//            if(!$feof(fpi_f)) begin
//                status = $fscanf(fpi_f,"%d\n", f_data);
//                $display("filter data read:%d", f_data);
//                in_addr.Send(f_addr);
//                in.Send(f_data); 
//                f_addr++;
//            end
//        end

//		load_done.Send(1);
//    end
//endmodule
