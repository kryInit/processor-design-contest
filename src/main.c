#include <stdio.h>


int main() {
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

