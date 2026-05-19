module seg7_decoder (
    input wire [3:0] bcd,
    output reg [7:0] seg_out
);
    // Encoding for DP G F E D C B A (0 = ON, 1 = OFF)
    always @(*) begin
        case(bcd)
            4'd0: seg_out = 8'b1100_0000; // C0
            4'd1: seg_out = 8'b1111_1001; // F9
            4'd2: seg_out = 8'b1010_0100; // A4
            4'd3: seg_out = 8'b1011_0000; // B0
            4'd4: seg_out = 8'b1001_1001; // 99
            4'd5: seg_out = 8'b1001_0010; // 92
            4'd6: seg_out = 8'b1000_0010; // 82
            4'd7: seg_out = 8'b1111_1000; // F8
            4'd8: seg_out = 8'b1000_0000; // 80
            4'd9: seg_out = 8'b1001_0000; // 90
            default: seg_out = 8'b1111_1111; // Blank
        endcase
    end
endmodule
