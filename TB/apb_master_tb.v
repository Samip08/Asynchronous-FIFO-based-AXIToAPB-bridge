`timescale 1ns/1ps

module tb_apb_master;

    // --- Testbench Clock & Reset ---
    reg clk;
    reg rst_n;

    // --- FIFO Interface ---
    reg [68:0] rfifo_rdata;
    reg        rfifo_empty;
    wire       rfifo_ren;

    // --- APB Bus Signals ---
    wire [31:0] paddr;
    wire [31:0] pwdata;
    wire [3:0]  pstrb;
    wire        pwrite;
    wire        psel;
    wire        penable;
    
    // --- Slave Responses ---
    reg [31:0] prdata;
    reg        pready;
    reg        pslverr;
    reg        rvalid;
    
    // --- Status Monitored ---
    wire       m_apb_busy;
    wire       rvalid_recieved;
    wire [2:0] m_apb_master_state;

    // --- Testbench Control Flags for Advanced Scenarios ---
    reg        inject_error;
    reg [2:0]  slave_wait_states; // Dynamic control over slave latency
    reg [2:0]  wait_counter;

    // Instantiate the RTL Module
    apb_master_fsm #(
        .DATA_WIDTH(69)
    ) uut (
        .m_apb_pclk(clk),
        .m_apb_presetn(rst_n),
        .rfifo_empty(rfifo_empty),
        .rfifo_rdata(rfifo_rdata),
        .m_apb_pready(pready),
        .m_apb_prdata(prdata),
        .m_apb_pslverr_mux(pslverr),
        .m_apb_rvalid(rvalid),
        .rfifo_ren(rfifo_ren),
        .m_apb_busy(m_apb_busy),
        .m_apb_paddr(paddr),
        .m_apb_pwrite(pwrite),
        .m_apb_pwdata(pwdata),
        .m_apb_pstrb(pstrb),
        .m_apb_penable(penable),
        .m_apb_rvalid_recieved(rvalid_recieved),
        .m_apb_psel_global(psel),
        .m_apb_master_state(m_apb_master_state)
    );

    // Clock Generator (100MHz)
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Safe Responsive Slave Model
    // -------------------------------------------------------------------------
    // Emulates a standard APB slave matching your original timing, 
    // but adds support for multi-cycle wait state stalls.
    always @(posedge clk) begin
        if (psel) begin
            if (penable) begin
                if (wait_counter > 0) begin
                    wait_counter <= wait_counter - 1'b1;
                    pready       <= 1'b0;
                    rvalid       <= 1'b0;
                end else begin
                    pready  <= 1'b1;
                    pslverr <= inject_error;
                    if (!pwrite) begin
                        rvalid <= 1'b1;
                        prdata <= (paddr == 32'h0000_0004) ? 32'hA1A1_B2B2 : 32'hDEAD_BEEF;
                    end else begin
                        rvalid <= 1'b0;
                        prdata <= 32'h0;
                    end
                end
            end else begin
                // SETUP Phase: Capture wait state settings
                wait_counter <= slave_wait_states;
                pready       <= 1'b0; 
                rvalid       <= 1'b0;
            end
        end else begin
            // Bus Is Inactive
            pready       <= 1'b0;
            pslverr      <= 1'b0;
            rvalid       <= 1'b0;
            prdata       <= 32'h0;
            wait_counter <= 3'd0;
        end
    end

    // -------------------------------------------------------------------------
    // Core Handshake Driver Task
    // -------------------------------------------------------------------------
    // Reverted back to your working 1-cycle clock-edge aligned strobe setup
    task automatic queue_fifo_packet;
        input rw;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        begin
            wait (m_apb_busy == 1'b0); // Wait for master to be free
            
            @(posedge clk);
            rfifo_rdata <= {rw, addr, data, strb};
            rfifo_empty <= 1'b0; // Drop empty flag (Data Available)
            
            @(posedge clk);
            rfifo_empty <= 1'b1; // Pull empty back high on next edge (1-cycle pulse)
            
            // Wait for FSM to cycle through the transaction and return to IDLE
            wait (m_apb_busy == 1'b1);
            wait (m_apb_busy == 1'b0);
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Orchestrated Verification Flow
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("waves.vcd"); 
        $dumpvars(0, tb_apb_master);
        
        // Step 1: System Initialization
        clk               = 0; 
        rst_n             = 0; 
        rfifo_empty       = 1; 
        rfifo_rdata       = 0;
        inject_error      = 0;
        slave_wait_states = 0;
        
        // Step 2: Release Reset
        #20 rst_n = 1; 
        #20;
        
        $display("=== STARTING APB MASTER COMPREHENSIVE VERIFICATION ===");

        // ---------------------------------------------------------------------
        // TEST CASE 1: Standard Write (0 Wait States)
        // ---------------------------------------------------------------------
        $display("\n[TC1] Launching zero-wait-state APB Write...");
        slave_wait_states = 3'd0;
        queue_fifo_packet(1'b1, 32'hAAAA_BBBB, 32'h1234_5678, 4'b1111);
        
        #40;

        // ---------------------------------------------------------------------
        // TEST CASE 2: Standard Read (0 Wait States)
        // ---------------------------------------------------------------------
        $display("\n[TC2] Launching zero-wait-state APB Read...");
        slave_wait_states = 3'd0;
        queue_fifo_packet(1'b0, 32'h0000_0004, 32'h0000_0000, 4'b0000);
        
        #40;

        // ---------------------------------------------------------------------
        // TEST CASE 3: Stalled Slave Write Operation (Wait States)
        // ---------------------------------------------------------------------
        $display("\n[TC3] Launching Stalled Slave Write (3 Wait States)...");
        slave_wait_states = 3'd3; 
        queue_fifo_packet(1'b1, 32'hE000_2000, 32'h5555_AAAA, 4'b1111);
        
        slave_wait_states = 3'd0; 
        #40;

        // ---------------------------------------------------------------------
        // TEST CASE 4: Stalled Slave Read Operation (Wait States)
        // ---------------------------------------------------------------------
        $display("\n[TC4] Launching Stalled Slave Read (2 Wait States)...");
        slave_wait_states = 3'd2;
        queue_fifo_packet(1'b0, 32'hE000_3000, 32'h0000_0000, 4'b0000);
        
        slave_wait_states = 3'd0;
        #40;

        // ---------------------------------------------------------------------
        // TEST CASE 5: Slave Error Interception (SLVERR)
        // ---------------------------------------------------------------------
        $display("\n[TC5] Triggering Slave Error Assertions...");
        inject_error = 1'b1;
        queue_fifo_packet(1'b1, 32'hDEAD_4444, 32'h9999_9999, 4'b1111);
        
        inject_error = 1'b0;
        #40;

        // Finalize
        $display("\n=== APB MASTER SIMULATION COMPLETE ===");
        $finish;
    end

    // --- Active Real-Time Protocol Assert Monitors ---
    always @(posedge clk) begin
        if (psel && !penable) begin
            $display("Time: %0t | [APB BUS] SETUP PHASE -> Addr: 0x%h | PWRITE: %b", $time, paddr, pwrite);
        end
        if (psel && penable && pready) begin
            $display("Time: %0t | [APB BUS] ACCESS HANDSHAKE COMPLETE -> PSLVERR: %b", $time, pslverr);
            if (!pwrite) begin
                $display("       >>>> Read Data Captured: 0x%h", prdata);
            end
        end
    end

endmodule