`timescale 1ns/1ps

import SystemVerilogCSP::*;


module noc_snn(
	interface filter_data, filter_addr, ifmap_data, ifmap_addr
	// timestep, start_r, ts_r, layer_r, done_r, out_spike_addr, out_spike_data
);

	parameter WIDTH_PKT = 32;
	parameter WIDTH_DATA = 13;
	parameter THRE = 64;
	parameter DEPTH_F = 5;
	parameter DEPTH_I = 25;
	parameter DEPTH_R = DEPTH_I - DEPTH_F + 1;

	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_l [DEPTH_F:0] [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_r [DEPTH_F:0] [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_u [DEPTH_F-1:0] [DEPTH_R:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_d [DEPTH_F-1:0] [DEPTH_R:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_p0 [DEPTH_F-1:0] [DEPTH_R-1:0] ();
	Channel #(.hsProtocol(P4PhaseBD),.WIDTH(WIDTH_PKT)) intf_p1 [DEPTH_F-1:0] [DEPTH_R-1:0] ();

	// Both filter-mem and ifmap-mem is connected to the top-left node
	Filter_mem #(.WIDTH_DATA(WIDTH_DATA), .DEPTH_F(DEPTH_F), .WIDTH_F(DEPTH_F), .FL(12), .BL(4))
		f_mem (.filter_in(filter_data), .filter_in_addr(filter_addr), .filter_out(intf_d[0][0]));
	Ifmap_mem #(.WIDTH_DATA(WIDTH_DATA), .DEPTH_I(DEPTH_I), .WIDTH_I(DEPTH_I), .FL(12), .BL(4), .DEPTH_R(DEPTH_R))
		i_mem (.ifmap_in(ifmap_data), .ifmap_in_addr(ifmap_addr), .ifmap_out(intf_r[0][0]));
	// instantiate the mesh with 21*5 nodes, each node contains a Router and a PE
	genvar i, j; // Mesh
	generate
		for (i = 0; i<DEPTH_F; i++) begin
			for (j = 0; j<DEPTH_R; j++) begin
				Router #(.WIDTH_PKT(32), .ADDRX(i[2:0]), .ADDRY(j[4:0]), .DEPTH_R(DEPTH_R), .DEPTH_F(DEPTH_F))
					router (.left_in(intf_r[i][j]), .left_out(intf_l[i][j]),
						.right_in(intf_l[i+1][j]), .right_out(intf_r[i+1][j]),
						.up_in(intf_d[i][j]), .up_out(intf_u[i][j]),
						.down_in(intf_u[i][j+1]), .down_out(intf_d[i][j+1]),
						.local_in(intf_p0[i][j]), .local_out(intf_p1[i][j]));
				PE #(.WIDTH_PKT(WIDTH_PKT), .WIDTH_DATA(WIDTH_DATA), .DEPTH_F(DEPTH_F), .DEPTH_I(DEPTH_I), .DEPTH_R(DEPTH_R), .ADDRX(i[2:0]), .ADDRY(j[4:0]), .FL(4), .BL(2))
					pe (.in(intf_p1[i][j]), .out(intf_p0[i][j]));
			end
		end
	endgenerate
	// The result mem is connected to the bottom-right node
	Result_mem #(.WIDTH_PKT(WIDTH_PKT), .WIDTH_DATA(WIDTH_DATA), .DEPTH_R(DEPTH_R), .THRE(THRE))
	   r_mem (.in(intf_d[DEPTH_F-1][DEPTH_R]));


	// main execution
	// initial begin

	// 	fpi_out1 = $fopen("out_spike1_sim.txt","r");
	// 	fpi_out2 = $fopen("out_spike2_sim.txt","r");

		// sending to the memory filter and feature map

		// load_start.Receive(l_st);
		// if (l_st==1) begin
		// 	for(integer i=0; i<DEPTH_F*DEPTH_F; i++) begin
		// 		filter_addr.Receive(f_addr);
		// 		filter_data.Receive(f_data);
		// 		mem_filter[f_addr] = f_data;
		// 		$display("Filter receives %d at %d", f_data, f_addr);
		// 	end

		// 	//timestep.Receive(ts);

		// 	for(integer i=0; i<DEPTH_I*DEPTH_I; i++) begin
		// 		timestep.Receive(ts);
		// 		if (ts == 1) begin
		// 			ifmap_addr.Receive(i1_addr);
		// 			ifmap_data.Receive(i1_data);
		// 			mem_ifmap_1[i1_addr] = i1_data;
		// 			$display("Timestep %d: receive %d at %d", ts, i1_data, i1_addr);
		// 		end
		// 	end

		// 	for(integer i=0; i<DEPTH_I*DEPTH_I; i++) begin
		// 		timestep.Receive(ts);
		// 		if (ts == 2) begin
		// 			ifmap_addr.Receive(i2_addr);
		// 			ifmap_data.Receive(i2_data);
		// 			mem_ifmap_2[i2_addr] = i2_data;
		// 			$display("Timestep %d: receive %d at %d", ts, i2_data, i2_addr);
		// 		end
		// 	end
		// end

		// load_done.Receive(load_dn);
		// if (load_dn==1) begin
		// 	$display("Successfully load all ifmaps and filter!");
		// end

		// //loading fake output spikes
		// 	for(integer i=0; i<(DEPTH_R*DEPTH_R); i++) begin
		// 		if(!$feof(fpi_out1)) begin
		// 			status = $fscanf(fpi_out1,"%d\n", out_data);
		// 			mem_out_1[i] = out_data;
		// 		end
		// 	end

		// 	for(integer i=0; i<(DEPTH_R*DEPTH_R); i++) begin
		// 		if(!$feof(fpi_out2)) begin
		// 			status = $fscanf(fpi_out2,"%d\n", out_data);
		// 			mem_out_2[i] = out_data;
		// 		end
		// 	end

		// // sending out_spike_1
		// start_r.Send(1);
		// ts_r.Send(1);
		// layer_r.Send(1);
	
		// for(integer i=0; i<DEPTH_R*DEPTH_R; i++) begin
		// 	out_spike_addr.Send(out_addr);
		// 	out_spike_data.Send(mem_out_1[out_addr]);
		// 	out_addr++;
		// 	$display("Send out spike 1: addr: %d, data: 1", out_addr);
		// end

		// // sending out_spike_2
		// ts_r.Send(2);
		// layer_r.Send(1);
		
		// out_addr=0;
		// for(integer i=0; i<DEPTH_R*DEPTH_R; i++) begin
		// 	out_spike_addr.Send(out_addr);
		// 	out_spike_data.Send(mem_out_2[out_addr]);
		// 	out_addr++;
		// 	$display("Send out spike 1: addr: %d, data: 0", out_addr);
		// end
		// done_r.Send(1);
	// end
endmodule


module noc_snn_tb;

	// parameters
	parameter WIDTH_PKT = 32;
	// parameter WIDTH_addr = 12;
	parameter WIDTH_DATA = 13;
	parameter DEPTH_F = 5;
	parameter DEPTH_I = 25;
	parameter THRE = 64;

	// logic i1_data, i2_data, dn, st, s_r;
	// logic [1:0] ts=1, l_index;
	// logic [WIDTH_PKT-1:0] f_data;
	// logic [WIDTH_addr-1:0] i1_addr = 0, i2_addr=0, f_addr=0, out_addr;
	// logic [WIDTH_out_data-1:0] out_data;
	// logic [WIDTH_out_data-1:0] comp1[DEPTH_R*DEPTH_R-1:0];
	// logic [WIDTH_out_data-1:0] comp2[DEPTH_R*DEPTH_R-1:0];

	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(5)) filter_addr();
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(7)) filter_data();
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(10)) ifmap_addr();
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1)) ifmap_data();

	noc_snn #(.WIDTH_PKT(WIDTH_PKT), .WIDTH_DATA(WIDTH_DATA), .DEPTH_F(DEPTH_F), .DEPTH_I(DEPTH_I), .THRE(THRE))
		dut(.filter_data(filter_data), .filter_addr(filter_addr), .ifmap_data(ifmap_data), .ifmap_addr(ifmap_addr)
		// .timestep(intf[2]), .ts_r(intf[6]), .layer_r(intf[7]), .done_r(intf[8]), .out_spike_addr(intf[9]), .out_spike_data(intf[10]), , .start_r(intf[12])
	); 
	
	logic [4:0] f_addr = 0;
	logic [7:0] f_data;
	logic [9:0] i1_addr = 0, i2_addr = 0;
	logic i1_data, i2_data;

	integer fpi_f, fpi_i1, fpi_i2;
	integer status;
	// integer error_count, fpt, fpi_i2, fpi_out1, fpi_out2, fpo, status;
	
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
		// fpi_f = $fopen("test_filter.txt","r");
		// fpi_i1 = $fopen("test_ifmap1.txt","r");
		// fpi_i2 = $fopen("test_ifmap2.txt", "r");
		// fpi_out1 = $fopen("out_spike1.txt","r");
		// fpi_out2 = $fopen("out_spike2.txt","r");
		// fpo = $fopen("test.dump","w");
		// fpt = $fopen("transcript.dump");

		if(!fpi_f || !fpi_i1 || !fpi_i2) begin
			$display("A file cannot be opened!");
			$finish;
		end

		//sending to the memory filter and feature map
		else begin
			// load_start.Send(1);
			for(integer i=0; i<DEPTH_F*DEPTH_F; i++) begin
				if(!$feof(fpi_f)) begin
					status = $fscanf(fpi_f,"%d\n", f_data);
					// $display("filter data read:%d", f_data);
					filter_addr.Send(f_addr);
					filter_data.Send(f_data);
					f_addr++;
				end
			end
			
			// sending ifmap 1 (timestep1)
			for(integer i=0; i<DEPTH_I*DEPTH_I; i++) begin
				if (!$feof(fpi_i1)) begin
					status = $fscanf(fpi_i1,"%d\n", i1_data);
					// $display("Ifmap1 data read:%d", i1_data);
					ifmap_addr.Send(i1_addr);
					ifmap_data.Send(i1_data);
					i1_addr++;
				end
			end

			wait(dut.r_mem.done == 1);

			// sending ifmap 2 (timestep2)
			for(integer i=0; i<DEPTH_I*DEPTH_I; i++) begin
				if (!$feof(fpi_i2)) begin
					status = $fscanf(fpi_i2,"%d\n", i2_data);
					// $display("Ifmap2 data read:%d", i2_data);
					ifmap_addr.Send(i2_addr);
					ifmap_data.Send(i2_data);
					i2_addr++;
				end
			end
		end

		// $fdisplay(fpt,"%m sent load_done token at %t",$realtime);
		$display("%m sent load_done token at %t",$realtime);
		
		#1000;
//		$stop;

		// // waiting for the signal indicating the start of receiving outputs
		// start_r.Receive(s_r);
		// $timeformat(-9, 4, "ns");
		// $display("tb: start_r Received at %t", $realtime);
		// $fdisplay(fpt,"%m start_r token received at %t",$realtime);

		// // comparing results
		// error_count=0;

		// if (s_r ==1) begin

		// 	ts_r.Receive(ts);
		// 	layer_r.Receive(l_index);
		// 	$display("Received timestep %d, layer, %d", ts, l_index);
			
		// 	if (ts ==1 && l_index ==1) begin
		// 		// load golden result: output_spike 1
		// 		for(integer i=0; i<(DEPTH_R*DEPTH_R); i++) begin
		// 			if(!$feof(fpi_out1)) begin
		// 			status = $fscanf(fpi_out1,"%d\n", out_data);
		// 			$display("GodenResult data read (output_spike 1):%d", out_data);
		// 			comp1[i] = out_data;
		// 			$fdisplay(fpt,"comp1[%d]= %d",i,out_data); 
		// 			end
		// 		end

		// 		// compare results
		// 		for (integer i = 0; i<DEPTH_R*DEPTH_R; i++) begin
		// 			// timestep 1
		// 			out_spike_addr.Receive(out_addr);
		// 			out_spike_data.Receive(out_data);
					
		// 			if (out_data != comp1[out_addr]) begin
		// 				$fdisplay(fpo,"%d != %d error!",out_data,comp1[i]);
		// 				$fdisplay(fpt,"%d != %d error!",out_data,comp1[i]);
		// 				$display("%d != %d error!",out_data,comp1[i]);
		// 				//    		$fdisplay(fpt,"%d == comp[%d] = %d", out_data, i, comp1[i]);
		// 				//    		$fdisplay(fpo," %d == comp[%d] = %d", out_data, i, comp1[i]);
		// 				error_count++;
		// 			end
		// 			else begin
		// 				$fdisplay(fpt,"%d == comp1[%d] = %d", out_data, i, comp1[i]);
		// 				$fdisplay(fpo,"%d == comp1[%d] = %d", out_data, i, comp1[i]);
		// 				$display("Passing comparison! Receive result value : %d at %t",out_data, $realtime);
		// 			end
		// 		end
		// 	end

		// 	# 2;
		// 	ts_r.Receive(ts);
		// 	layer_r.Receive(l_index);

		// 	if (ts ==2 && l_index ==1) begin
		// 		// load golden result: output_spike 2
		// 		for(integer i=0; i<(DEPTH_R*DEPTH_R); i++) begin
		// 			if(!$feof(fpi_out2)) begin
		// 			status = $fscanf(fpi_out2,"%d\n", out_data);
		// 			$display("GodenResult data read (output_spike 2):%d", out_data);
		// 			comp2[i] = out_data;
		// 			$fdisplay(fpt,"comp2[%d]= %d",i,out_data); 
		// 		end end

		// 		// compare results
		// 		for (integer i = 0; i<DEPTH_R*DEPTH_R; i++) begin
		// 			// timestep 1
		// 			out_spike_addr.Receive(out_addr);
		// 			out_spike_data.Receive(out_data);
					
		// 			if (out_data != comp2[out_addr]) begin
		// 				$fdisplay(fpo,"%d != %d error!",out_data,comp2[i]);
		// 				$fdisplay(fpt,"%d != %d error!",out_data,comp2[i]);
		// 				$display("%d != %d error!",out_data,comp2[i]);
		// 				// 		$fdisplay(fpt,"%d == comp[%d] = %d", out_data, i, comp2[i]);
		// 				// 		$fdisplay(fpo," %d == comp[%d] = %d", out_data, i, comp2[i]);
		// 				error_count++;
		// 			end else begin
		// 				$fdisplay(fpt,"%d == comp2[%d] = %d", out_data, i, comp2[i]);
		// 				$fdisplay(fpo,"%d == comp2[%d] = %d", out_data, i, comp2[i]);
		// 				$display("Passing comparison! Receive result value : %d at %t",out_data, $realtime);
		// 				end
		// 		end
		// 	end

		// end

		// done_r.Receive(dn);
		// if (dn==1) begin
		// 	$fdisplay(fpo,"total errors = %d",error_count);
		// 	$fdisplay(fpt,"total errors = %d",error_count);
		// 	$display("total errors = %d",error_count); 
			
		// 	$display("%m Results compared, ending simulation at %t",$realtime);
		// 	$fdisplay(fpt,"%m Results compared, ending simulation at %t",$realtime);
		// 	$fdisplay(fpo,"%m Results compared, ending simulation at %t",$realtime);
		// 	$fclose(fpt);
		// 	$fclose(fpo);
		// 	$finish;
		// end
	end
endmodule
