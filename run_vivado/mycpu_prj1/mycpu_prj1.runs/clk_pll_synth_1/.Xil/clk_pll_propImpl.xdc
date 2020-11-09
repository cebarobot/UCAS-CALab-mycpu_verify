set_property SRC_FILE_INFO {cfile:d:/vivado_prj/CPU_CDE/mycpu_verify/rtl/xilinx_ip/clk_pll/clk_pll.xdc rfile:../../../../../rtl/xilinx_ip/clk_pll/clk_pll.xdc id:1 order:EARLY scoped_inst:inst} [current_design]
current_instance inst
set_property src_info {type:SCOPED_XDC file:1 line:57 export:INPUT save:INPUT read:READ} [current_design]
set_input_jitter [get_clocks -of_objects [get_ports clk_in1]] 0.1
