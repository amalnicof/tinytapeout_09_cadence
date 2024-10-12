TBNAME = $(tb).sv
NETLIST = $(mod)_netlist.v

all:
	@echo "sim tb=<TBNAME> mod=<MODULENAME>"
	@echo "simgui tb=<TBNAME> mod=<MODULENAME>"
	@echo "example: sim tb=firtb mod=fir"


sim:
	xrun -timescale 1ns/1ps \
	../tb/$(TBNAME) \
	../syn/outputs/$(NETLIST) \
	/opt/cadence/libraries/gsclib045_all_v4.7/gsclib045/verilog/slow_vdd1v0_basicCells.v \
	-access +rwc \
	-define USE_SDF \
	-define NETLIST \
	-top $(tb)

simgui:
	xrun -timescale 1ns/1ps \
	../tb/$(TBNAME) \
	../syn/outputs/$(NETLIST) \
	/opt/cadence/libraries/gsclib045_all_v4.7/gsclib045/verilog/slow_vdd1v0_basicCells.v \
	-access +rwc \
	-define USE_SDF \
	-define NETLIST \
	-top $(tb) \
	+gui

clean:
	rm -rf trace.vcd  xcelium.d  xrun.history  xrun.log xrun.key *~
