module display_74hc595_8digit (
    input wire clk,              // e.g., 50MHz
    input wire rst_n,
    input wire [26:0] value_in,  // Integer to display
    
    output wire SEG7_DIO__DS,
    output wire SEG7_RCLK__STCP,
    output wire SEG7_SCLK__SHCP
);

    // --- Signals & Internal State ---
    wire [31:0] bcd_data;
    wire [7:0] current_seg_data;
    reg [3:0] current_bcd_digit;
    reg [7:0] digit_select;
    reg [2:0] digit_idx;
    
    reg [15:0] shift_data;
    reg shift_start;
    wire shift_busy;
    
    // 1ms Refresh Timer (Assumes 50MHz Clock)
    reg [15:0] refresh_cnt;
    localparam REFRESH_MAX = 16'd50_000; 

    // --- Module Instantiations ---
    bin2bcd u_bcd (
        .binary(value_in),
        .bcd(bcd_data)
    );

    seg7_decoder u_seg (
        .bcd(current_bcd_digit),
        .seg_out(current_seg_data)
    );

    hc595_driver u_driver (
        .clk(clk),
        .rst_n(rst_n),
        .start(shift_start),
        .data_in(shift_data),
        .SEG7_DIO__DS(SEG7_DIO__DS),
        .SEG7_RCLK__STCP(SEG7_RCLK__STCP),
        .SEG7_SCLK__SHCP(SEG7_SCLK__SHCP),
        .busy(shift_busy)
    );

    // --- Multiplexer Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_cnt <= 16'd0;
            digit_idx <= 3'd0;
            shift_start <= 1'b0;
            digit_select <= 8'b0000_0001;
        end else begin
            shift_start <= 1'b0; // Default to no-start pulse
            
            if (refresh_cnt == REFRESH_MAX) begin
                refresh_cnt <= 16'd0;
                
                // Advance to next digit
                digit_idx <= digit_idx + 1;
                
                // Shift digit select mask (Active High assumed for digit selection)
                if (digit_idx == 3'd7) digit_select <= 8'b0000_0001;
                else                   digit_select <= digit_select << 1;
                
            end else begin
                refresh_cnt <= refresh_cnt + 1;
            end
            
            // Extract the 4-bit BCD for the currently active digit
            // (e.g., if digit_idx=0, grab bcd_data[3:0])
            current_bcd_digit <= bcd_data[(digit_idx * 4) +: 4];

            // Trigger the shift process halfway through the timer to ensure stable data
            // Combine segment data and digit selection into the 16-bit payload
            // Note: Concatenation order {segment, digit} depends on which 595 is first in the chain on your PCB. 
            // Swap to {digit_select, current_seg_data} if your display is scrambled.
            if (refresh_cnt == (REFRESH_MAX / 2) && !shift_busy) begin
                shift_data <= {current_seg_data, digit_select}; 
                shift_start <= 1'b1;
            end
        end
    end
endmodule
