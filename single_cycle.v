/**************************************************************************/
/* code161.v                          For CSC.T341 CLD Archlab TOKYO TECH */
/**************************************************************************/
`timescale 1ns/100ps
`default_nettype none

/***** top module for simulation *****/
module m_top (); 
  reg r_clk=0; initial forever #50 r_clk = ~r_clk;
  wire [31:0] w_led;

//  initial $dumpfile("main.vcd");
//  initial $dumpvars(0, m_top);

  reg [31:0] r_cnt = 1;
  always@(posedge r_clk) r_cnt <= r_cnt + 1;
   
  m_proc p (r_clk, 1'b1, w_led);

  always@(posedge r_clk) $write("%7d %08x\n", r_cnt, p.w_rslt2);
//  initial $write("  clock: r_pc     w_ir     w_rrs1   w_ain    r_rslt2  r_led\n");
//  always@(posedge r_clk) 
//    $write("%7d: %08x %x %08x %08x %08x %08x\n", r_cnt,
//            p.r_pc, p.w_ir, p.w_rrs1, p.w_ain, p.w_rslt2, w_led);
  always@(posedge r_clk) if(w_led!=0) $finish;
  initial #50000000 $finish;
endmodule

/***** main module for FPGA implementation *****/
/*
module m_main (w_clk, w_led);
  input  wire w_clk;
  output wire [3:0] w_led;
 
  wire w_clk2, w_locked;
  clk_wiz_0 clk_w0 (w_clk2, 0, w_locked, w_clk);
   
  wire [31:0] w_dout;
  m_proc p (w_clk2, w_locked, w_dout);

  vio_0 vio_00(w_clk2, w_dout);
 
  reg [3:0] r_led = 0;
  always @(posedge w_clk2) 
    r_led <= {^w_dout[31:24], ^w_dout[23:16], ^w_dout[15:8], ^w_dout[7:0]};
  assign w_led = r_led;
endmodule
*/

/**************************************************************************/
module m_proc (w_clk, w_ce, w_led); // m_proc07
  input  wire w_clk, w_ce;
  output wire [31:0] w_led;

  reg [31:0] r_pc = 0;
  wire [31:0] w_ir;
  wire [4:0]  w_op5 = w_ir[6:2];
  wire [4:0]  w_rs1 = w_ir[19:15];
  wire [4:0]  w_rs2 = w_ir[24:20];
  wire [4:0]  w_rd  = w_ir[11:7];
  wire [2:0]  w_f3  = w_ir[14:12];
  wire w_we = w_ce & (w_op5==5'b01100 || w_op5==5'b00100 || w_op5==5'b00000);

  wire [31:0] w_imm, w_rrs1, w_rrs2, w_ain, w_rslt, w_ldd, w_rslt2;

  m_amemory m_imem (w_clk, r_pc[13:2], 1'd0, 32'd0, w_ir);
  m_immgen m_immgen0 (w_ir, w_imm);
  m_regfile m_regs (w_clk, w_rs1, w_rs2, w_rd, w_we, w_rslt2, w_rrs1, w_rrs2);
  assign w_ain = (w_op5==5'b01100) ? w_rrs2 : w_imm;
  assign w_rslt = (w_f3==3'b001) ? w_rrs1 << w_ain[4:0] :
                  (w_f3==3'b101) ? w_rrs1 >> w_ain[4:0] : w_rrs1 + w_ain;

  m_amemory m_dmem (w_clk, w_rslt[13:2], (w_op5==5'b01000), w_rrs2, w_ldd);
  assign w_rslt2 = (w_op5==5'b00000) ? w_ldd : w_rslt;

  wire w_tkn = ({w_ir[12],w_op5}==6'b011000 & w_rrs1==w_rrs2) ||  // BEQ
               ({w_ir[12],w_op5}==6'b111000 & w_rrs1!=w_rrs2);    // BNE
  always @(posedge w_clk) #5 
    if(w_ce && w_ir!=32'h000f0033) r_pc <= (w_tkn) ? r_pc + w_imm : r_pc+4;
              
  reg [31:0] r_led = 0;
  always @(posedge w_clk) if(w_ce & w_we & w_rd==30) r_led <= w_rslt;
  assign w_led = r_led;
endmodule

/**************************************************************************/
module m_amemory (w_clk, w_addr, w_we, w_din, w_dout); // asynchronous memory
  input  wire w_clk, w_we;
  input  wire [11:0] w_addr;
  input  wire [31:0] w_din;
  output wire [31:0] w_dout;
  reg [31:0] 	     cm_ram [0:4095]; // 4K word (4096 x 32bit) memory
  always @(posedge w_clk) if (w_we) cm_ram[w_addr] <= w_din;
  assign #20 w_dout = cm_ram[w_addr];
`include "program.txt"
endmodule

/**************************************************************************/
module m_memory (w_clk, w_addr, w_we, w_din, r_dout); // synchronous memory
  input  wire w_clk, w_we;
  input  wire [11:0] w_addr;
  input  wire [31:0] w_din;
  output reg  [31:0] r_dout;
  reg [31:0]         cm_ram [0:4095]; // 4K word (4096 x 32bit) memory
  always @(posedge w_clk) if (w_we) cm_ram[w_addr] <= w_din;
  always @(posedge w_clk) r_dout <= cm_ram[w_addr];
`include "program.txt"
endmodule

/**************************************************************************/
module m_immgen (w_i, r_imm); // module immediate generator
  input  wire [31:0] w_i;    // instruction
  output reg  [31:0] r_imm;  // r_immediate

  always @(*) case (w_i[6:2])
    5'b11000: r_imm <= {{20{w_i[31]}}, w_i[7], w_i[30:25], w_i[11:8], 1'b0};   // B-type
    5'b01000: r_imm <= {{21{w_i[31]}}, w_i[30:25], w_i[11:7]};                 // S-type
    5'b11011: r_imm <= {{12{w_i[31]}}, w_i[19:12], w_i[20], w_i[30:21], 1'b0}; // J-type
    5'b01101: r_imm <= {w_i[31:12], 12'b0};                                    // U-type
    5'b00101: r_imm <= {w_i[31:12], 12'b0};                                    // U-type
    default : r_imm <= {{21{w_i[31]}}, w_i[30:20]};                   // I-type & R-type
  endcase
endmodule

/**************************************************************************/
module m_regfile (w_clk, w_rr1, w_rr2, w_wr, w_we, w_wdata, w_rdata1, w_rdata2);
   input  wire        w_clk;
   input  wire [4:0]  w_rr1, w_rr2, w_wr;
   input  wire [31:0] w_wdata;
   input  wire        w_we;
   output wire [31:0] w_rdata1, w_rdata2;
    
   reg [31:0] r[0:31];
   assign #8 w_rdata1 = (w_rr1==0) ? 0 : r[w_rr1];
   assign #8 w_rdata2 = (w_rr2==0) ? 0 : r[w_rr2];
   always @(posedge w_clk) if(w_we) r[w_wr] <= w_wdata;
endmodule
/**************************************************************************/
