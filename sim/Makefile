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
	rm -rf waves.shm trace.vcd  xcelium.d  xrun.history  xrun.log xrun.key *~
