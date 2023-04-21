`timescale 1ns/1ps

import SystemVerilogCSP::*;


module noc_snn(
	interface filter_data, filter_addr, ifmap_data, ifmap_addr, ref_spike
);

	parameter WIDTH_PKT = 32;
	parameter WIDTH_DATA = 13;
	parameter THRE = 64;
	parameter DEPTH_F = 5;
	parameter DEPTH_I = 25;
	parameter DEPTH_R = DEPTH_I - DEPTH_F + 1;

// The following 2d channel is not supported by some compiler
//	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_l [DEPTH_F:0] [DEPTH_R-1:0] ();
//	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_r [DEPTH_F:0] [DEPTH_R-1:0] ();
//	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_u [DEPTH_F-1:0] [DEPTH_R:0] ();
//	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_d [DEPTH_F-1:0] [DEPTH_R:0] ();
//	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_pi [DEPTH_F-1:0] [DEPTH_R-1:0] ();
//	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_p1 [DEPTH_F-1:0] [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_l0 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_l1 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_l2 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_l3 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_l4 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_l5 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_r0 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_r1 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_r2 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_r3 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_r4 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_r5 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_u0 [DEPTH_R:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_u1 [DEPTH_R:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_u2 [DEPTH_R:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_u3 [DEPTH_R:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_u4 [DEPTH_R:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_d0 [DEPTH_R:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_d1 [DEPTH_R:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_d2 [DEPTH_R:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_d3 [DEPTH_R:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_d4 [DEPTH_R:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_pi0 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_pi1 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_pi2 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_pi3 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_pi4 [DEPTH_R-1:0] ();
    Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_po0 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_po1 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_po2 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_po3 [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_po4 [DEPTH_R-1:0] ();

	// Both filter-mem and ifmap-mem is connected to the top-left node
	Filter_mem #(.WIDTH_DATA(WIDTH_DATA), .DEPTH_F(DEPTH_F), .WIDTH_F(DEPTH_F), .FL(12), .BL(4))
		f_mem (.filter_in(filter_data), .filter_in_addr(filter_addr), .filter_out(intf_d0[0]));
	Ifmap_mem #(.WIDTH_DATA(1), .DEPTH_I(DEPTH_I), .WIDTH_I(DEPTH_I), .FL(12), .BL(4), .DEPTH_R(DEPTH_R))
		i_mem (.ifmap_in(ifmap_data), .ifmap_in_addr(ifmap_addr), .ifmap_out(intf_r0[0]));
	// instantiate the mesh with 21*5 nodes, each node contains a Router and a PE
	genvar i, j; // Mesh
	generate
//		for (i = 0; i<DEPTH_F; i++) begin
//			for (j = 0; j<DEPTH_R; j++) begin
//				Router #(.WIDTH_PKT(32), .ADDRX(i[2:0]), .ADDRY(j[4:0]), .DEPTH_R(DEPTH_R), .DEPTH_F(DEPTH_F))
//					router (.left_in(intf_r[i][j]), .left_out(intf_l[i][j]),
//						.right_in(intf_l[i+1][j]), .right_out(intf_r[i+1][j]),
//						.up_in(intf_d[i][j]), .up_out(intf_u[i][j]),
//						.down_in(intf_u[i][j+1]), .down_out(intf_d[i][j+1]),
//						.local_in(intf_pi[i][j]), .local_out(intf_p1[i][j]));
//				PE #(.WIDTH_PKT(WIDTH_PKT), .WIDTH_DATA(WIDTH_DATA), .DEPTH_F(DEPTH_F), .DEPTH_I(DEPTH_I), .DEPTH_R(DEPTH_R), .ADDRX(i[2:0]), .ADDRY(j[4:0]), .FL(4), .BL(2))
//					pe (.in(intf_po[i][j]), .out(intf_pi[i][j]));
//			end
//		end
        for (j = 0; j<DEPTH_R; j++) begin
            Router #(.WIDTH_PKT(32), .ADDRX(3'd0), .ADDRY(j[4:0]), .DEPTH_R(DEPTH_R), .DEPTH_F(DEPTH_F))
                router0 (.left_in(intf_r0[j]), .left_out(intf_l0[j]), .right_in(intf_l1[j]), .right_out(intf_r1[j]), .up_in(intf_d0[j]), .up_out(intf_u0[j]),  .down_in(intf_u0[j+1]), .down_out(intf_d0[j+1]), .local_in(intf_pi0[j]), .local_out(intf_po0[j]));
            PE #(.WIDTH_PKT(WIDTH_PKT), .WIDTH_DATA(WIDTH_DATA), .DEPTH_F(DEPTH_F), .DEPTH_I(DEPTH_I), .DEPTH_R(DEPTH_R), .ADDRX(3'd0), .ADDRY(j[4:0]), .FL(4), .BL(2))
                pe0 (.in(intf_po0[j]), .out(intf_pi0[j]));
            Router #(.WIDTH_PKT(32), .ADDRX(3'd1), .ADDRY(j[4:0]), .DEPTH_R(DEPTH_R), .DEPTH_F(DEPTH_F))
                router1 (.left_in(intf_r1[j]), .left_out(intf_l1[j]), .right_in(intf_l2[j]), .right_out(intf_r2[j]), .up_in(intf_d1[j]), .up_out(intf_u1[j]),  .down_in(intf_u1[j+1]), .down_out(intf_d1[j+1]), .local_in(intf_pi1[j]), .local_out(intf_po1[j]));
            PE #(.WIDTH_PKT(WIDTH_PKT), .WIDTH_DATA(WIDTH_DATA), .DEPTH_F(DEPTH_F), .DEPTH_I(DEPTH_I), .DEPTH_R(DEPTH_R), .ADDRX(3'd1), .ADDRY(j[4:0]), .FL(4), .BL(2))
                pe1 (.in(intf_po1[j]), .out(intf_pi1[j]));
            Router #(.WIDTH_PKT(32), .ADDRX(3'd2), .ADDRY(j[4:0]), .DEPTH_R(DEPTH_R), .DEPTH_F(DEPTH_F))
                router2 (.left_in(intf_r2[j]), .left_out(intf_l2[j]), .right_in(intf_l3[j]), .right_out(intf_r3[j]), .up_in(intf_d2[j]), .up_out(intf_u2[j]),  .down_in(intf_u2[j+1]), .down_out(intf_d2[j+1]), .local_in(intf_pi2[j]), .local_out(intf_po2[j]));
            PE #(.WIDTH_PKT(WIDTH_PKT), .WIDTH_DATA(WIDTH_DATA), .DEPTH_F(DEPTH_F), .DEPTH_I(DEPTH_I), .DEPTH_R(DEPTH_R), .ADDRX(3'd2), .ADDRY(j[4:0]), .FL(4), .BL(2))
                pe2 (.in(intf_po2[j]), .out(intf_pi2[j]));
            Router #(.WIDTH_PKT(32), .ADDRX(3'd3), .ADDRY(j[4:0]), .DEPTH_R(DEPTH_R), .DEPTH_F(DEPTH_F))
                router3 (.left_in(intf_r3[j]), .left_out(intf_l3[j]), .right_in(intf_l4[j]), .right_out(intf_r4[j]), .up_in(intf_d3[j]), .up_out(intf_u3[j]),  .down_in(intf_u3[j+1]), .down_out(intf_d3[j+1]), .local_in(intf_pi3[j]), .local_out(intf_po3[j]));
            PE #(.WIDTH_PKT(WIDTH_PKT), .WIDTH_DATA(WIDTH_DATA), .DEPTH_F(DEPTH_F), .DEPTH_I(DEPTH_I), .DEPTH_R(DEPTH_R), .ADDRX(3'd3), .ADDRY(j[4:0]), .FL(4), .BL(2))
                pe3 (.in(intf_po3[j]), .out(intf_pi3[j]));
            Router #(.WIDTH_PKT(32), .ADDRX(3'd4), .ADDRY(j[4:0]), .DEPTH_R(DEPTH_R), .DEPTH_F(DEPTH_F))
                router4 (.left_in(intf_r4[j]), .left_out(intf_l4[j]), .right_in(intf_l5[j]), .right_out(intf_r5[j]), .up_in(intf_d4[j]), .up_out(intf_u4[j]),  .down_in(intf_u4[j+1]), .down_out(intf_d4[j+1]), .local_in(intf_pi4[j]), .local_out(intf_po4[j]));
            PE #(.WIDTH_PKT(WIDTH_PKT), .WIDTH_DATA(WIDTH_DATA), .DEPTH_F(DEPTH_F), .DEPTH_I(DEPTH_I), .DEPTH_R(DEPTH_R), .ADDRX(3'd4), .ADDRY(j[4:0]), .FL(4), .BL(2))
                pe4 (.in(intf_po4[j]), .out(intf_pi4[j]));
        end
	endgenerate
	// The result mem is connected to the bottom-right node
	Result_mem #(.WIDTH_PKT(WIDTH_PKT), .WIDTH_DATA(WIDTH_DATA), .DEPTH_R(DEPTH_R), .THRE(THRE))
	   r_mem (.in(intf_d4[DEPTH_R]), .ref_in(ref_spike));
endmodule


module noc_snn_tb;

	// parameters
	parameter WIDTH_PKT = 32;
	// parameter WIDTH_addr = 12;
	parameter WIDTH_DATA = 13;
	parameter DEPTH_F = 5;
	parameter DEPTH_I = 25;
	parameter THRE = 64;
	parameter DEPTH_R = DEPTH_I - DEPTH_F + 1;

	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(5)) filter_addr();
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(7)) filter_data();
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(10)) ifmap_addr();
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1)) ifmap_data();
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1)) ref_spike();

	noc_snn #(.WIDTH_PKT(WIDTH_PKT), .WIDTH_DATA(WIDTH_DATA), .DEPTH_F(DEPTH_F), .DEPTH_I(DEPTH_I), .THRE(THRE))
		dut(.filter_data(filter_data), .filter_addr(filter_addr), .ifmap_data(ifmap_data), .ifmap_addr(ifmap_addr), .ref_spike(ref_spike)
	); 
	
	logic [4:0] f_addr = 0;
	logic [7:0] f_data;
	logic [9:0] i1_addr = 0, i2_addr = 0;
	logic i1_data, i2_data;
	logic [8:0] r1_addr = 0, r2_addr = 0;
	logic [12:0] r1_data, r2_data;

	integer fpi_f, fpi_i1, fpi_i2, fpi_r1, fpi_r2;
	integer status;
	
	// watchdog timer
	initial begin
		#100000;
		$display("*** Stopped by watchdog timer ***");
		$finish;
	end
	
	initial begin
		fpi_f = $fopen("filter.txt","r");
		fpi_i1 = $fopen("ifmap1.txt","r");
		fpi_i2 = $fopen("ifmap2.txt", "r");
		fpi_r1 = $fopen("out_spike1.txt", "r");
		fpi_r2 = $fopen("out_spike2.txt", "r");
		// fpi_f = $fopen("test_filter.txt","r");
		// fpi_i1 = $fopen("test_ifmapo.txt","r");
		// fpi_i2 = $fopen("test_ifmap2.txt", "r");

		if(!fpi_f || !fpi_i1 || !fpi_i2 || !fpi_r1 || !fpi_r2) begin
			$display("A file cannot be opened!");
			$finish;
		end
		else begin
			for(int i=0; i<DEPTH_F**2; i++) begin
				if(!$feof(fpi_f)) begin
					status = $fscanf(fpi_f,"%d\n", f_data);
					filter_addr.Send(f_addr);
					filter_data.Send(f_data);
					f_addr++;
				end
			end
			
			// timestepo
			for(int i=0; i<DEPTH_I**2; i++) begin
				if (!$feof(fpi_i1)) begin
					status = $fscanf(fpi_i1,"%d\n", i1_data);
					ifmap_addr.Send(i1_addr);
					ifmap_data.Send(i1_data);
					i1_addr++;
				end
			end
			for(int i=0; i<DEPTH_R**2; i++) begin
				if (!$feof(fpi_r1)) begin
					status = $fscanf(fpi_r1,"%d\n", r1_data);
					ref_spike.Send(r1_data);
				end
			end

			wait(dut.r_mem.done == 1);

			// timestep2
			for(int i=0; i<DEPTH_I**2; i++) begin
				if (!$feof(fpi_i2)) begin
					status = $fscanf(fpi_i2,"%d\n", i2_data);
					ifmap_addr.Send(i2_addr);
					ifmap_data.Send(i2_data);
					i2_addr++;
				end
			end
			for(int i=0; i<DEPTH_R**2; i++) begin
				if (!$feof(fpi_r2)) begin
					status = $fscanf(fpi_r2,"%d\n", r2_data);
					ref_spike.Send(r2_data);
				end
			end
		end
	end
endmodule
