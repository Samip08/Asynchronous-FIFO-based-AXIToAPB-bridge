Module 1: axi_slave_fsm.v (AXI Clock Domain)
This module interfaces directly with the master CPU. It captures the address and data phases using standard AXI4-Lite handshake logic and prepares the packet for the FIFO.

Inputs:

s_axi_aclk — Global high-speed clock.

s_axi_aresetn — Active-low synchronous reset.

s_axi_awaddr[31:0] — Write address from CPU.

s_axi_awvalid — Master valid signal for write address.

s_axi_wdata[31:0] — Write data from CPU.

s_axi_wstrb[3:0] — Byte strobes for write data.

s_axi_wvalid — Master valid signal for write data.

s_axi_bready — Master ready signal to accept write response.

s_axi_araddr[31:0] — Read address from CPU.

s_axi_arvalid — Master valid signal for read address.

s_axi_rready — Master ready signal to accept read data.

wfifo_full — Status flag from the Async FIFO indicating no more write space.

Outputs:

s_axi_awready — Slave ready signal for write address.

s_axi_wready — Slave ready signal for write data.

s_axi_bresp[1:0] — Write transaction status response (OKAY/SLVERR).

s_axi_bvalid — Slave valid signal for write response.

s_axi_arready — Slave ready signal for read address.

s_axi_rdata[31:0] — Read data payload routed from the FIFO back to the CPU.

s_axi_rresp[1:0] — Read transaction status response (OKAY/SLVERR).

s_axi_rvalid — Slave valid signal for read data.

wfifo_wen — Write enable control line to push data into the FIFO.

wfifo_wdata[68:0] — The compiled packet to write into the FIFO (typically containing Address + Data + Write/Read Command flag + Strobes).

Module 2: async_fifo_core.v (Dual Clock Domain)
The central mailbox. It houses the storage registers and handles the Gray-coded pointer synchronization loops across the asynchronous clock boundary.

Inputs:

wclk (connected to s_axi_aclk) — Write domain clock.

wrst_n (connected to s_axi_aresetn) — Write domain reset.

winc (connected to wfifo_wen) — Write increment/enable pulse.

wdata[68:0] (connected to wfifo_wdata) — Parallel data packet to be stored.

rclk (connected to m_apb_pclk) — Read domain clock.

rrst_n (connected to m_apb_presetn) — Read domain reset.

rinc (connected to rfifo_ren) — Read increment/enable pulse.

Outputs:

rdata[68:0] (connected to rfifo_rdata) — Parallel data packet popped out of storage.

wfull (connected to wfifo_full) — Full flag generated synchronously to the write clock.

rempty (connected to rfifo_empty) — Empty flag generated synchronously to the read clock.

Module 3: apb_master_fsm.v (APB Clock Domain)
This module watches the FIFO read port, pulls down transaction requests when the empty flag drops, and drives the global APB bus through its 3-phase execution cycle.

Inputs:

m_apb_pclk — Global low-speed peripheral clock.

m_apb_presetn — Active-low synchronous reset.

rfifo_empty — Status flag from the Async FIFO indicating no data is available to read.

rfifo_rdata[68:0] — The raw packet popped from the FIFO containing the decoupled address and data commands.

m_apb_pready — Ready signal returned from the currently selected active peripheral.

m_apb_prdata[31:0] — Read data payload returned from the active peripheral.

m_apb_pslverr_mux — Consolidated error status line from the peripheral decoder multiplexer.

Outputs:

rfifo_ren — Read enable pulse sent to the FIFO to advance the internal read pointer.

m_apb_paddr[31:0] — Outbound address bus driven to all peripheral inputs.

m_apb_pwrite — Control wire indicating direction (High = Write, Low = Read).

m_apb_pwdata[31:0] — Outbound write data driven to all peripheral inputs.

m_apb_pstrb[3:0] — Outbound byte selection strobes.

m_apb_penable — Strobe used to transition the APB bus from the Setup Phase into the Access Phase.

m_apb_psel_global — Master select signal indicating an active peripheral access cycle is underway.

Module 4: apb_slave_mux.v (APB Clock Domain)
The address decoder and routing matrix. It splits the master select signal into dedicated lines for individual peripherals and filters return traffic back to the master.

Inputs:

m_apb_paddr[31:0] — Address bus from the APB Master.

m_apb_psel_global — Master select indication wire.

prdata_s0[31:0], prdata_s1[31:0], ... — Individual read data buses coming back from Slave 0, Slave 1, etc.

pready_s0, pready_s1, ... — Individual ready flags coming back from Slave 0, Slave 1, etc.

pslverr_s0, pslverr_s1, ... — Individual slave error flags coming back from Slave 0, Slave 1, etc.

Outputs:

m_apb_psel[c_apb_num_slaves-1:0] — One-hot vector where only the bit matching the targeted peripheral address space goes high.

m_apb_pready — Routed ready wire from the active peripheral back to the APB Master.

m_apb_prdata[31:0] — Multiplexed read data wire from the active peripheral back to the APB Master.

m_apb_pslverr_mux — Routed error wire from the active peripheral back to the APB Master.

Module 5: axi_apb_bridge_top.v (Structural Wrapper)
This has no logic gates of its own. Its ports match the external boundary of your overall chip layout block, and its interior consists solely of wire declarations mapping the outputs of one module to the inputs of another.