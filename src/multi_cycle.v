/**************************************************************************/
/* code185.v                          For CSC.T341 CLD Archlab TOKYO TECH */
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
   
  m_proc14 p (r_clk, 1'b1, w_led);

  always@(posedge r_clk)
    $write("%5d: %08x %08x %08x %08x %08x: %d %08x %08x %08x %08x %08x %08x\n",
           r_cnt, p.IF.pc, p.ID.pc, p.EX.pc, p.MEM.pc, p.WB.pc,
           p.EX.do_branch, p.ID.reg_data1, p.ID.reg_data2, p.EX.rhs_operand, p.EX.calced_value, p.WB.writing_value, p.w_led);

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
  m_proc14 p (w_clk2, w_locked, w_dout);

  vio_0 vio_00(w_clk2, w_dout);
 
  reg [3:0] r_led = 0;
  always @(posedge w_clk2) 
    r_led <= {^w_dout[31:24], ^w_dout[23:16], ^w_dout[15:8], ^w_dout[7:0]};
  assign w_led = r_led;
endmodule
*/

module m_proc14 (w_clk, w_ce, w_led);
    input  wire w_clk, w_ce;
    output wire [31:0] w_led;

    m_IF IF(w_clk, w_ce, ID.do_speculative_branch, ID.branch_dest_addr, EX.do_branch, EX.branch_dest_addr);
    m_ID ID(w_clk, w_ce, EX.do_branch, IF.pc, IF.instr, WB.reg_dest, WB.writing_value);
    m_EX EX(
        w_clk, w_ce, ID.pc, ID.instr, ID.imm,
        ID.reg_source1, ID.reg_source2, ID.reg_data1, ID.reg_data2, ID.reg_dest,
        MEM.reg_dest, WB.reg_dest, MEM.calced_value, WB.writing_value
    );

    m_MEM MEM(w_clk, w_ce, EX.pc, EX.instr, EX.calced_value, EX.reg_source1, EX.reg_source2, EX.reg_data2, EX.reg_dest);
    m_WB WB(w_clk, w_ce, MEM.pc, MEM.instr, MEM.calced_value, MEM.memory_data, MEM.reg_dest);

    reg [31:0] r_led = 0;
    always @(posedge w_clk) if(w_ce & WB.reg_dest == 30) r_led <= WB.writing_value;
    assign w_led = r_led;
endmodule

module m_IF ( clk, ce, ID_do_speculative_branch, ID_branch_dest_addr, EX_do_branch, EX_branch_dest_addr);
    input wire clk, ce;
    input wire ID_do_speculative_branch, EX_do_branch;
    input wire [31:0] ID_branch_dest_addr, EX_branch_dest_addr;

    reg [31:0] pc = 0;
    wire [31:0] instr;

    //                clk, addr,     we,   input, output
    m_amemory m_imem (clk, pc[13:2], 1'd0, 32'd0, instr);

    always @(posedge clk) #5 if(ce && instr != 32'h000f0033) pc <= EX_do_branch ? EX_branch_dest_addr : ID_do_speculative_branch ? ID_branch_dest_addr : pc+4;
endmodule

module m_ID ( clk, ce, do_branch, IF_pc, IF_instr, WB_reg_dest, WB_write_value );
    input wire clk, ce, do_branch;
    input wire [31:0] IF_pc, IF_instr;
    input wire [4:0] WB_reg_dest;
    input wire [31:0] WB_write_value;

    // take over from IF
    reg [31:0] pc = 0;
    reg [31:0] instr = 0;
    always @(posedge clk) #5 if(ce) begin
        pc <= (do_branch || do_speculative_branch) ? 0 : IF_pc;
        instr <= (do_branch || do_speculative_branch) ? {25'd0, 7'b0010011} : IF_instr;
    end

    // split instr
    wire [4:0] short_opcode = instr[6:2];
    wire is_instr_to_write_reg = short_opcode == 5'b01100 // arithmetic operation with reg
                              || short_opcode == 5'b00100 // arithmetic operation with imm
                              || short_opcode == 5'b00000;// store
    wire [4:0] reg_dest     = !do_branch && is_instr_to_write_reg ? instr[11:7] : 0;
    wire [4:0] reg_source1  = instr[19:15];
    wire [4:0] reg_source2  = instr[24:20];

    wire [31:0] imm, week_reg_data1, week_reg_data2;
    m_immgen m_immgen0 (instr, imm);
    m_regfile m_regs (clk, reg_source1, reg_source2, WB_reg_dest, 1'b1, WB_write_value, week_reg_data1, week_reg_data2);

    wire [31:0] reg_data1 = (WB_reg_dest != 0 && WB_reg_dest == reg_source1) ? WB_write_value : week_reg_data1;
    wire [31:0] reg_data2 = (WB_reg_dest != 0 && WB_reg_dest == reg_source2) ? WB_write_value : week_reg_data2;

    wire do_speculative_branch = {instr[12], short_opcode} == 6'b111000; // == is_bne
    wire [31:0] branch_dest_addr = pc + imm;
endmodule

module m_EX (
    clk, ce, ID_pc, ID_instr, ID_imm,
    ID_reg_source1, ID_reg_source2, ID_reg_data1, ID_reg_data2, ID_reg_dest,
    MEM_reg_dest, WB_reg_dest, MEM_calced_value, WB_writing_value
);
    input wire clk, ce;
    input wire [31:0] ID_pc, ID_instr, ID_imm;
    input wire [4:0]  ID_reg_source1, ID_reg_source2, ID_reg_dest;
    input wire [31:0] ID_reg_data1, ID_reg_data2;

    input wire [4:0]  MEM_reg_dest, WB_reg_dest;
    input wire [31:0] MEM_calced_value, WB_writing_value;

    // take over from ID
    reg [31:0] pc = 0, instr = 0, imm = 0;
    reg [4:0]  reg_source1 = 0, reg_source2 = 0, reg_dest = 0;
    reg [31:0] week_reg_data1 = 0, week_reg_data2 = 0;

    always @(posedge clk) #5 if(ce) begin
        pc <= do_branch ? 0 : ID_pc;
        instr <= do_branch ? {25'd0, 7'b0010011} : ID_instr;
        imm <= ID_imm;
        reg_source1 <= ID_reg_source1;
        reg_source2 <= ID_reg_source2;
        week_reg_data1 <= ID_reg_data1;
        week_reg_data2 <= ID_reg_data2;
        reg_dest  <= ID_reg_dest;
    end

    wire [4:0] short_opcode = instr[6:2];
    wire is_sll = instr[14:12] == 3'b001;
    wire is_srl = instr[14:12] == 3'b101;
    wire is_beq = {instr[12], short_opcode} == 6'b011000;
    wire is_bne = {instr[12], short_opcode} == 6'b111000;


    wire [31:0] reg_data1 = reg_source1 == 0            ? 0
                          : reg_source1 == MEM_reg_dest ? MEM_calced_value
                          : reg_source1 == WB_reg_dest  ? WB_writing_value
                          :                               week_reg_data1;
    wire [31:0] reg_data2 = reg_source2 == 0            ? 0
                          : reg_source2 == MEM_reg_dest ? MEM_calced_value
                          : reg_source2 == WB_reg_dest  ? WB_writing_value
                          :                               week_reg_data2;

    wire [31:0] lhs_operand = reg_data1;
    wire [31:0] rhs_operand = (short_opcode==5'b01100 || short_opcode==5'b11000) ? reg_data2 : imm;

    wire [31:0] calced_value = (is_sll) ? lhs_operand << rhs_operand[4:0] :
                               (is_srl) ? lhs_operand >> rhs_operand[4:0] : lhs_operand + rhs_operand;

    wire revert_speculative_branch = (is_bne & lhs_operand == rhs_operand);
    wire do_branch = revert_speculative_branch || (is_beq & lhs_operand == rhs_operand);

    wire [31:0] branch_dest_addr = revert_speculative_branch ? pc + 4 : pc + imm;
endmodule

module m_MEM ( clk, ce, EX_pc, EX_instr, EX_calced_value, EX_reg_source1, EX_reg_source2, EX_reg_data2, EX_reg_dest );
    input wire clk, ce;
    input wire [31:0] EX_pc, EX_instr, EX_calced_value;
    input wire [4:0]  EX_reg_source1, EX_reg_source2, EX_reg_dest;
    input wire [31:0] EX_reg_data2;

    // take over from EX
    reg [31:0] pc = 0, instr = 0, calced_value;
    reg [4:0]  reg_source1 = 0, reg_source2 = 0, reg_dest = 0;
    reg [31:0] reg_data2 = 0;
    always @(posedge clk) #5 if(ce) begin
        pc           <= EX_pc;
        instr        <= EX_instr;
        calced_value <= EX_calced_value;
        reg_source1  <= EX_reg_source1;
        reg_source2  <= EX_reg_source2;
        reg_data2    <= EX_reg_data2;
        reg_dest     <= EX_reg_dest;
    end

    wire [4:0] short_opcode = instr[6:2];
    wire is_store_instr = short_opcode == 5'b01000;
    wire [31:0] memory_data;
    m_memory m_dmem (clk, calced_value[13:2], is_store_instr, reg_data2, memory_data);
endmodule

module m_WB ( clk, ce, MEM_pc, MEM_instr, MEM_calced_value, MEM_memory_data, MEM_reg_dest );
    input wire clk, ce;
    input wire [31:0] MEM_pc, MEM_instr, MEM_calced_value, MEM_memory_data;
    input wire [4:0]  MEM_reg_dest;

    // take over from MEM
    reg [31:0] pc = 0, instr = 0, calced_value, memory_data;
    reg [4:0]  reg_dest = 0;

    always @(posedge clk) #5 if(ce) begin
        pc           <= MEM_pc;
        instr        <= MEM_instr;
        calced_value <= MEM_calced_value;
        memory_data  <= MEM_memory_data;
        reg_dest     <= MEM_reg_dest;
    end

    wire [4:0] short_opcode = instr[6:2];

    wire is_load_instr = short_opcode == 5'b00000;
    wire [31:0] writing_value = is_load_instr ? memory_data : calced_value;
endmodule

module m_amemory (w_clk, w_addr, w_we, w_din, w_dout); // asynchronous memory
  input  wire w_clk, w_we;
  input  wire [11:0] w_addr;
  input  wire [31:0] w_din;
  output wire [31:0] w_dout;
  reg [31:0] 	     cm_ram [0:4095]; // 4K word (4096 x 32bit) memory
  always @(posedge w_clk) if (w_we) cm_ram[w_addr] <= w_din;
  assign #20 w_dout = cm_ram[w_addr];
`include "../inputs/program6.txt" // [include]
endmodule

module m_memory (w_clk, w_addr, w_we, w_din, r_dout); // synchronous memory
  input  wire w_clk, w_we;
  input  wire [11:0] w_addr;
  input  wire [31:0] w_din;
  output reg  [31:0] r_dout;
  reg [31:0]         cm_ram [0:4095]; // 4K word (4096 x 32bit) memory
  always @(posedge w_clk) if (w_we) cm_ram[w_addr] <= w_din;
  always @(posedge w_clk) r_dout <= cm_ram[w_addr];
`include "../inputs/program6.txt" // [include]
endmodule

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
