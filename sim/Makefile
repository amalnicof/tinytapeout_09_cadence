TBNAME = $(tb).sv

all:
	@echo "sim tb=<TBNAME>"
	@echo "simgui tb=<TBNAME>"
	@echo "example: sim tb=firtb"

sim:
	xrun ../tb/$(TBNAME) \
	../rtl/* \
	-access +rwc \
	-top $(tb)

simgui:
	xrun ../tb/$(TBNAME) \
	../rtl/* \
	-access +rwc \
	-top $(tb) \
	+gui

sim_fir_engine:
	xrun tb_FIREngine.sv \
	../rtl/* \
	-access +rwc \
	-top tb_FIREngine

sim_i2s_controller:
	xrun tb_I2SController.sv \
	../rtl/I2SController.sv \
	-access +rwc \
	-top tb_I2SController

clean:
	rm -rf \
	outputs \
	waves.shm \
	trace.vcd \
	xcelium.d \
	xrun.history \
	xrun.log \
	xrun.key \
	*~
