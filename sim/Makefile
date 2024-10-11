setup:
	mkdir -p outputs

sim_i2s_controller: setup
	xrun tb_I2SController.sv \
	../rtl/I2SController.sv \
	-access +rwc \
	-top tb_I2SController

sim_i2s_clock_generator: setup
	xrun tb_I2SClockGenerator.sv \
	../rtl/I2SClockGenerator.sv \
	-access +rwc \
	-top tb_I2SClockGenerator

sim_spi_slave: setup
	xrun tb_SPISlave.sv \
	../rtl/SPISlave.sv \
	-access +rwc \
	-top tb_SPISlave

sim_config_store: setup
	xrun tb_ConfigStore.sv \
	../rtl/ConfigStore.sv \
	-access +rwc \
	-top tb_ConfigStore

sim_fir_engine: setup
	xrun tb_FIREngine.sv \
	../rtl/FIREngine.sv \
	../rtl/ConfigStore.sv \
	../rtl/I2SController.sv \
	../rtl/SPISlave.sv \
	-access +rwc \
	-top tb_FIREngine

sim:
	xrun tb.sv \
	../rtl/iir.sv \
	-access +rwc \
	-top tb

simg:
	xrun tb.sv \
	../rtl/iir.sv \
	-access +rwc \
	-top tb \
	+gui

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
