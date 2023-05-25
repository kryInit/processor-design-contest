/**************************************************************************/
/* code185.v                          For CSC.T341 CLD Archlab TOKYO TECH */
/**************************************************************************/
`timescale 1ns/100ps
`default_nettype none

/***** top module for simulation *****/
// [[delete-begin --on-vivado]]
module m_top (); 
    reg r_clk=0; initial forever #50 r_clk = ~r_clk;
    wire [31:0] w_led;

    initial $dumpfile("main.vcd"); // [[delete-line --on-test]]
    initial $dumpvars(0, m_top);   // [[delete-line --on-test]]

    reg [31:0] r_cnt = 1;
    always@(posedge r_clk) r_cnt <= r_cnt + 1;

    m_proc14 p (r_clk, 1'b1, w_led);

    initial $write("r_cnt: IF.pc    ID.pc    EX.pc    MEM.pc   WB.pc   :   ID.reg_data1, 2   EX.rhs   EX.ret   WB.w_val w_led\n");
    always@(posedge r_clk)
        $write("%5d: %08x %08x %08x %08x %08x: %d %08x %08x %08x %08x %08x %08x\n",
            r_cnt, p.IF.pc, p.ID.pc, p.EX.pc, p.MEM.pc, p.WB.pc,
            p.EX.do_branch, p.ID.reg_data1, p.ID.reg_data2, p.EX.rhs_operand, p.MEM.calced_value, p.WB.writing_value, p.w_led);

    always@(posedge r_clk) if(w_led!=0) $finish;
    initial #50000000 $finish;
endmodule
// [[delete-end --on-vivado]]

/***** main module for FPGA implementation *****/
/* [[delete-line --on-vivado]]
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
// [[delete-line --on-vivado]] */

module m_proc14 (w_clk, w_ce, w_led);
    input  wire w_clk, w_ce;
    output wire [31:0] w_led;

    m_IF IF(w_clk, w_ce, ID.do_speculative_branch, ID.branch_dest_addr, ID.pc, MEM.do_branch, MEM.branch_dest_addr);
    m_ID ID(w_clk, w_ce, MEM.do_branch, IF.pc, IF.instr, IF.do_speculative_branch, WB.reg_dest, WB.writing_value);
    m_EX EX(
        w_clk, w_ce, MEM.do_branch, ID.pc, ID.instr, ID.imm,
        ID.reg_source1, ID.reg_source2, ID.reg_data1, ID.reg_data2, ID.reg_dest,
        MEM.reg_dest, WB.reg_dest, MEM.calced_value, WB.writing_value
    );
    m_MEM MEM(w_clk, w_ce, EX.pc, EX.instr, EX.imm, EX.reg_source1, EX.reg_source2, EX.reg_data2, EX.reg_dest, EX.lhs_operand, EX.rhs_operand );
    m_WB WB(w_clk, w_ce, MEM.pc, MEM.instr, MEM.calced_value, MEM.memory_data, MEM.reg_dest);

    reg [31:0] r_led = 0;
    always @(posedge w_clk) if(w_ce & WB.reg_dest == 30) r_led <= WB.writing_value;
    assign w_led = r_led;
endmodule

module m_IF ( clk, ce, ID_do_speculative_branch, ID_branch_dest_addr, ID_pc, EX_do_branch, EX_branch_dest_addr );
/*
    1. 命令のフェッチ
    2. PCの更新
        - ID, EXステージで計算した分岐フラグがtrue: 指定された場所へ
        - それ以外:  pc += 4
    3. 分岐先のメモ化
        - bne命令の分岐先をメモ化
            - 本来bneはIDステージで分岐先がわかる
            - メモ化し、この段階で分岐先がわかると1cycleの得
        - IDステージから分岐して欲しいと言われる ( ID_do_speculative_branch = true ): 分岐先をメモ
        - それ以外: メモした値を取得
            - 取得した値が0でない: 過去に分岐が起こっているので分岐
            -           0である: 何もしない
*/
    input wire clk, ce;
    input wire ID_do_speculative_branch, EX_do_branch;
    input wire [31:0] ID_pc, ID_branch_dest_addr, EX_branch_dest_addr;

    reg [31:0] pc = 0;
    wire [31:0] instr;
    //                               addr,     read value
    m_instr_memory instr_memory(clk, pc[13:2], instr); // fetch instruction

    wire [11:0] addr = ID_do_speculative_branch ? ID_pc[13:2] : EX_do_branch ? 0 : pc[13:2] + 12'd2; // regを使っていて遅延があり、それを補完するための + 12'd2
    wire [31:0] raw_branch_dest_addr;
    //                                   write enable,             writing value,       read value
    m_data_memory data_memory(clk, addr, ID_do_speculative_branch, ID_branch_dest_addr, raw_branch_dest_addr); // fetch memorized branch destination

    // 本来この辺のregはIDに書くべきのはずだが、IDで使用するわけではないのでここに書く
    reg do_speculative_branch = 0;
    reg [31:0] branch_dest_addr = 0;
    always @(posedge clk) #5 if(ce) begin
        branch_dest_addr <= raw_branch_dest_addr;
        do_speculative_branch <= |raw_branch_dest_addr;

        if (instr != 32'h000f0033) begin // 32'h000f0033はこのプロセッサにおいてのhalt命令
            pc <= EX_do_branch             ? EX_branch_dest_addr
                : ID_do_speculative_branch ? ID_branch_dest_addr
                : do_speculative_branch    ? branch_dest_addr
                : pc+4;
        end
    end
endmodule

module m_ID ( clk, ce, do_branch, IF_pc, IF_instr, IF_do_speculative_branch, WB_reg_dest, WB_write_value );
/*
    1. 命令のデコード
    2. レジスタへの書き込み、読み出し
    3. bne命令の分岐先計算 ( bne命令の投機的実行 )
        - bne命令の分岐先を計算
            - 本来bneを本当に実行するかはEXステージでわかる ( このプロセッサではクリティカルパスを短くするためMEMステージでわかる )
            - bneは分岐成立の回数が多いため、この段階で分岐させると1cycleの得
*/
    input wire clk, ce, do_branch, IF_do_speculative_branch;
    input wire [31:0] IF_pc, IF_instr;
    input wire [4:0] WB_reg_dest;
    input wire [31:0] WB_write_value;

    // take over from IF
    reg [31:0] pc = 0, instr = 0;
    reg did_speculative_branch;
    always @(posedge clk) #5 if(ce) begin
        pc    <= (do_branch || do_speculative_branch) ? 0                   : IF_pc;
        instr <= (do_branch || do_speculative_branch) ? {25'd0, 7'b0010011} : IF_instr;
        did_speculative_branch <= IF_do_speculative_branch;
    end

    // decode instr
    wire [4:0] short_opcode = instr[6:2];
    wire [4:0] reg_source1  = instr[19:15];
    wire [4:0] reg_source2  = instr[24:20];

    wire is_instr_to_write_reg = short_opcode == 5'b01100 // arithmetic operation with reg
                              || short_opcode == 5'b00100 // arithmetic operation with imm
                              || short_opcode == 5'b00000;// store
    wire [4:0] reg_dest     = !do_branch && is_instr_to_write_reg ? instr[11:7] : 0;

    // read registers
    wire [31:0] imm, reg_data1, reg_data2;
    m_immgen m_immgen0 (instr, imm);
    m_regfile m_regs (clk, reg_source1, reg_source2, WB_reg_dest, 1'b1, WB_write_value, reg_data1, reg_data2);

    // 分岐予測 ( IFステージでメモ化した値から分岐をした場合、分岐が重複するのでdid_speculative_branch = trueの際はdo_speculative_branchをtrueにしない )
    wire do_speculative_branch = !did_speculative_branch && {instr[12], short_opcode} == 6'b111000; // == is_bne
    wire [31:0] branch_dest_addr = pc + imm;
endmodule

module m_EX (
    clk, ce, do_branch, ID_pc, ID_instr, ID_imm,
    ID_reg_source1, ID_reg_source2, ID_reg_data1, ID_reg_data2, ID_reg_dest,
    MEM_reg_dest, WB_reg_dest, MEM_calced_value, WB_writing_value
);
/*
    1. 計算
        - レジスタの値をフォワーディングを考慮して求める
        - クリティカルパスを短くするためlhs, rhsの計算まで
*/
    input wire clk, ce, do_branch;
    input wire [31:0] ID_pc, ID_instr, ID_imm, ID_reg_data1, ID_reg_data2;
    input wire [4:0]  ID_reg_source1, ID_reg_source2, ID_reg_dest, MEM_reg_dest, WB_reg_dest;

    input wire [31:0] MEM_calced_value, WB_writing_value;

    // take over from ID
    reg [31:0] pc = 0, instr = 0, imm = 0, weak_reg_data1 = 0, weak_reg_data2 = 0;
    reg [4:0]  reg_source1 = 0, reg_source2 = 0, reg_dest = 0;

    always @(posedge clk) #5 if(ce) begin
        pc <= do_branch ? 0 : ID_pc;
        instr <= do_branch ? {25'd0, 7'b0010011} : ID_instr;
        imm <= ID_imm;
        reg_source1 <= ID_reg_source1;
        reg_source2 <= ID_reg_source2;
        weak_reg_data1 <= ID_reg_data1;
        weak_reg_data2 <= ID_reg_data2;
        reg_dest  <= ID_reg_dest;
    end

    wire [4:0] short_opcode = instr[6:2];


    wire [31:0] reg_data1 = reg_source1 == 0            ? 0
                          : reg_source1 == MEM_reg_dest ? MEM_calced_value
                          : reg_source1 == WB_reg_dest  ? WB_writing_value
                          :                               weak_reg_data1;
    wire [31:0] reg_data2 = reg_source2 == 0            ? 0
                          : reg_source2 == MEM_reg_dest ? MEM_calced_value
                          : reg_source2 == WB_reg_dest  ? WB_writing_value
                          :                               weak_reg_data2;

    wire [31:0] lhs_operand = reg_data1;
    wire [31:0] rhs_operand = (short_opcode==5'b01100 || short_opcode==5'b11000) ? reg_data2 : imm;
endmodule

module m_MEM ( clk, ce, EX_pc, EX_instr, EX_imm, EX_reg_source1, EX_reg_source2, EX_reg_data2, EX_reg_dest, EX_lhs_operand, EX_rhs_operand );
/*
    1. メモリに対してのload, store
    2. lhs, rhsを用いての計算
        - 本来EXステージで計算するが、クリティカルパスを短くするためここで計算
    3. bne, beq命令を実行するか, 投機的実行をした分岐命令を戻すかどうか ( 投機的実行が失敗したかどうか ) のフラグを計算
        - lhs, rhsを用いて分岐をするかどうかを計算
            - 本来はEXステージで(略
*/
    input wire clk, ce;
    input wire [31:0] EX_pc, EX_instr, EX_imm, EX_reg_data2, EX_lhs_operand, EX_rhs_operand;
    input wire [4:0]  EX_reg_source1, EX_reg_source2, EX_reg_dest;

    // take over from EX
    reg [31:0] pc = 0, instr = 0, imm = 0, reg_data2 = 0, lhs_operand = 0, rhs_operand = 0;
    reg [4:0]  reg_source1 = 0, reg_source2 = 0, reg_dest = 0;
    always @(posedge clk) #5 if(ce) begin
        pc           <= do_branch ? 0 : EX_pc;
        instr        <= do_branch ? {25'd0, 7'b0010011} : EX_instr;
        imm          <= EX_imm;
        reg_source1  <= EX_reg_source1;
        reg_source2  <= EX_reg_source2;
        reg_data2    <= EX_reg_data2;
        reg_dest     <= do_branch ? 0 : EX_reg_dest;
        lhs_operand  <= EX_lhs_operand;
        rhs_operand  <= EX_rhs_operand;
    end

    // 結果の計算
    wire is_sll = instr[14:12] == 3'b001;
    wire is_srl = instr[14:12] == 3'b101;
    wire [31:0] calced_value = (is_sll) ? lhs_operand << rhs_operand[4:0] :
                               (is_srl) ? lhs_operand >> rhs_operand[4:0] : lhs_operand + rhs_operand;

    // 分岐フラグ、分岐先計算
    wire is_beq = {instr[12], short_opcode} == 6'b011000;
    wire is_bne = {instr[12], short_opcode} == 6'b111000;
    wire revert_speculative_branch = (is_bne & lhs_operand == rhs_operand); // bneなのに成立した( 投機的実行の失敗 )
    wire do_branch = revert_speculative_branch || (is_beq & lhs_operand == rhs_operand);
    wire [31:0] branch_dest_addr = revert_speculative_branch ? pc + 4 : pc + imm;

    // メモリへのload, store
    wire [4:0] short_opcode = instr[6:2];
    wire is_store_instr = short_opcode == 5'b01000;
    wire [31:0] memory_data;
    //                             addr,               write enable,   write value, read value
    m_data_memory data_memory(clk, calced_value[13:2], is_store_instr, reg_data2, memory_data);
endmodule

module m_WB ( clk, ce, MEM_pc, MEM_instr, MEM_calced_value, memory_data, MEM_reg_dest );
/*
    1. loadした値を結果にするか計算した値を結果にするかの選択
*/
    input wire clk, ce;
    input wire [31:0] MEM_pc, MEM_instr, MEM_calced_value, memory_data;
    input wire [4:0]  MEM_reg_dest;

    // take over from MEM
    reg [31:0] pc = 0, instr = 0, calced_value;
    reg [4:0]  reg_dest = 0;

    always @(posedge clk) #5 if(ce) begin
        pc           <= MEM_pc;
        instr        <= MEM_instr;
        calced_value <= MEM_calced_value;
        reg_dest     <= MEM_reg_dest;
    end

    wire [4:0] short_opcode = instr[6:2];

    wire is_load_instr = short_opcode == 5'b00000;
    wire [31:0] writing_value = is_load_instr ? memory_data : calced_value;
endmodule

// プログラムが格納された非同期メモリ
module m_instr_memory ( clk, addr, out );
  input  wire clk;
  input  wire [11:0] addr;
  output reg  [31:0] out;

  reg [31:0] cm_ram [0:4095]; // 4K word (4096 x 32bit) memory
  
  always #5 out <= cm_ram[addr];

`include "../inputs/program.txt" // [[include-program]]
endmodule

// 同期メモリ
module m_data_memory (w_clk, w_addr, w_we, w_din, r_dout); // synchronous memory
    input wire w_clk, w_we;
    input wire [11:0] w_addr;
    input wire [31:0] w_din;
    output reg  [31:0] r_dout = 0;

    reg [31:0] cm_ram [0:4095]; // 4K word (4096 x 32bit) memory

    // [[delete-begin --on-vivado]]
    integer i;
    input wire [31:0] initial_value;
    initial begin
        for (i = 0; i <= 4096; i += 1) begin
            cm_ram[i] = 0;
        end
    end
    // [[delete-end --on-vivado]]

    always @(posedge w_clk) #5 if (w_we) cm_ram[w_addr] <= w_din;
    always @(posedge w_clk) #5 r_dout <= cm_ram[w_addr];
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

    assign #8 w_rdata1 = w_rr1 == 0 ? 0 : w_rr1 == w_wr ? w_wdata : r[w_rr1];
    assign #8 w_rdata2 = w_rr2 == 0 ? 0 : w_rr2 == w_wr ? w_wdata : r[w_rr2];
    always @(posedge w_clk) if(w_we) r[w_wr] <= w_wdata;
endmodule
