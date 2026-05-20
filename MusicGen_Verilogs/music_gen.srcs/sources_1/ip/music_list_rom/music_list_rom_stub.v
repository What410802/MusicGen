// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Wed May 20 14:51:14 2026
// Host        : DESKTOP-5SKJTNQ running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               C:/Users/what4/BiS.d/1.d/Code.d/SystemVerilog.d/MusicGen/MusicGen_Verilogs/music_gen.srcs/sources_1/ip/music_list_rom/music_list_rom_stub.v
// Design      : music_list_rom
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_2,Vivado 2018.3" *)
module music_list_rom(clka, addra, douta)
/* synthesis syn_black_box black_box_pad_pin="clka,addra[7:0],douta[63:0]" */;
  input clka;
  input [7:0]addra;
  output [63:0]douta;
endmodule
