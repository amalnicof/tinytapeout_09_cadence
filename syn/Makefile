all: syn

syn_i2s_controller:
	BASENAME=I2SController \
		CLOCKPERIOD=31.25 \
		TIMINGPATH=/opt/skywater/libraries/sky130_fd_sc_hd/latest/timing \
		TIMINGLIB=sky130_fd_sc_hd__ss_n40C_1v76.lib \
		VERILOG='../rtl/I2SController.sv' \
		genus -f genus_script.tcl -no_gui

syn_spi_slave:
	BASENAME=SPISlave \
		CLOCKPERIOD=31.25 \
		TIMINGPATH=/opt/skywater/libraries/sky130_fd_sc_hd/latest/timing \
		TIMINGLIB=sky130_fd_sc_hd__ss_n40C_1v76.lib \
		VERILOG='../rtl/SPISlave.sv' \
		genus -f genus_script.tcl -no_gui

syn:
	BASENAME=iir \
		CLOCKPERIOD=3 \
		TIMINGPATH=/opt/cadence/libraries/gsclib045_all_v4.7/gsclib045/timing \
		TIMINGLIB=slow_vdd1v0_basicCells.lib \
		VERILOG='../rtl/iir.sv' \
		genus -f genus_script.tcl

clean:
	rm -rf outputs reports genus.log* genus.cmd* *~ fv