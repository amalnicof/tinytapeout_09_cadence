MODULE = $(sv).sv

all:
	@echo "syn sv=<top_module> clk=<clk_period>"
	@echo "example: syn sv=fir clk=3"

syn:
	BASENAME=$(sv) \
	CLOCKPERIOD=$(clk) \
	TIMINGPATH=/opt/skywater/libraries/sky130_fd_sc_hd/latest/timing/ \
	TIMINGLIB=sky130_fd_sc_hd__ss_n40C_1v76.lib \
	VERILOG='../rtl/$(MODULE)' \
	genus -f genus_script.tcl -no_gui

syn_fir_engine:
	BASENAME=FIREngine \
	CLOCKPERIOD=20 \
	TIMINGPATH=/opt/skywater/libraries/sky130_fd_sc_hd/latest/timing/ \
	TIMINGLIB=sky130_fd_sc_hd__ss_n40C_1v76.lib \
	VERILOG="ConfigStore.sv fir.sv FIREngine.sv I2SController.sv SPISlave.sv" \
	genus -f genus_script.tcl -no_gui

clean:
	rm -rf outputs reports genus.log* genus.cmd* *~ fv

