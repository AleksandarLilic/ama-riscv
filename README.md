# RISC-V core

**Description:**  
Verilog implementation of RISC-V RV32I ISA as 5-stage scalar core  
Runs compiled C code on the FPGA and provides communication with the PC over UART

**Testing Methodology**  
There are two supported mechanisms in which the core can be tested:  
1. Self-checking - relies on reading register `tohost` LSB (testbench waits for `tohost[0] == 1` to end the simulation)
2. DPI - cosimulation with the purpose built instruction set simulator [ama-riscv-sim](https://github.com/AleksandarLilic/ama-riscv-sim) with the testbench checkers on per instruction basis (TBD)

**Status:**   
All [RISC-V ISA tests](https://github.com/riscv-software-src/riscv-tests) are passing  
Communication with PC over UART functional

# Running tests
TBD