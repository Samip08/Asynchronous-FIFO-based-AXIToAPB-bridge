1. The Write Transaction Flow
The AXI master (CPU) sends writes across two separate channels (AW for address, W for data). Your FSM must capture both, merge them, and send a completion status back on the B channel.

Step A: The Handshake Phase
Goal: Wait for the CPU to provide a valid address and data.

Logic: Look at s_axi_awvalid and s_axi_wvalid.

The Catch: The AXI master can assert these on the exact same clock cycle, or one might arrive a cycle earlier than the other. Your FSM must track when both have arrived (using registers or states) before moving forward.

Action: Once both are valid and your FIFO isn't full (!wfifo_full), you assert s_axi_awready and s_axi_wready high to lock in and swallow the incoming parameters.

Step B: Packet Packing & FIFO Push
Goal: Translate the raw variables into your 69-bit FIFO format.

Action: You combine the captured data into wfifo_wdata and strike wfifo_wen high for exactly one clock cycle.

The 69-Bit Mapping Structure:

[68]: Command Type Flag (1 for Write, 0 for Read)

[67:36]: Address (s_axi_awaddr)

[35:4]: Data (s_axi_wdata)

[3:0]: Strobes (s_axi_wstrb)

Step C: The Response Phase
Goal: Tell the CPU the write is complete.

Action: Set s_axi_bresp = 2'b00 (OKAY) and drive s_axi_bvalid high. Wait until the master asserts s_axi_bready to drop them back to low. Transaction complete.

2. The Read Transaction Flow
Reading is slightly different. The CPU sends a read address request on the AR channel. Your FSM needs to treat this request as a packet that also gets pushed into the FIFO, instructing the backend device to perform a read operation.

Step A: Read Request Capture
Goal: Listen for an incoming read address from the master CPU.

Logic: Wait for s_axi_arvalid to go high.

Action: If the FIFO is not full, assert s_axi_arready to accept the read address.

Step B: Read Command Packaging
Goal: Turn this read request into a command packet for the FIFO.

Action: Drive wfifo_wen high for one cycle. Pack wfifo_wdata with the read details.

The Read Mapping Structure:

[68]: Command Type Flag (0 for Read)

[67:36]: Address (s_axi_araddr)

[35:0]: Pad with zeros (Data and strobes don't matter during a read request).

Step C: Read Response Return
Goal: Return the actual data back to the CPU over the R channel.

Logic: For an AXI-Lite command-pass-through design, after pushing the read request command into the FIFO, your FSM can assert s_axi_rvalid high, set s_axi_rresp = 2'b00, and route the response loop.

Action: Hold s_axi_rvalid high until the master drops a s_axi_rready handshake.



################################################################################################################################
The Validity Rule: Once a channel asserts its VALID signal high, it is strictly forbidden to drop VALID low or change the value of the payload (DATA or ADDR) until the receiver asserts its READY signal high for at least one clock cycle.

What this means for your FSM:
If s_axi_awvalid comes up high at cycle 1, but s_axi_wvalid is low, the CPU must hold that exact address stable on s_axi_awaddr and keep s_axi_awvalid at 1 until your FSM drives s_axi_awready high to accept it. The data/address will never just vanish or change mid-handshake.

Because of this rule, there are only 3 possible scenarios your write logic needs to handle:

Scenario 1: The Perfect Pair (Simultaneous Arrival)
s_axi_awvalid and s_axi_wvalid both arrive high on the exact same clock cycle.

Your FSM action: You instantly fire s_axi_awready = 1 and s_axi_wready = 1, capture both inputs into your FIFO packet buffer in one shot, and move straight to pushing it.

Scenario 2: Address First, Data Later
s_axi_awvalid goes high, but s_axi_wvalid is low.

Your FSM action: You can set s_axi_awready = 1 immediately to swallow the address and store it in an internal temporary register. You then move to a state where you keep s_axi_awready = 0 and just wait for s_axi_wvalid to eventually show up. Because of the protocol rule, that address is safely locked in your internal register; you don't care if the CPU drops the external line later.

Scenario 3: Data First, Address Later
s_axi_wvalid goes high, but s_axi_awvalid is low.

Your FSM action: Exactly like Scenario 2, but reversed. You assert s_axi_wready = 1 to capture the data and its strobes into a temporary register, then sit and wait for s_axi_awvalid to show up.



################################################################################################################################

