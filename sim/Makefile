setup:
	mkdir -p outputs

sim_i2s_controller: setup
	xrun tb_I2SController.sv \
	../rtl/I2SController.sv \
	-access +rwc \
	-top tb_I2SController

sim_spi_slave: setup
	xrun tb_SPISlave.sv \
	../rtl/SPISlave.sv \
	-access +rwc \
	-top tb_SPISlave


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
