# RISC-V core

**Description:**  
Verilog implementation of RISC-V RV32I ISA  
5-stage scalar core

**Goal**  
Running compiled C code on the FPGA implementation of the design and communication with the PC over UART

**Testing Methodology**  
There are two ways in which core can be tested, selected thru `` `define STANDALONE`` in the `ama_riscv_core_top_tb.sv`:
1. Standalone - relies on reading register `tohost` LSB (waits for `tohost[0] == 1`). This is the way RISC-V ISA tests are structured and any other test can use this approach
2. Vectors - exported from [ama-riscv-sim](https://github.com/AleksandarLilic/ama-riscv-sim) cycle accurate simulator and then imported into the testbench via provided [scripts](https://github.com/AleksandarLilic/ama-riscv/tree/dev/verif/scripts) which will generate `vector_import.sv` and `checkers_task.sv`

**Status:**   
Phase 1 done - Passing all [RISC-V ISA tests](https://github.com/riscv-software-src/riscv-tests); Communication with PC over UART functional

**Further development:**  
Performance Analysis and Improvements
  
### **Project Structure**
**RTL:** /src  
**Direct TB:**  /verif/direct_tb  
**Documentation:**  /docs  

### **Branches**
**Main - stable release:** main  
**Ongoing development:** dev   
**Documentation:** doc  

