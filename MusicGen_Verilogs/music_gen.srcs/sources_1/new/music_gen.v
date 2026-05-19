`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design Name: 
// Module Name: music_gen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module music_gen(
        input clk, input reset_n, output wire beep, // clk: 50MHz
        input [3:0] list_index_n,
        input back15s, input forw15s,
        output wire    ds,       // 串行数据
        output wire    shcp,     // 移位时钟
        output wire    stcp      // 锁存时钟
    );
        reg [31:0] counter_arr; //预重装值寄存器
        wire [31:0] counter_ccr; //输出比较值
        wire [7:0] list_index;
        wire [15:0] notes_index; // Index of main ROM (Order of note sequence), output of get_pitch.
        
    assign list_index = {4'b0, list_index_n};
    wire reset; assign reset=~reset_n;
    
    // 50MHz, A4=440Hz. The precisions below can be more fine.
    parameter
        N_SONGS = 4, // Remember to update this after updating songs.
		T_0C  = 3058174, // 50MHz//16.35Hz
		T_0CS = 2886836, //17.32Hz
		T_0D  = 2724796, //18.35Hz
		T_0DS = 2570694, //19.45Hz
		T_0E  = 2427185, //20.60Hz
		T_0F  = 2290426, //21.83Hz
		T_0FS = 2162630, //23.12Hz
		T_0G  = 2024816, //24.50Hz
		T_0GS = 1926040, //25.96Hz
		T_0A  = 1818182, //27.50Hz
		T_0AS = 1715855, //29.14Hz
		T_0B  = 1619696; //30.87Hz
    
	wire [15:0] note_length;
	wire [3:0] octaven;
	wire [3:0] inoctave;
	wire [31:0] abs_note_length, done_abs_note_length, abs_fullnote_length;
	get_pitch get_pitch(
		.clk(clk),
		.list_index(list_index),
		.notes_index(notes_index),
		.note_length(note_length),
		.abs_note_length(abs_note_length), .done_abs_note_length(done_abs_note_length), .abs_fullnote_length(abs_fullnote_length),
		.reset_n(reset_n),
		.back15s_n(back15s),
		.forw15s_n(forw15s)
	);
	music_rom music_rom(
		.clka(clk), // input wire clka
		.addra(notes_index), // input wire [15 : 0] addra
		.douta({note_length, octaven, inoctave})
	);
	
    //根据rom存储输出不同的音调输出不同的预置数
    parameter GAP_RSH_RATIO = 4, GAP_FULLNOTE_RSH_RATIO = 10;
    always@(posedge clk)
        if(reset || (done_abs_note_length < abs_note_length>>GAP_RSH_RATIO && done_abs_note_length < abs_fullnote_length>>GAP_FULLNOTE_RSH_RATIO))
            counter_arr = 32'd1;
        else begin
            case(inoctave)
                4'b0010: counter_arr = T_0C  >> octaven;
                4'b0011: counter_arr = T_0CS >> octaven;
                4'b0100: counter_arr = T_0D  >> octaven;
                4'b0101: counter_arr = T_0DS >> octaven;
                4'b0110: counter_arr = T_0E  >> octaven;
                
                4'b1000: counter_arr = T_0F  >> octaven;
                4'b1001: counter_arr = T_0FS >> octaven;
                4'b1010: counter_arr = T_0G  >> octaven;
                4'b1011: counter_arr = T_0GS >> octaven;
                4'b1100: counter_arr = T_0A  >> octaven;
                4'b1101: counter_arr = T_0AS >> octaven;
                4'b1110: counter_arr = T_0B  >> octaven;
                
                default: counter_arr = 32'd1; // normally 4'b0001, or 4'b0000, 休止符
            endcase
        end
    //设置输出比较值为预重装值一定比例
    assign counter_ccr = counter_arr >> 1;
    pwm_gen pwm_gen(
        .clk(clk),
        .reset_n(reset_n),
        .pwm_gen_en(1'b1),
        .counter_arr(counter_arr),
        .counter_ccr(counter_ccr),
        .pwm_out(beep) // DEBUG: If you wish to output to beep, then fill in `beep`; else put it blank.
    );
    display_74hc595_8digit display_74hc595_8digit(
        .clk(clk), .rst_n('b1),
        .value_in(list_index*10000+notes_index),
        .SEG7_DIO__DS(ds), .SEG7_SCLK__SHCP(shcp), .SEG7_RCLK__STCP(stcp)
    );
    
endmodule
/*
music_list_rom.coe:
```
; 16b: begin, 16b: end, 32b: abs_fullnote_length





;      ::      ><      ::      ><      ::      ::      ::      >
```
music_rom.coe:
```
; 16b(0)+4b(1)+4b(2): 0: length, 1: which octave, 2: which note (12 in total) in this octave. 1~2: T=126.55us to 61.16ms





;  ::  ::  ::  ><  ><  >
```
*/