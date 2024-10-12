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

clean:
	rm -rf waves.shm trace.vcd  xcelium.d  xrun.history  xrun.log xrun.key *~
