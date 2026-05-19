module hc595_driver (
    input wire clk,           // System clock (e.g., 50MHz)
    input wire rst_n,         // Active low reset
    input wire start,         // Pulse high to start transmission
    input wire [15:0] data_in,// 16-bit data (Segment Data + Digit Select)
    
    output reg SEG7_DIO__DS,
    output reg SEG7_RCLK__STCP,
    output reg SEG7_SCLK__SHCP,
    output reg busy           // High while shifting
);

    reg [2:0] state;
    reg [15:0] shift_reg;
    reg [4:0] bit_cnt;

    localparam IDLE       = 3'd0;
    localparam SHIFT_LOW  = 3'd1;
    localparam SHIFT_HIGH = 3'd2;
    localparam LATCH      = 3'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            SEG7_DIO__DS <= 1'b0;
            SEG7_RCLK__STCP <= 1'b0;
            SEG7_SCLK__SHCP <= 1'b0;
            busy <= 1'b0;
            bit_cnt <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    SEG7_RCLK__STCP <= 1'b0;
                    SEG7_SCLK__SHCP <= 1'b0;
                    if (start) begin
                        shift_reg <= data_in;
                        busy <= 1'b1;
                        bit_cnt <= 5'd15; // Shift MSB first
                        state <= SHIFT_LOW;
                    end else begin
                        busy <= 1'b0;
                    end
                end

                SHIFT_LOW: begin
                    SEG7_SCLK__SHCP <= 1'b0;
                    SEG7_DIO__DS <= shift_reg[bit_cnt]; // Present data
                    state <= SHIFT_HIGH;
                end

                SHIFT_HIGH: begin
                    SEG7_SCLK__SHCP <= 1'b1; // Rising edge shifts data in
                    if (bit_cnt == 0) begin
                        state <= LATCH;
                    end else begin
                        bit_cnt <= bit_cnt - 1;
                        state <= SHIFT_LOW;
                    end
                end

                LATCH: begin
                    SEG7_SCLK__SHCP <= 1'b0;
                    SEG7_RCLK__STCP <= 1'b1; // Rising edge updates outputs
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
