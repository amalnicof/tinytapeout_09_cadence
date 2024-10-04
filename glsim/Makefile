sim-postsyn:
	xrun -timescale 1ns/1ps \
	tb.sv \
	../syn/outputs/iir_netlist.v \
	/opt/cadence/libraries/gsclib045_all_v4.7/gsclib045/verilog/slow_vdd1v0_basicCells.v \
	-access +rwc \
	-define USE_SDF \
	-top tb

sim-postsyn-gui:
	xrun -timescale 1ns/1ps \
	tb.sv \
	../syn/outputs/iir_netlist.v \
	/opt/cadence/libraries/gsclib045_all_v4.7/gsclib045/verilog/slow_vdd1v0_basicCells.v \
	-access +rwc \
	-define USE_SDF \
	-top tb \
	+gui

clean:
	rm -rf trace.vcd  xcelium.d  xrun.history  xrun.log xrun.key *~
