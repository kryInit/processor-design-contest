#include <stdio.h>


int main() {
//    int cmds[50] = { 0x00000033 ,0x00000033 ,0x00000a13 ,0x00300a93 ,0x00000633 ,0x00000593 ,0x40000413 ,0x40040413 ,0x00000493 ,0x00000513 ,0x00b52023 ,0x00148493 ,0x00458593 ,0x00959cb3 ,0x009cdd33 ,0x00058593 ,0x00450513 ,0x00940463 ,0xfe0410e3 ,0x40000413 ,0x40040413 ,0x00000493 ,0x00000513 ,0x00052583 ,0x00148493 ,0x00450513 ,0x00b60633 ,0x00160613 ,0xfff60613 ,0x00160613 ,0x00160613 ,0xfff60613 ,0x00160613 ,0xffe60613 ,0xfc941ae3 ,0x015d5d33 ,0x001a0a13 ,0x01140413 ,0x01240413 ,0x01340413 ,0x01440413 ,0xf75a18e3 ,0x00000033 ,0x00060f33 ,0x000f0033 ,0x00000033 ,0x00000033 ,0x00000033 ,0x00000033 ,0x00000033 };
//
//    for(int i=0; i<50; ++i) {
//        printf("[ %2d ] ", i);
//        int cmd = cmds[i];
//        int op_code = cmd&127;
//        int rd = (cmd>>7)&31;
//        int funct3 = (cmd>>12)&7;
//        int rs1 = (cmd>>15)&31;
//        int rs2 = (cmd>>20)&31;
//        int imm = (cmd>>20)&4095;
//        int imm2 = (cmd>>25)&127;
//
//        if (op_code == 0b0010011) printf("x[%d] = x[%d] + %d;\n", rd, rs1, imm);
//        else if (op_code == 0b0110011) {
//            if (funct3 == 0b000)      printf("x[%d] = x[%d] + x[%d];\n", rd, rs1, rs2);
//            else if (funct3 == 0b001) printf("x[%d] = x[%d] << x[%d];\n", rd, rs1, rs2);
//            else if (funct3 == 0b101) printf("x[%d] = x[%d] >> x[%d];\n", rd, rs1, rs2);
//        }
//        else if (op_code == 0b0100011) {
//            const int actual_imm = (imm2 << 5) + rd;
//            printf("memory[ x[%d] + %d ] = x[%d];\n", rs1, actual_imm, rs2);
//        }
//        else if (op_code == 0b0000011) {
//            printf("x[%d] = memory[ x[%d] + %d ];\n", rd, rs1, imm);
//        }
//        else if (op_code == 0b1100011) {
//            if (funct3 == 0b000) {
//                int actual_imm = (rd & 30) + ((imm2 & 63)<<5) + ((rd&1)<<11) + ((imm2&64)<<6);
//                if (actual_imm >= 4096) actual_imm = actual_imm - 8192;
//                printf("if ( x[%d] == x[%d] ) goto %d\n", rs1, rs2, actual_imm);
//            } else if (funct3 == 0b001) {
//                int actual_imm = (rd & 30) + ((imm2 & 63)<<5) + ((rd&1)<<11) + ((imm2&64)<<6);
//                if (actual_imm >= 4096) actual_imm = actual_imm - 8192;
//                printf("if ( x[%d] != x[%d] ) goto %d\n", rs1, rs2, actual_imm);
//
//            }
//        } else printf("not found\n");
//    }
//
//    return 0;


    int memory[4096] = {};
    int x[30];

    x[20] = 0;                     //     addi x20, x0,  0
    x[21] = 3;                     //     addi x21, x0,  3
    x[12] = 0;                     //     add  x12, x0,  x0
    L03: x[11] = 0;                // L03:addi x11, x0,  0
    x[8] = 1024;                   //     addi x8,  x0,  1024
    x[8] = x[8] + 1024;            //     addi x8,  x8,  1024
    x[9] = 0;                      //     addi x9,  x0,  0
    x[10] = 0;                     //     addi x10, x0,  0
    L01: memory[x[10]>>2] = x[11];    // L01:sw   x11, 0(x10)
    x[9] = x[9] + 1;               //     addi x9,  x9,  1
    x[11] = x[11] + 4;             //     addi x11, x11, 4
    x[25] = x[11] << x[9];         //     sll  x25 x11, x9
    x[26] = x[25] >> x[9];         //     srl  x26, x25, x9
    x[11] = x[11] + 0;             //     addi x11, x11, 0
    x[10] = x[10] + 4;             //     addi x10, x10, 4
    if (x[8] == x[9]) goto L04;    //     beq  x8,  x9,  L04
    if (x[8] != 0) goto L01;       //     bne  x8,  x0,  L01
    L04: x[8] = 1024;              // L04:addi x8,  x0,  1024
    x[8] = x[8] + 1024;            //     addi x8,  x8,  1024
    x[9] = 0;                      //     addi x9,  x0,  0
    x[10] = 0;                     //     addi x10, x0,  0
    L02: x[11] = memory[x[10]>>2];    // L02:lw   x11, 0(x10)
    x[9] = x[9] + 1;               //     addi x9,  x9,  1
    x[10] = x[10] + 4;             //     addi x10, x10, 4
    x[12] = x[12] + x[11];         //     add  x12, x12, x11
    x[12] = x[12] + 1;             //     addi x12, x12, 1
    x[12] = x[12] - 1;             //     addi x12, x12, -1
    x[12] = x[12] + 1;             //     addi x12, x12, 1
    x[12] = x[12] + 1;             //     addi x12, x12, 1
    x[12] = x[12] - 1;             //     addi x12, x12, -1
    x[12] = x[12] + 1;             //     addi x12, x12, 1
    x[12] = x[12] - 2;             //     addi x12, x12, -2
    if (x[8] != x[9]) goto L02;    //     bne  x8,  x9,  L02
    x[26] = x[26] >> x[21];        //     srl  x26, x26, x21
    x[20] = x[20] + 1;             //     addi x20, x20, 1
    x[8] = x[8] + 0x11;            //     addi x8,  x8,  0x11
    x[8] = x[8] + 0x12;            //     addi x8,  x8,  0x12
    x[8] = x[8] + 0x13;            //     addi x8,  x8,  0x13
    x[8] = x[8] + 0x14;            //     addi x8,  x8,  0x14
    if (x[20] != x[21]) goto L03;  //     bne  x20, x21, L03

    int result = x[12];            //     add  x30, x12, x0

    printf("%8x\n", result);
}

