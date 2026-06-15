`timescale 1ns / 1ps

module axi_bridge_tb;

    parameter DATA_WIDTH = 69;

    // Clock & Reset
    reg s_axi_aclk;
    reg s_axi_aresetn;

    // AXI Write Address Channel
    reg [31:0] s_axi_awaddr;
    reg        s_axi_awvalid;
    wire       s_axi_awready;

    // AXI Write Data Channel
    reg [31:0] s_axi_wdata;
    reg [3:0]  s_axi_wstrb;
    reg        s_axi_wvalid;
    wire       s_axi_wready;

    // AXI Write Response Channel
    wire [1:0] s_axi_bresp;
    wire       s_axi_bvalid;
    reg        s_axi_bready;

    // AXI Read Address Channel
    reg [31:0] s_axi_araddr;
    reg        s_axi_arvalid;
    wire       s_axi_arready;

    // AXI Read Data/Response Channel
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;

    // Backpressure Control Wire
    reg         wfifo_full;

    // Internal Hookup Wires between FSM and ROM
    wire [4:0]  rom_addr_bus;
    wire        rom_read_en;
    wire [31:0] rom_data_bus;
    wire        rom_valid_sig;

    wire [1:0]   sw_axi_slave_state;
    wire [1:0]   sr_axi_slave_state;

    // Outbound FIFO Interconnects (Monitored by TB)
    wire                    wfifo_wen;
    wire [DATA_WIDTH-1:0]   wfifo_wdata;

    // -------------------------------------------------------------------------
    // DUT Interconnections
    // -------------------------------------------------------------------------
    axi_slave_fsm #(
        .DATA_WIDTH(DATA_WIDTH)
    ) uut_fsm (
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_rdata_rom(rom_data_bus),
        .s_axi_rready(s_axi_rready),
        .mem_valid(rom_valid_sig),
        .wfifo_full(wfifo_full),
        .s_axi_awready(s_axi_awready),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rid(rom_addr_bus),
        .s_axi_ext_rena(rom_read_en),
        .wfifo_wen(wfifo_wen),
        .wfifo_wdata(wfifo_wdata),
        .sw_axi_slave_state(sw_axi_slave_state),
        .sr_axi_slave_state(sr_axi_slave_state)
    );

    rom_memory #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(5)
    ) uut_rom (
        .addr(rom_addr_bus),
        .read_en(rom_read_en),
        .data(rom_data_bus),
        .valid(rom_valid_sig)
    );

    // -------------------------------------------------------------------------
    // Clock Generation (100MHz)
    // -------------------------------------------------------------------------
    initial begin
        s_axi_aclk = 0;
        forever #5 s_axi_aclk = ~s_axi_aclk;
    end

    // -------------------------------------------------------------------------
    // Low-Level AXI Master Driver Tasks
    // -------------------------------------------------------------------------

    // Robust Write Channel Driver (Handles out-of-order or decoupled ready flags)
    task automatic axi_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        reg aw_done;
        reg w_done;
        begin
            aw_done = 0;
            w_done  = 0;
            
            @(posedge s_axi_aclk);
            #1; // Offset to prevent race conditions
            s_axi_awaddr  = addr;
            s_axi_awvalid = 1'b1;
            s_axi_wdata   = data;
            s_axi_wstrb   = strb;
            s_axi_wvalid  = 1'b1;

            fork
                // Handle AW handshake
                begin
                    while (!aw_done) begin
                        if (s_axi_awvalid && s_axi_awready) begin
                            @(posedge s_axi_aclk);
                            #1;
                            s_axi_awvalid = 1'b0;
                            aw_done = 1'b1;
                        end else begin
                            @(posedge s_axi_aclk);
                            #1;
                        end
                    end
                end
                // Handle W handshake
                begin
                    while (!w_done) begin
                        if (s_axi_wvalid && s_axi_wready) begin
                            @(posedge s_axi_aclk);
                            #1;
                            s_axi_wvalid = 1'b0;
                            w_done = 1'b1;
                        end else begin
                            @(posedge s_axi_aclk);
                            #1;
                        end
                    end
                end
            join

            // Wait for Response (B Channel)
            while (!s_axi_bvalid) begin
                @(posedge s_axi_aclk);
                #1;
            end
            
            $display("Time: %0t | [WRITE CHANNEL] Addr: 0x%h -> Data: 0x%h | Resp: 2'b%b", 
                     $time, addr, data, s_axi_bresp);
            
            if (s_axi_bresp == 2'b10) begin
                $display("       >>>> Verification Note: Confirmed SLVERR Trap Matched!");
            end

            @(posedge s_axi_aclk);
            #1;
        end
    endtask

    // Robust Read Channel Driver
    task automatic axi_read;
        input [31:0] addr;
        begin
            @(posedge s_axi_aclk);
            #1;
            s_axi_araddr  = addr;
            s_axi_arvalid = 1'b1;

            while (!s_axi_arready) begin
                @(posedge s_axi_aclk);
                #1;
            end
            
            @(posedge s_axi_aclk);
            #1;
            s_axi_arvalid = 1'b0;

            // Wait for Read Data and Valid back from Slave
            while (!s_axi_rvalid) begin
                @(posedge s_axi_aclk);
                #1;
            end

            $display("Time: %0t | [READ CHANNEL]  Addr: 0x%h -> Data Extracted: 0x%h | Resp: 2'b%b", 
                     $time, addr, s_axi_rdata, s_axi_rresp);
            
            @(posedge s_axi_aclk);
            #1;
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("pipeline_doom.vcd");
        $dumpvars(0, axi_bridge_tb);

        // Clear system state
        s_axi_aresetn = 1'b0;
        s_axi_awaddr  = 32'h0;
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = 32'h0;
        s_axi_wstrb   = 4'h0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b1; // Ready to accept responses immediately
        s_axi_araddr  = 32'h0;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b1; // Ready to accept read data immediately
        wfifo_full    = 1'b0;

        #40;
        s_axi_aresetn = 1'b1;
        repeat(3) @(posedge s_axi_aclk);

        $display("=== STARTING COMPREHENSIVE BRIDGE SYSTEM TEST ===");

        // ---------------------------------------------------------------------
        // SCENARIO 1: Basic Operational Writes
        // ---------------------------------------------------------------------
        $display("\n--- Running Scenario 1: Standard System Writes ---");
        axi_write(32'h5000cafe, 32'hdeadbeef, 4'b1111);
        axi_write(32'h1000aaaa, 32'h12345678, 4'b1111);

        // ---------------------------------------------------------------------
        // SCENARIO 2: Error Trapping & Overrides
        // ---------------------------------------------------------------------
        $display("\n--- Running Scenario 2: Trap Address Error Handling ---");
        // Address starts with 0x2, should trigger 2'b10 (SLVERR)
        axi_write(32'h2000baba, 32'haaaa5555, 4'b1111);

        // ---------------------------------------------------------------------
        // SCENARIO 3: Consecutive ROM Flash Reads
        // ---------------------------------------------------------------------
        $display("\n--- Running Scenario 3: Sequential ROM Memory Reads ---");
        // Read lines from the initialized ROM array (0x00 to 0x03)
        axi_read(32'h00000000); // Should yield 32'hA0
        axi_read(32'h00000001); // Should yield 32'hA1
        axi_read(32'h00000002); // Should yield 32'hA2
        axi_read(32'h00000003); // Should yield 32'hA3

        // ---------------------------------------------------------------------
        // SCENARIO 4: Parallel Pipeline / Stutter Interleaving
        // ---------------------------------------------------------------------
        $display("\n--- Running Scenario 4: Concurrency Stress Test ---");
        fork
            axi_write(32'h50001111, 32'h99998888, 4'b1111);
            axi_read(32'h0000001F); // Read index 31 (Should yield 32'hBF)
        join

        // ---------------------------------------------------------------------
        // SCENARIO 5: Downstream FIFO Backpressure Stalling
        // ---------------------------------------------------------------------
        $display("\n--- Running Scenario 5: FIFO Backpressure Hold Verification ---");
        wfifo_full = 1'b1;
        $display("Time: %0t | [TB NOTICE] Artificially setting FIFO Full flag.", $time);
        
        fork
            begin
                // This transaction should get stuck in SW_WAITING because FIFO is full
                axi_write(32'h50002222, 32'h77776666, 4'b1111);
            end
            begin
                repeat(5) @(posedge s_axi_aclk);
                #1;
                $display("Time: %0t | [TB NOTICE] Releasing FIFO Full flag backpressure.", $time);
                wfifo_full = 1'b0;
            end
        join

        // Finalize
        repeat(10) @(posedge s_axi_aclk);
        $display("\n=== SYSTEM SIMULATION COMPLETE ===");
        $finish;
    end

    // Monitor FIFO Structural Output to catch bad writes instantly
    always @(posedge s_axi_aclk) begin
        if (wfifo_wen) begin
            $display("Time: %0t | [FIFO MONITOR] Captured Data Write Pipeline: Push Flag = %b | Payload Out = 0x%h", 
                     $time, wfifo_wdata[68], wfifo_wdata[67:0]);
        end
    end

endmodule