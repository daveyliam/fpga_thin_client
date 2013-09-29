FPGA Thin Client
================

A Thin Client implemented in hardware on an FPGA chip.

The target platform was a Digilent Atlys Spartan 6 development board.

This was my Final Year Engineering project in 2011.


Directories
-----------

The 'doc' directory contains my thesis and seminar slides.

The 'src' directory contains the C code for the QEMU modification and also
a short program to send raw frames to the FPGA for testing.

The 'vlog' directory contains the Verilog code for the FPGA hardware design.
Note that the DDR2 controller is missing, it was generated automatically
by ISE and contained a lot of non editable .ncd files.

I can provide the complete Xilinx ISE project if anyone is interested.
