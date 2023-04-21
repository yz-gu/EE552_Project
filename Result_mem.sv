`timescale 1ns / 1ps

import SystemVerilogCSP::*;


module Result_mem(
    interface in, ref_in
);
    parameter WIDTH_DATA = 13;
    parameter WIDTH_PKT = 32;
    parameter DEPTH_R = 21;
    parameter THRE = 13'd64;
    logic [WIDTH_PKT-1: 0] pkt;
    logic [DEPTH_R-1: 0] [DEPTH_R-1: 0] [WIDTH_DATA-1: 0] residue;
    logic [DEPTH_R-1: 0] [DEPTH_R-1: 0] spike;
    logic  ref_value;
    logic [4:0] ln_num;
    logic [4:0] counter [DEPTH_R-1:0];
    logic [DEPTH_R-1:0] initialized = 21'd0;
    logic [12:0] data;
    logic done = 0;

    integer fpr1, fps1, fpr2, fps2, fpt, fpd;
    integer last_event_time = 0, gap1, gap2;
    initial begin
        fpr1 = $fopen("residue1.txt","w");
        fps1 = $fopen("spike1.txt","w");
        fpt = $fopen("time.txt", "w");
        fpd = $fopen("match.txt", "w");
        // fpr1 = $fopen("test_residue1.txt","w");
        // fps1 = $fopen("test_spike1.txt","w");
        for (int i = 0; i<DEPTH_R**2; i++) begin
            in.Receive(pkt);
            data = pkt[12:0];

            gap1 = $time - last_event_time;
            last_event_time = $time;
            $fdisplay(fpt, "%0d", gap1);

            ln_num = pkt[20:16];
            if (!initialized[ln_num]) begin
                counter[ln_num] = 0;
                initialized[ln_num] = 1;
            end
            residue[ln_num][counter[ln_num]] = data;
            spike[ln_num][counter[ln_num]] = 0;
            if (residue[ln_num][counter[ln_num]] > 13'd64) begin
                residue[ln_num][counter[ln_num]] -= THRE;
                spike[ln_num][counter[ln_num]] = 1;
            end
            counter[ln_num] ++;
        end

        for (int i = 0; i<DEPTH_R; i++) begin
            for (int j = 0; j<DEPTH_R; j++) begin
                ref_in.Receive(ref_value);
                if (spike[i][j] == ref_value) begin
                    $fdisplay(fpd, "match");
                    $display("match");
                end
                else begin
                    $fdisplay(fpd, "don't match");
                    $display("don't match");
                end
                 $fdisplay(fpr1, "%0d", residue[i][j]);
                 $fdisplay(fps1, "%0d", spike[i][j]);
            end
        end

        done = 1;

        initialized = 21'd0;
        fpr2 = $fopen("residue2.txt","w");
        fps2 = $fopen("spike2.txt","w");
        // fpr2 = $fopen("test_residue2.txt","w");
        // fps2 = $fopen("test_spike2.txt","w");
        for (int i = 0; i<DEPTH_R**2; i++) begin
            in.Receive(pkt);
            data = pkt[12:0];

            gap2 = $time - last_event_time;
            last_event_time = $time;
            $fdisplay(fpt, "%0d", gap2);

            ln_num = pkt[20:16];
            if (!initialized[ln_num]) begin
                counter[ln_num] = 0;
                initialized[ln_num] = 1;
            end
            residue[ln_num][counter[ln_num]] += data;
            if (residue[ln_num][counter[ln_num]] > 13'd64) begin
                residue[ln_num][counter[ln_num]] -= THRE;
                spike[ln_num][counter[ln_num]] = 1;
            end
            else
                spike[ln_num][counter[ln_num]] = 0;
            counter[ln_num] ++;
        end
        
        for (int i = 0; i<DEPTH_R; i++) begin
            for (int j = 0; j<DEPTH_R; j++) begin
                ref_in.Receive(ref_value);
                if (spike[i][j] == ref_value) begin
                    $fdisplay(fpd, "match");
                    $display("match");
                end
                else begin
                    $fdisplay(fpd, "don't match");
                    $display("don't match");
                end
                $fdisplay(fpr2, "%0d", residue[i][j]);
                $fdisplay(fps2, "%0d", spike[i][j]);
            end
        end

        $stop;
    end

endmodule
