// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
// Date        : Thu Oct 10 20:57:57 2024
// Host        : Spire running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/haow6/Desktop/projects/tinytapeout_09_cadence/basys3/ip/ClockGenerator/ClockGenerator_stub.v
// Design      : ClockGenerator
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a35tcpg236-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module ClockGenerator(sysClk, reset, locked, rawClk)
/* synthesis syn_black_box black_box_pad_pin="reset,locked,rawClk" */
/* synthesis syn_force_seq_prim="sysClk" */;
  output sysClk /* synthesis syn_isclock = 1 */;
  input reset;
  output locked;
  input rawClk;
endmodule
