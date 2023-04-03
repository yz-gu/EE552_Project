`timescale 1ns / 1ps
import SystemVerilogCSP::*;


module Filter_RF ( // 1-dimension filter memory, write into all locations before read
    interface filter_in, filter_out, filter_out_addr, load_done
);
    parameter WIDTH_DATA = 13;
    parameter LEN_F = 5, ADDR_F = 3;
	parameter FL = 4, BL = 2;
    logic [WIDTH_DATA-1: 0] filter [LEN_F-1: 0];
    logic [ADDR_F-1: 0] waddr, raddr;
    logic [20: 0] filter_in_data;

    always begin
        for (int i = 0; i<LEN_F; i++) begin
            filter_in.Receive(filter_in_data);
            #1;
            waddr = filter_in_data[12+ADDR_F:13];
            filter[waddr] = filter_in_data[12:0];
        end
        load_done.Send(1);
    end
    
    always begin
        // for (int i = 0; i<LEN_F; i++) begin
            filter_out_addr.Receive(raddr);
            #FL;
            filter_out.Send(filter[raddr]);
            #BL;
        // end
        // for (int i = 0; i<LEN_F; i++) begin
        //     filter[i] = 0;
        // end
    end
endmodule


module Ifmap_RF ( // 1-dimension ifmap memory
    interface ifmap_in, ifmap_out, ifmap_out_addr, load_done
);
    parameter WIDTH_DATA = 13;
    parameter LEN_I = 25, ADDR_I = 5;
	parameter FL = 4, BL = 2;
    logic [WIDTH_DATA-1: 0] ifmap [LEN_I-1: 0];
    logic [ADDR_I-1: 0] waddr, raddr;
    logic [20: 0] ifmap_in_data;

    always begin
        for (int i = 0; i<LEN_I; i++) begin
            ifmap_in.Receive(ifmap_in_data);
            #1;
            waddr = ifmap_in_data[12+ADDR_I:13];
            ifmap[waddr] = ifmap_in_data[12:0];
        end
        load_done.Send(1);
    end

    always begin
        // for (int i = 0; i<LEN_I; i++) begin
            ifmap_out_addr.Receive(raddr);
            #FL;
            ifmap_out.Send(ifmap[raddr]);
            #BL;
        // end
        // for (int i = 0; i<LEN_I; i++) begin
        //     ifmap[i] = 0;
        // end
    end
endmodule


module Psum_FIFO ( // psum fifo, store the psum_in in case psum_in arrives before all filter/ifmap are loaded and creates deadlock in PE split unit
    interface psum_fifo_in, psum_fifo_out
);
    parameter WIDTH_DATA = 13;
    parameter NUM_LOOPS = 3;
    logic [WIDTH_DATA-1:0] fifo [15:0];
    logic [WIDTH_DATA-1:0] psum_value;
    logic [3:0] wptr=0, rptr=0, depth=0;
    
    always begin
        psum_fifo_in.Receive(psum_value);
        fifo[wptr]=psum_value;
        wptr = wptr +1;
        depth = depth +1;
        #1;
    end
    
    always begin
        if (depth>0) begin
            psum_fifo_out.Send(fifo[rptr]);
            rptr = rptr+1;
            depth = depth -1;
        end
        else
            #5;
    end
endmodule


module Control (
    interface acc_clear, split_sel, add_sel, filter_addr, ifmap_addr, load_done_F, load_done_I
);
    parameter LEN_F = 5, LEN_I = 25;
	parameter FL = 4, BL = 2;
	int NUM_ITER = LEN_I-LEN_F+1;
	logic load_done_sig_F, load_done_sig_I;

    always begin
        fork
            load_done_F.Receive(load_done_sig_F);
            load_done_I.Receive(load_done_sig_I);
        join
		#FL;
        for (integer i = 0; i<NUM_ITER; i++) begin
            for (integer j = 0; j<LEN_F; j++) begin
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
    parameter LEN_F = 5, LEN_I = 25;
    parameter ADDRX = 3'd0, ADDRY = 5'd0;
    logic [WIDTH_PKT-1: 0] pkt_in, pkt_out;
    logic [WIDTH_DATA-1: 0] psum_result;
    
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(21)) filter(), ifmap();
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(WIDTH_DATA)) psum_in(), psum_fifo_out(), psum_out();

    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1)) acc_clear(), add_sel(), split_sel(), load_done_F(), load_done_I();
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(2)) filter_raddr();
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(3)) ifmap_raddr();
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(WIDTH_DATA)) filter_out(), ifmap_out(), mul_out(), adder_out(), acc_out(), acc_in();

	Filter_RF 	#(.WIDTH_DATA(WIDTH_DATA), .LEN_F(LEN_F), .ADDR_F(2), .FL(FL), .BL(BL))			
		filter_rf (.filter_in(filter), .filter_out(filter_out), .filter_out_addr(filter_raddr), .load_done(load_done_F));
	Ifmap_RF 	#(.WIDTH_DATA(WIDTH_DATA), .LEN_I(LEN_I), .ADDR_I(3), .FL(FL), .BL(BL))
		ifmap_rf (.ifmap_in(ifmap), .ifmap_out(ifmap_out), .ifmap_out_addr(ifmap_raddr), .load_done(load_done_I));
    Psum_FIFO   #(.WIDTH_DATA(WIDTH_DATA), .NUM_LOOPS(LEN_I-LEN_F+1))
        psum_fifo (.psum_fifo_in(psum_in), .psum_fifo_out(psum_fifo_out));
	Control 	#(.LEN_F(LEN_F), .LEN_I(LEN_I), .FL(FL), .BL(BL))
		ctrl(.acc_clear(acc_clear), .split_sel(split_sel), .add_sel(add_sel), .filter_addr(filter_raddr), .ifmap_addr(ifmap_raddr), .load_done_F(load_done_F), .load_done_I(load_done_I));
	Multiplier  #(.WIDTH_DATA(WIDTH_DATA), .FL(FL), .BL(BL))
		mul(.in0(filter_out), .in1(ifmap_out), .out(mul_out));
	Adder 		#(.WIDTH_DATA(WIDTH_DATA), .FL(FL), .BL(BL))
		adder(.sel(add_sel), .a0(mul_out), .a1(psum_fifo_out), .b0(acc_out), .result(adder_out));
	Accumulator #(.WIDTH_DATA(WIDTH_DATA), .FL(FL), .BL(BL))
		acc(.in(acc_in), .out(acc_out), .clear(acc_clear));
	Split 		#(.WIDTH_DATA(WIDTH_DATA), .FL(FL), .BL(BL))
		split(.sel(split_sel), .in(adder_out), .acc_out(acc_in), .psum_out(psum_out));

	initial begin
		acc.out.Send(0);
	end


    // always begin
    //     in.Receive(pkt_in);
    //     #FL;
    //     case (pkt_in[30:29])
    //         2'b00: filter_in.Send(pkt_in[20:0]);
    //         2'b01: ifmap_in.Send(pkt_in[20:0]);
    //         2'b10: psum_in.Send(pkt_in[12:0]);
    //         // default: 
    //     endcase
    //     #BL;
    // end

    always begin // PE split unit
        in.Receive(pkt_in);
        #FL;
        if (pkt_in[31:29]==3'b000) begin // it's a filter data, also send in the src addr to decide its location in the memory
            filter.Send(pkt_in[20:0]);
        end
        else if (pkt_in[31:29]==3'b001) begin // it's a ifmap data, also send in the src addr
            ifmap.Send(pkt_in[20:0]);
        end
        else if (pkt_in[31:29]==3'b010) begin // it's a psum_in, no need to send in the src addr since it's a fifo
            psum_in.Send(pkt_in[12:0]);
        end
        #BL;
    end

    initial begin // for the PE on the 1st column, a psum_in = 0 should be provided
        if (ADDRX==3'b0) begin
            for (int i = 0; i<LEN_I-LEN_F+1; i++) begin
                psum_in.Send(13'b0);
            end
        end
    end

    reg [4:0] counter = 0;
    reg [7:0] src_addr;
    always begin // decide the dst addr for the calculated psum_out
        psum_out.Receive(psum_result);
        if(ADDRX!=3'd2) // this is still a partial result, send to the next PE on this line
            pkt_out = {3'b010, ADDRY, {ADDRX+3'b1}, ADDRY, ADDRX, psum_result};
        else begin// this is the final result, send to the result mem
            src_addr = ADDRY*(LEN_I-LEN_F+1) + counter;
            pkt_out = {3'b011, 5'd3, 3'd2, src_addr, psum_result};
            counter = counter + 1;
        end
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