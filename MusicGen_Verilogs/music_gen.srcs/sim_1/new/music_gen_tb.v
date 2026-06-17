`timescale 1ns / 1ps
`define CLK_PERIOD 20 

module music_gen_tb;
    reg clk, reset_n = ~1'b0;
    wire beep;
    reg [3:0] list_index_i = 4'b0;
    reg back15s_n = ~1'b0, forw15s_n = ~1'b0;
//    wire [31:0] counter_arr, counter_ccr; //输出比较值
//    wire [7:0] list_index;
//    wire [15:0] notes_index; // Index of main ROM (Order of note sequence)
    
    music_gen music_gen(
        .clk(clk), .reset_n(reset_n), .beep(beep),
        .list_index_i(list_index_i),
        .back15s_n(back15s_n), .forw15s_n(forw15s_n)
//        , .counter_arr(counter_arr), .counter_ccr(counter_ccr),
//        .list_index(list_index), .notes_index(notes_index)
    );
    
    initial clk = 0;
    always#(`CLK_PERIOD/2) clk = ~clk;
    
    initial begin
        #2_000_000_000;
        #2_000_000_000;
        #2_000_000_000;
        #2_000_000_000;
        #2_000_000_000;
    end
endmodule
