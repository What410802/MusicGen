`timescale 1ns / 1ps

/* Bit length specification:
time- or clock-related: 32b;
Index of music_rom or related: 16b; Its output: 16b+4b+4b=24b; 
Index of music_list_rom or related: 8b; Its output: 16b*2=32b;
*/
module get_pitch(
    input clk, input reset_n,
    
    input [7:0] list_index,
    output reg signed [15:0] notes_index, //获取音符rom的地址编号
    
    input [15:0] note_length,
    output reg [31:0] abs_note_length, done_abs_note_length,
    output wire [31:0] abs_fullnote_length,
    
    input back15s_n, input forw15s_n
    );
    wire reset; assign reset = ~reset_n, back15s=~back15s_n, forw15s=~forw15s_n;
    
    reg [63:0] timestamp = 0, prev_timestamp = 0, last_pressed = 0; // prev_timestamp records when the last note ends. Used in note switching. 
    // So, in paused state, the user can press back/forw at most once.
    
    wire [15:0] music_rom_begin, music_rom_end; //abs_fullnote_length originally declared here
    reg [15:0] local_music_rom_begin = ~16'b0, local_music_rom_end = ~16'b0; reg [31:0] local_abs_fullnote_length = ~32'b0; // _Flag. Signal of update already.
    
    parameter 
        BACK_AMOUNT = 15,
        FORW_AMOUNT = 5,
        SLP_AMOUNT = 250_000_000/20; // f=50MHz, T_clk=2e-8s=20ns. So this is 250ms/20ns.

    music_list_rom music_list_rom(
        .clka(clk),
		.addra(list_index),
		.douta({music_rom_begin, music_rom_end, abs_fullnote_length})
    );
//     assign music_rom_begin=0, music_rom_end=10, abs_fullnote_length=32'b0000_0101_1111_0101_1110_0001_0000_0000;
     
    /*
        abs_note_length/(note_length/2^(l-1)) = abs_fullnote_length
        So, abs_note_length = abs_fullnote_length * (note_length/2^(l-1)).
        
        The abs_fullnote_length in music_list_rom.coe should be calculated by:
            (bpm/xth_note) / 60 = Fullnote_p_s
            Fullnote_p_s = 1/ T_fullnote
            abs_note_length = T_fullnote / T_clk
        So, abs_note_length = f_clk * 60 * xth_note/bpm
        For example, if bpm=120 (xth_note=4) and f_clk=50MHz, then abs_note_length = 1e8 = 00000101 11110101 11100001 00000000_2
    */
//    wire [47:0] _tmpmul; assign _tmpmul = abs_fullnote_length * note_length; // 32b+16b, higher 32b is useful. According to Verilog stadard, the result is a+b bits.
//    wire [31:0] abs_note_length; assign abs_note_length = _tmpmul[46:15]; // This normally won't cause overflow, because abs_fullnote_length's value won't go very big.
    
    always@(*) begin
        abs_note_length = ({16'b0, abs_fullnote_length} * note_length) >> 15;
    end
    always@(*) begin
        done_abs_note_length = timestamp - prev_timestamp;
    end
    
    always@(posedge clk) begin
        // Whether the song is changed. If so, reset the notes to correspending begin; else, do nothing.
        if(music_rom_begin != local_music_rom_begin || music_rom_end != local_music_rom_end || abs_fullnote_length != local_abs_fullnote_length) begin
            local_music_rom_begin     <= music_rom_begin;
            local_music_rom_end       <= music_rom_end;
            local_abs_fullnote_length <= abs_fullnote_length;
            
            notes_index               <= music_rom_begin;
            prev_timestamp            <= timestamp;
        end
        
        else if(notes_index >= local_music_rom_end) begin
            notes_index    <= notes_index - (local_music_rom_end - local_music_rom_begin);
            prev_timestamp <= timestamp;
        end
        else if(notes_index < local_music_rom_begin) begin
            notes_index    <= notes_index + (local_music_rom_end - local_music_rom_begin);
            prev_timestamp <= timestamp;
        end
        
        // Whether the back/forw is pressed. If so, back/forw corresponding notes; else, do nothing.
        else if(back15s) begin
            if(timestamp > last_pressed + SLP_AMOUNT) begin
//                if(notes_index<=local_music_rom_begin+BACK_AMOUNT)
//                    notes_index <= notes_index + (local_music_rom_end-local_music_rom_begin) - BACK_AMOUNT;
//                else
                    notes_index <= notes_index - BACK_AMOUNT;
                
                prev_timestamp <= timestamp;
                last_pressed   <= timestamp;
            end
        end
        else if(forw15s) begin
            if(timestamp > last_pressed + SLP_AMOUNT) begin
//                if(notes_index + FORW_AMOUNT>=local_music_rom_end)
//                    notes_index <= notes_index + FORW_AMOUNT - (local_music_rom_end-local_music_rom_begin);
//                else
                    notes_index <= notes_index + FORW_AMOUNT;
                
                prev_timestamp <= timestamp;
                last_pressed   <= timestamp;
            end
        end
        
        // Check whether it is time for the next note. If so, forward the pointer, and re-set the next note time; else, do nothing.
        else if(timestamp >= prev_timestamp + abs_note_length) begin
            notes_index    <= notes_index + 1;
            prev_timestamp <= timestamp;
        end
        
        if(reset) // In main file, reset controls whether the frequency is very low (1).
            timestamp <= timestamp;
        else
            timestamp <= timestamp + 1;
    end
    
endmodule
