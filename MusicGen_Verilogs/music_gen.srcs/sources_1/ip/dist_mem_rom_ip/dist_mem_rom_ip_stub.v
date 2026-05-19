// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Sat Jul 20 15:47:06 2024
// Host        : DESKTOP-K3KT58K running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/LearnFPGA_xilinx/music_gen/music_gen.srcs/sources_1/ip/dist_mem_rom_ip/dist_mem_rom_ip_stub.v
// Design      : dist_mem_rom_ip
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "dist_mem_gen_v8_0_12,Vivado 2018.3" *)
module dist_mem_rom_ip(a, clk, spo, qspo)
/* synthesis syn_black_box black_box_pad_pin="a[8:0],clk,spo[7:0],qspo[7:0]" */;
  input [8:0]a;
  input clk;
  output [7:0]spo;
  output [7:0]qspo;
endmodule
