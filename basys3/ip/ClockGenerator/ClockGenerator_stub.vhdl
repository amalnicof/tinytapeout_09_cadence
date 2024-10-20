-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
-- Date        : Sun Oct 20 09:57:44 2024
-- Host        : Stealth running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               c:/Users/haow6/Desktop/projects/tinytapeout_09_cadence/basys3/ip/ClockGenerator/ClockGenerator_stub.vhdl
-- Design      : ClockGenerator
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a35tcpg236-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ClockGenerator is
  Port ( 
    sysClk : out STD_LOGIC;
    reset : in STD_LOGIC;
    locked : out STD_LOGIC;
    rawClk : in STD_LOGIC
  );

end ClockGenerator;

architecture stub of ClockGenerator is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "sysClk,reset,locked,rawClk";
begin
end;
