module bin2bcd (
    input wire [26:0] binary, // Max 99,999,999
    output reg [31:0] bcd     // 8 digits x 4 bits
);
    integer i, j;
    always @(binary) begin
        bcd = 0;
        for (i = 26; i >= 0; i = i - 1) begin
            // Add 3 to columns >= 5
            for (j = 0; j < 8; j = j + 1) begin
                if (bcd[j*4 +: 4] >= 5) 
                    bcd[j*4 +: 4] = bcd[j*4 +: 4] + 3;
            end
            // Shift left 1
            bcd = {bcd[30:0], binary[i]};
        end
    end
endmodule
