# set ::env(DESIGN_NAME) "Top_module"
# set ::env(VERILOG_FILES) [list $::env(DESIGN_DIR)/src/apb_master_fsm.v $::env(DESIGN_DIR)/src/apb_slave_mux.v $::env(DESIGN_DIR)/src/async_fifo_core.v $::env(DESIGN_DIR)/src/axi_slave_fsm.v $::env(DESIGN_DIR)/src/Top_module.v]
# set ::env(CLOCK_PORT) "clk"
# set ::env(CLOCK_PERIOD) "10"
# set ::env(FP_CORE_UTIL) "35"
# set ::env(PL_TARGET_DENSITY) "0.45"
# set ::env(SYNTH_STRATEGY) "DELAY 4"

set ::env(DESIGN_NAME) "Top_module"
set ::env(VERILOG_FILES) [glob $::env(DESIGN_DIR)/src/*.v]

# Timing Setup
# Note: If m_apb_pclk is your second clock, ensure your custom SDC file handles the CDC paths!
set ::env(CLOCK_PORT) "s_axi_aclk"
set ::env(CLOCK_PERIOD) "10.0"

# Floorplanning: Switched to Relative Sizing to Save Your RAM
set ::env(FP_SIZING) "relative"
set ::env(FP_CORE_UTIL) 40; # 40% logic density leaves 60% free space for routing paths

# IO Pin Placement Tuning
set ::env(FP_IO_MIN_DISTANCE) "2"

# Placement and Routing Congestion Tuning
set ::env(PL_TARGET_DENSITY) "0.45"
set ::env(GRT_ALLOW_CONGESTION) 1

# Parallel Execution Engine Threads (Optimized for Laptop Core Count)
set ::env(DRT_THREADS) 4