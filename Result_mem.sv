`timescale 1ns / 1ps

import SystemVerilogCSP::*;


module Result_mem(
    interface in
);
    parameter WIDTH_DATA = 13;
    parameter WIDTH_PKT = 32;
    parameter DEPTH_R = 21;
    parameter THRE = 13'd64;
    logic [WIDTH_PKT-1: 0] pkt;
    logic [WIDTH_DATA-1: 0] residue [DEPTH_R**2-1: 0];
    logic spike [DEPTH_R**2-1: 0];
    logic [7:0] addr;
    logic done = 0;

    integer fpr, fps;
    initial begin
        fpr = $fopen("test_residue.txt","w");
        fps = $fopen("test_spike.txt","w");
        for (int i = 0; i<DEPTH_R**2; i++) begin
            in.Receive(pkt);
            addr = pkt[20:13];
            if (pkt[12:0]>=13'd64) begin
                residue[addr] = pkt[12:0] - THRE;
                spike[addr] = 1;
            end
            else begin
                residue[addr] = pkt[12:0];
                spike[addr] = 0;
            end
        end
        done = 1;
        $stop;
    end

    initial begin
        wait(done);
        for (int i = 0; i<DEPTH_R**2; i++) begin
            $fdisplay(fpr, "%d", residue[addr]);
            $fdisplay(fps, "%d", spike[addr]);
        end
    end
endmodule
