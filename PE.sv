`timescale 1ns / 1ps
import SystemVerilogCSP::*;


module Filter_RF ( // 1-dimension filter memory, write into all locations before read
    interface filter_in, filter_out, filter_out_addr
);
    parameter WIDTH_DATA = 13;
    parameter DEPTH_F = 5, ADDR_F = 3;
	parameter FL = 4, BL = 2;
    logic [WIDTH_DATA-1: 0] filter [DEPTH_F-1: 0];
    logic [ADDR_F-1: 0] waddr, raddr;
    logic [20: 0] filter_in_data;

    always begin
        for (int i = 0; i<DEPTH_F; i++) begin
            filter_in.Receive(filter_in_data);
            waddr = filter_in_data[12+ADDR_F:13];
            filter[waddr] = filter_in_data[12:0];
            #BL;
        end
    end
    
    always begin
        filter_out_addr.Receive(raddr);
        #FL;
        filter_out.Send(filter[raddr]);
        #BL;
    end
endmodule


module Ifmap_RF ( // 1-dimension ifmap memory
    interface ifmap_in, ifmap_out, ifmap_out_addr, load_done
);
    parameter WIDTH_DATA = 13;
    parameter DEPTH_I = 25, ADDR_I = 5;
	parameter FL = 4, BL = 2;
    logic [WIDTH_DATA-1: 0] ifmap [DEPTH_I-1: 0];
    logic [ADDR_I-1: 0] waddr, raddr;
    logic [20: 0] ifmap_in_data;

    always begin
        for (int i = 0; i<DEPTH_I; i++) begin
            ifmap_in.Receive(ifmap_in_data);
            waddr = ifmap_in_data[12+ADDR_I:13];
            ifmap[waddr] = ifmap_in_data[12:0];
            #BL;
        end
        load_done.Send(1);
    end

    always begin
        ifmap_out_addr.Receive(raddr);
        #FL;
        ifmap_out.Send(ifmap[raddr]);
        #BL;
    end
endmodule


module Psum_FIFO ( // psum fifo, store the psum_in in case psum_in arrives before all filter/ifmap are loaded and creates deadlock in PE split unit
    interface psum_fifo_in, psum_fifo_out
);
    parameter WIDTH_DATA = 13;
    parameter DEPTH_R = 3;
    parameter FL = 4, BL = 2;
    parameter ADDRX = 3'b0;
    logic [WIDTH_DATA-1:0] fifo [15:0];
    logic [WIDTH_DATA-1:0] psum_value;
    logic [3:0] wptr=0, rptr=0, depth=0;
    
    always begin
        psum_fifo_in.Receive(psum_value);
        fifo[wptr]=psum_value;
        wptr = wptr +1;
        depth = depth +1;
        #BL;
    end
    
    always begin
        #FL;
        if (depth>0) begin
            psum_fifo_out.Send(fifo[rptr]);
            rptr = rptr+1;
            depth = depth -1;
        end

        if (ADDRX==3'b0)
            psum_fifo_out.Send(13'b0);
    end
endmodule


module Control (
    interface acc_clear, split_sel, add_sel, filter_addr, ifmap_addr, load_done_I
);
    parameter DEPTH_F = 5, DEPTH_I = 25, DEPTH_R = 21;
	parameter FL = 4, BL = 2;
	logic load_done_sig_F, load_done_sig_I, test;

    always begin
        load_done_I.Receive(load_done_sig_I);
		#FL;
        for (int i = 0; i<DEPTH_R; i++) begin
            for (int j = 0; j<DEPTH_F; j++) begin
                fork
					split_sel.Send(0);
					add_sel.Send(0);
					acc_clear.Send(0);
					filter_addr.Send(j);
					ifmap_addr.Send(i+j);
            	join
            end
			fork
				split_sel.Send(1);
				add_sel.Send(1);
				acc_clear.Send(1);
			join
        end
    end
endmodule


module Multiplier (
    interface in0, in1, out
);
    parameter WIDTH_DATA = 5;
	parameter FL = 4, BL = 2;
    logic [WIDTH_DATA-1: 0] a, b, product;

    always begin
		fork
			in0.Receive(a);
        	in1.Receive(b);
		join
        product = a*b;
        #FL;
        out.Send(product);
        #BL;
    end
endmodule


module Adder (
    interface sel, a0, a1, b0, result
);
	parameter WIDTH_DATA = 5;
	parameter FL = 4, BL = 2;
    logic add_sel;
	logic [WIDTH_DATA-1: 0] a, b, sum;

    always begin
        sel.Receive(add_sel);
        fork
            begin
                if(add_sel)
                    a1.Receive(a);
                else
                    a0.Receive(a);
            end
            b0.Receive(b);
        join
        #FL;
        sum = a + b;
        result.Send(sum);
        #BL;
    end
endmodule


module Accumulator (
    interface in, out, clear
);
	parameter WIDTH_DATA = 5;
	parameter FL = 4, BL = 2;
    logic acc_clear;
	logic [WIDTH_DATA-1: 0] data;

    always begin
		clear.Receive(acc_clear);
		#FL;
        if (acc_clear)
            out.Send(0);
        else begin
            in.Receive(data);
            out.Send(data);
        end
        #BL;
    end
endmodule


module Split (
    interface sel, in, acc_out, psum_out
);
	parameter WIDTH_DATA = 5;
	parameter FL = 4, BL = 2;
    logic split_sel;
	logic [WIDTH_DATA-1: 0] data;

    always begin
        fork
            sel.Receive(split_sel);
            in.Receive(data);
        join
        #FL;
        if(split_sel)
            psum_out.Send(data);
        else
            acc_out.Send(data);
        #BL;
    end
endmodule


module PE (
    interface in, out
);
    parameter WIDTH_PKT = 32;
    parameter WIDTH_DATA = 13;
    parameter FL = 4, BL = 2;
    parameter DEPTH_F = 5, DEPTH_I = 25, DEPTH_R = 21;
    parameter ADDRX = 3'd0, ADDRY = 5'd0;
    logic [WIDTH_PKT-1: 0] pkt_in, pkt_out;
    logic [WIDTH_DATA-1: 0] psum_result;
    
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(21)) filter_in(), ifmap_in();
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(WIDTH_DATA)) psum_in(), psum_fifo_out(), psum_out();

    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1)) acc_clear(), add_sel(), split_sel(), load_done_I();
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(3)) filter_raddr();
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(5)) ifmap_raddr();
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(WIDTH_DATA)) filter_out(), ifmap_out(), mul_out(), adder_out(), acc_out(), acc_in();

	Filter_RF 	#(.WIDTH_DATA(WIDTH_DATA), .DEPTH_F(DEPTH_F), .ADDR_F(3), .FL(FL), .BL(BL))			
		filter_rf (.filter_in(filter_in), .filter_out(filter_out), .filter_out_addr(filter_raddr));
	Ifmap_RF 	#(.WIDTH_DATA(WIDTH_DATA), .DEPTH_I(DEPTH_I), .ADDR_I(5), .FL(FL), .BL(BL))
		ifmap_rf (.ifmap_in(ifmap_in), .ifmap_out(ifmap_out), .ifmap_out_addr(ifmap_raddr), .load_done(load_done_I));
    Psum_FIFO   #(.WIDTH_DATA(WIDTH_DATA), .DEPTH_R(DEPTH_R), .ADDRX(ADDRX))
        psum_fifo (.psum_fifo_in(psum_in), .psum_fifo_out(psum_fifo_out));
	Control 	#(.DEPTH_F(DEPTH_F), .DEPTH_I(DEPTH_I), .DEPTH_R(DEPTH_R), .FL(FL), .BL(BL))
		ctrl (.acc_clear(acc_clear), .split_sel(split_sel), .add_sel(add_sel), .filter_addr(filter_raddr), .ifmap_addr(ifmap_raddr), .load_done_I(load_done_I));
	Multiplier  #(.WIDTH_DATA(WIDTH_DATA), .FL(FL), .BL(BL))
		mul (.in0(filter_out), .in1(ifmap_out), .out(mul_out));
	Adder 		#(.WIDTH_DATA(WIDTH_DATA), .FL(FL), .BL(BL))
		adder (.sel(add_sel), .a0(mul_out), .a1(psum_fifo_out), .b0(acc_out), .result(adder_out));
	Accumulator #(.WIDTH_DATA(WIDTH_DATA), .FL(FL), .BL(BL))
		acc (.in(acc_in), .out(acc_out), .clear(acc_clear));
	Split 		#(.WIDTH_DATA(WIDTH_DATA), .FL(FL), .BL(BL))
		split (.sel(split_sel), .in(adder_out), .acc_out(acc_in), .psum_out(psum_out));

	initial begin
		acc.out.Send(0);
	end

    always begin
        in.Receive(pkt_in);
        #FL;
        case (pkt_in[30:29])
            2'b00: filter_in.Send(pkt_in[20:0]);
            2'b01: ifmap_in.Send(pkt_in[20:0]);
            2'b10: psum_in.Send(pkt_in[12:0]);
            // default: 
        endcase
        #BL;
    end

    // always begin // PE split unit
    //     in.Receive(pkt_in);
    //     #FL;
    //     if (pkt_in[31:29]==3'b000) begin // it's a filter data, also send in the src addr to decide its location in the memory
    //         filter_in.Send(pkt_in[20:0]);
    //     end
    //     else if (pkt_in[31:29]==3'b001) begin // it's a ifmap data, also send in the src addr
    //         ifmap_in.Send(pkt_in[20:0]);
    //     end
    //     else if (pkt_in[31:29]==3'b010) begin // it's a psum_in, no need to send in the src addr since it's a fifo
    //         psum_in.Send(pkt_in[12:0]);
    //     end
    //     #BL;
    // end

    // initial begin // for the PE on the 1st column, a psum_in = 0 should be provided
    //     if (ADDRX==3'b0) begin
    //         for (int i = 0; i<DEPTH_I-DEPTH_F+1; i++) begin
    //             psum_in.Send(13'b0);
    //         end
    //         for (int i = 0; i<DEPTH_I-DEPTH_F+1; i++) begin
    //             psum_in.Send(13'b0);
    //         end
    //     end
    // end

    always begin // decide the dst addr for the calculated psum_out
        psum_out.Receive(psum_result);
        if (ADDRX!=DEPTH_F[2:0]-3'd1) // this is still a partial result, send to the next PE on this line
            pkt_out = {3'b010, ADDRY, ADDRX+3'd1, ADDRY, ADDRX, psum_result};
        else // this is the final result, send to the result mem
            pkt_out = {3'b011, DEPTH_R[4:0], DEPTH_F[2:0]-3'd1, ADDRY, ADDRX, psum_result};
        out.Send(pkt_out);
    end
endmodule

    

//module data_bucket (interface in);
//    parameter WIDTH = 8;
//    parameter BL = 0;
//    logic [WIDTH-1:0] ReceiveValue = 0;
//    always begin
//        in.Receive(ReceiveValue);
//        #BL;
//    end
//endmodule


//module PE_tb;
//    parameter WIDTH_PKT = 32;

//    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(WIDTH_PKT)) in(), out();

//    PE #(.WIDTH_PKT(WIDTH_PKT), .WIDTH_DATA(32)) pe(in, out);
//    data_bucket db(out);

//    initial begin
//        // load filter
//        in.Send({3'b000, 8'b0, 8'd0, 13'd10});
//        in.Send({3'b000, 8'b0, 8'd1, 13'd10});
//        in.Send({3'b000, 8'b0, 8'd2, 13'd10});
//        in.Send({3'b000, 8'b0, 8'd3, 13'd10});
//        in.Send({3'b000, 8'b0, 8'd4, 13'd10});

//        // load ifmap
//        in.Send({3'b001, 8'b0, 8'd0, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd1, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd2, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd3, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd4, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd5, 13'd0});
//        in.Send({3'b001, 8'b0, 8'd6, 13'd0});
//        in.Send({3'b001, 8'b0, 8'd7, 13'd0});
//        in.Send({3'b001, 8'b0, 8'd8, 13'd0});
//        in.Send({3'b001, 8'b0, 8'd9, 13'd0});
//        in.Send({3'b001, 8'b0, 8'd10, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd11, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd12, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd13, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd14, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd15, 13'd0});
//        in.Send({3'b001, 8'b0, 8'd16, 13'd0});
//        in.Send({3'b001, 8'b0, 8'd17, 13'd0});
//        in.Send({3'b001, 8'b0, 8'd18, 13'd0});
//        in.Send({3'b001, 8'b0, 8'd19, 13'd0});
//        in.Send({3'b001, 8'b0, 8'd20, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd21, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd22, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd23, 13'd1});
//        in.Send({3'b001, 8'b0, 8'd24, 13'd1});

//        // load psum
//        in.Send({3'b010, 8'b0, 8'b0, 13'd1});
//        in.Send({3'b010, 8'b0, 8'b0, 13'd2});
//        in.Send({3'b010, 8'b0, 8'b0, 13'd3});
//        in.Send({3'b010, 8'b0, 8'b0, 13'd4});
//        in.Send({3'b010, 8'b0, 8'b0, 13'd5});
//        in.Send({3'b010, 8'b0, 8'b0, 13'd6});

//        #100;
//        $stop;
//    end
//endmodule