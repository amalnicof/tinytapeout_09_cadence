if {![info exists ::env(CLOCKPERIOD)] } {
  set clockPeriod 20
} else {
    set clockPeriod [getenv CLOCKPERIOD]
}

create_clock -name clk -period $clockPeriod [get_ports "clk"]

set_input_delay  0 -clock clk [all_inputs -no_clocks]
set_output_delay 0 -clock clk [all_outputs]
