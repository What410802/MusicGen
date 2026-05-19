`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/07/17 13:58:12
// Design Name: 
// Module Name: pwm_gen
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
//   This file is equivalent to a "hardware driver", which means that the input of this file needn't to be changed upon modifying other file's functionalities.  
//////////////////////////////////////////////////////////////////////////////////


module pwm_gen(
    clk,
    reset_n,
    
    pwm_gen_en,
    counter_arr,
    counter_ccr,
    pwm_out
    );
    wire reset;
    assign reset = ~reset_n;
    
    input clk;
    input reset_n;
    
    input pwm_gen_en; //pwm产生使能信号
    input [31:0]counter_arr;//输入32位预重装值
    input [31:0]counter_ccr; //输入32位输出比较值
    output reg pwm_out;
    
    reg [31:0]pwm_gen_cnt=32'b1;
//pwm频率控制
    always@(posedge clk)
      if(reset)
        pwm_gen_cnt <= 32'd1;
      else if(pwm_gen_en)
          begin
            if(pwm_gen_cnt <= 32'd1)
              pwm_gen_cnt <= counter_arr;    //计数减到1，加载预重装寄存器值
            else
              pwm_gen_cnt <= pwm_gen_cnt - 1'b1;//计数器自减1
          end
      else
        pwm_gen_cnt <= counter_arr; //未使能时，计数器值等于预重装寄存器值            
//占空比比较器        
    always@(posedge clk)
      if(reset)                          //复位时，PWM输出低电平
        pwm_out <= 1'b0;
      else if(pwm_gen_cnt <= counter_ccr)//计数值小于比较值，PWM输出高电平
        pwm_out <= 1'b1;
      else
        pwm_out <= 1'b0;      //计数值大于比较值，PWM输出低电平    

endmodule
