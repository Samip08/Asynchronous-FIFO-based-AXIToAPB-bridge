`timescale 1ns/1ps

module tb_apb_master;
    // --- Testbench Clock & Reset ---
    reg clk;
    reg rst_n;

    // --- FIFO Interface ---
    reg [68:0] rfifo_rdata;
    reg rfifo_empty;
    wire rfifo_ren;

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

    // --- Testbench Control Flags ---
    reg inject_error;

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
        .m_apb_psel_global(psel)
    );

    // Clock Generator (100MHz)
    always #5 clk = ~clk;

    // --- Unified Responsive Slave Model ---
    // Responds dynamically based on whether the Master targets a Read, Write, or Error cycle
    always @(posedge clk) begin
        if (psel) begin
            pready  <= 1'b1;
            pslverr <= inject_error; // Triggers if testbench arms the error flag
            
            if (!pwrite) begin
                // Read Access Sequence
                rvalid <= 1'b1;
                prdata <= 32'hDEAD_BEEF; // Keeps our signature magic number!
            end else begin
                // Write Access Sequence
                rvalid <= 1'b0;
                prdata <= 32'h0;
            end
        end else begin
            // Bus is inactive
            pready  <= 1'b0;
            pslverr <= 1'b0;
            rvalid  <= 1'b0;
            prdata  <= 32'h0;
        end
    end

    // --- Main Test Sequence ---
    initial begin
        $dumpfile("waves.vcd"); 
        $dumpvars(0, tb_apb_master);
        
        // Step 1: System Initialization
        clk = 0; 
        rst_n = 0; 
        rfifo_empty = 1; 
        rfifo_rdata = 0;
        inject_error = 0;
        
        // Step 2: Release Reset
        #20 rst_n = 1; 
        #20;
        
        // ---------------------------------------------------------
        // TRANSACTION 1: Standard Write (Hits M_IDLE -> M_WAITING -> M_WRITING)
        // ---------------------------------------------------------
        $display("[TB] Sending Write Command...");
        // Arguments: rw (1=Write), addr, data, strb
        do_transaction(1'b1, 32'hAAAA_BBBB, 32'h1234_5678, 4'b1111);
        
        #40; // Small delay gap between commands to clearly separate waveforms

        // ---------------------------------------------------------
        // TRANSACTION 2: Standard Read (Hits M_IDLE -> M_WAITING -> M_READING)
        // ---------------------------------------------------------
        $display("[TB] Sending Read Command...");
        // Arguments: rw (0=Read), addr, data (ignored), strb (ignored)
        do_transaction(1'b0, 32'hCCCC_DDDD, 32'h0, 4'b0);
        
        #40;

        // ---------------------------------------------------------
        // TRANSACTION 3: Error Injection (Hits M_RESPONSE)
        // ---------------------------------------------------------
        $display("[TB] Sending Write Command with Error Injection...");
        force_error_transaction();
        
        // Wrap up simulation cleanly
        #100;
        $display("[TB] All transaction testing complete.");
        $finish;
    end

    // --- Task: Handles Standard Read / Write Handshaking ---
    task do_transaction(input rw, input [31:0] addr, input [31:0] data, input [3:0] strb);
        begin
            wait (m_apb_busy == 1'b0); // Ensure FSM is back in IDLE
            
            @(posedge clk);
            rfifo_rdata <= {rw, addr, data, strb};
            rfifo_empty <= 1'b0; // Signal that data is ready in FIFO
            
            @(posedge clk);
            rfifo_empty <= 1'b1; // De-assert FIFO request pulse
            
            // Wait until FSM handles it and fully goes back down to IDLE
            wait (m_apb_busy == 1'b1);
            wait (m_apb_busy == 1'b0);
        end
    endtask

    // --- Task: Forces FSM directly into M_RESPONSE ---
    task force_error_transaction();
        begin
            wait (m_apb_busy == 1'b0);
            
            @(posedge clk);
            rfifo_rdata <= {1'b1, 32'hEEEE_FFFF, 32'h9999_9999, 4'b1111};
            rfifo_empty <= 1'b0;
            inject_error <= 1'b1; // Arm slave to assert pslverr_mux when psel goes high
            
            @(posedge clk);
            rfifo_empty <= 1'b1;
            
            // Wait for FSM to detect error and transition out to response state
            wait (m_apb_busy == 1'b1);
            wait (m_apb_busy == 1'b0);
            
            inject_error <= 1'b0; // Disarm error tracking for future loops
        end
    endtask

endmodule