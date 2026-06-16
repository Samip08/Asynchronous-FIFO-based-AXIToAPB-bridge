`timescale 1ns/1ps

module Top_module_tb;

    // Parameters matching your Top_module defaults
    parameter C_APB_NUM_SLAVES = 16;
    parameter C_DATA_WIDTH     = 32;
    parameter C_ADDR_WIDTH     = 32;
    parameter STRB_WIDTH       = 4;

    // --- Clock & Reset Signals ---
    reg  s_axi_aclk;
    reg  s_axi_aresetn;
    reg  m_apb_pclk;
    reg  m_apb_presetn;

    // --- AXI Master Stimulus Regs ---
    reg [C_ADDR_WIDTH-1:0]   s_axi_awaddr;
    reg                      s_axi_awvalid;
    reg [C_DATA_WIDTH-1:0]   s_axi_wdata;
    reg                      s_axi_wvalid;
    reg [STRB_WIDTH-1:0]     s_axi_wstrb;
    reg                      s_axi_bready;
    reg [C_ADDR_WIDTH-1:0]   s_axi_araddr;
    reg                      s_axi_arvalid;
    reg                      s_axi_rready;

    // --- AXI Outputs to Monitor ---
    wire                     s_axi_awready;
    wire                     s_axi_wready;
    wire [1:0]               s_axi_bresp;
    wire                     s_axi_bvalid;
    wire                     s_axi_arready;
    wire [C_DATA_WIDTH-1:0]  s_axi_rdata;
    wire [1:0]               s_axi_rresp;
    wire                     s_axi_rvalid;
    
    // NEW AXI STATUS WIRES
    wire                     s_axi_rbusy;
    wire [C_DATA_WIDTH-1:0]  s_axi_rdata_return;

    // --- APB Bus Wires ---
    wire [C_ADDR_WIDTH-1:0]  m_apb_paddr;
    wire                     m_apb_penable;
    wire                     m_apb_pwrite;
    wire [C_DATA_WIDTH-1:0]  m_apb_pwdata;
    wire [STRB_WIDTH-1:0]    m_apb_pstrb;
    wire [C_APB_NUM_SLAVES-1:0] m_apb_psel;
    wire [C_DATA_WIDTH-1:0]  m_apb_pslverrmsg_mux;

    // --- Mock Peripheral Arrays ---
    wire [(C_APB_NUM_SLAVES*32)-1:0] prdata_slaves;
    wire [C_APB_NUM_SLAVES-1:0]      pready_slaves;
    wire [C_APB_NUM_SLAVES-1:0]      pslverr_slaves;
    wire [(C_APB_NUM_SLAVES*32)-1:0] pslverrmsg_slaves;
    wire [2:0]                       m_apb_master_state;
    wire [1:0]                       sw_axi_slave_state, sr_axi_slave_state;
    wire                             apb_master_busy;

    // =========================================================
    // SMART SLAVE MOCK LOGIC
    // =========================================================
    // Auto-assert pready whenever any slave's psel goes high
    assign pready_slaves = m_apb_psel; 

    // Target Slave Error Logic
    assign pslverr_slaves = (m_apb_paddr == 32'h4200_2222) ? m_apb_psel : {C_APB_NUM_SLAVES{1'b0}};

    // Constant data coming back from mock slaves
    assign prdata_slaves    = {C_APB_NUM_SLAVES{32'hc001d00d}}; 
    assign pslverrmsg_slaves = {C_APB_NUM_SLAVES{32'h0badc0de}};

    // =========================================================
    // DEVICE UNDER TEST (DUT) INSTANTIATION
    // =========================================================
    Top_module #(
        .C_APB_NUM_SLAVES(C_APB_NUM_SLAVES),
        .C_DATA_WIDTH(C_DATA_WIDTH),
        .C_ADDR_WIDTH(C_ADDR_WIDTH)
    ) u_dut (
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),
        .m_apb_pclk(m_apb_pclk),
        .m_apb_presetn(m_apb_presetn),
        
        // Write Address Channel
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        
        // Write Data Channel
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wready(s_axi_wready),
        
        // Write Response Channel
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        
        // Read Address Channel
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        
        // Read Data Channel
        .s_axi_rready(s_axi_rready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        
        // New Read Pipeline Connections
        .s_axi_rbusy(s_axi_rbusy),
        .s_axi_rdata_return(s_axi_rdata_return),

        // APB Slave Side connections
        .prdata_slaves(prdata_slaves),
        .pready_slaves(pready_slaves),
        .pslverr_slaves(pslverr_slaves),
        .pslverrmsg_slaves(pslverrmsg_slaves),
        
        // APB Master Output Bus
        .m_apb_paddr(m_apb_paddr),
        .m_apb_penable(m_apb_penable),
        .m_apb_pwrite(m_apb_pwrite),
        .m_apb_pwdata(m_apb_pwdata),
        .m_apb_pstrb(m_apb_pstrb),
        .m_apb_psel(m_apb_psel),
        .m_apb_pslverrmsg_mux(m_apb_pslverrmsg_mux),
        
        // Debug/State Tracking
        .m_apb_master_state(m_apb_master_state),
        .sw_axi_slave_state(sw_axi_slave_state),
        .sr_axi_slave_state(sr_axi_slave_state),
        .apb_master_busy(apb_master_busy)
    );

    // =========================================================
    // CLOCK GENERATION
    // =========================================================
    initial s_axi_aclk = 0;
    always #5 s_axi_aclk = ~s_axi_aclk;

    initial m_apb_pclk = 0;
    always #20 m_apb_pclk = ~m_apb_pclk;

    // =========================================================
    // APB BUS SNOOPER
    // =========================================================
    always @(posedge m_apb_pclk) begin
        if (m_apb_presetn && m_apb_penable && m_apb_psel != 0) begin
            if (m_apb_pwrite) begin
                $display("[%0t ns] [APB SNOOP] WRITE Executed | Addr: 0x%h | TRUE Bus Data: 0x%h", 
                         $time, m_apb_paddr, m_apb_pwdata);
            end else begin
                if(!apb_master_busy)
                $display("[%0t ns] [APB SNOOP] READ Executed  | Addr: 0x%h", 
                         $time, m_apb_paddr);
            end

            if (pslverr_slaves != 0) begin
                $display("[%0t ns] >>>> [APB ERROR TRIGGERED] PSLVERR high for Addr: 0x%h!", 
                         $time, m_apb_paddr);
            end
        end
    end

    // =========================================================
    // STIMULUS TASK: AXI WRITE TRANSACTION
    // =========================================================
    task axi_master_write(input [31:0] addr, input [31:0] data);
        begin
            if (apb_master_busy) begin
                $display("[%0t ns] [WAIT] Bridge busy, waiting for IDLE...", $time);
                wait(!apb_master_busy);
            end

            @(posedge s_axi_aclk);
            s_axi_awaddr  = addr;
            s_axi_wdata   = data;
            s_axi_awvalid = 1;
            s_axi_wvalid  = 1;
            s_axi_wstrb   = 4'hf;
            s_axi_bready  = 1;

            wait(s_axi_awready && s_axi_wready);
            @(posedge s_axi_aclk);
            s_axi_awvalid = 0;
            s_axi_wvalid  = 0;
            
            wait(s_axi_bvalid);
            @(posedge s_axi_aclk);
            s_axi_bready = 0;
            $display("[%0t ns] [AXI INPUT] Write Complete. AXI_BRESP: 2'b%b", $time, s_axi_bresp);
        end
    endtask

    // =========================================================
    // STIMULUS TASK: AXI READ TRANSACTION
    // =========================================================
    task axi_master_read(input [31:0] addr);
        begin
            // Protect against simultaneous or overlapping read processing
            if (s_axi_rbusy) begin
                $display("[%0t ns] [WAIT] Read path busy, waiting for IDLE...", $time);
                wait(!s_axi_rbusy);
            end

            @(posedge s_axi_aclk);
            s_axi_araddr  = addr;
            s_axi_arvalid = 1;
            
            wait(s_axi_arready);
            @(posedge s_axi_aclk);
            s_axi_arvalid = 0;

            s_axi_rready = 1; 
            wait(s_axi_rvalid);
            @(posedge s_axi_aclk);
            
            $display("[%0t ns] [AXI INPUT] Read Complete  | Data: 0x%h | AXI_RRESP: 2'b%b", 
                     $time, s_axi_rdata, s_axi_rresp);
            
            s_axi_rready = 0;
            @(posedge s_axi_aclk);
        end
    endtask

    // =========================================================
    // MAIN INITIAL BLOCK
    // =========================================================
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, Top_module_tb);

        // Reset state
        s_axi_awaddr  = 0; s_axi_awvalid = 0;
        s_axi_wdata   = 0; s_axi_wvalid  = 0; s_axi_wstrb = 0;
        s_axi_bready  = 0;
        s_axi_araddr  = 0; s_axi_arvalid = 0; s_axi_rready = 0;

        s_axi_aresetn = 0;
        m_apb_presetn = 0;
        #100;
        
        s_axi_aresetn = 1;
        m_apb_presetn = 1;
        #50;

        $display("\n=== STARTING BRIDGE PIPELINE WRITE TESTS ===");

        $display("\n[TEST 1] Testing WRITE ADDRESS ERROR...");
        axi_master_write(32'h2000_1111, 32'hDEAD_BEEF);
        #500;

        $display("\n[TEST 2] Testing WRITE PERIPHERAL ERROR...");
        axi_master_write(32'h4200_2222, 32'hBAAD_F00D);
        #500;

        $display("\n[TEST 3] Testing PERFECT WRITE...");
        axi_master_write(32'h4500_3333, 32'hCAFE_BABE);
        #500;

        $display("\n=== STARTING BRIDGE PIPELINE READ TESTS ===");

        // // CASE 4: READ ADDRESS ERROR
        // $display("\n[TEST 4] Testing READ ADDRESS ERROR...");
        // axi_master_read(32'h2000_5555); 
        // #500;

        // // CASE 5: READ PERIPHERAL ERROR 
        // $display("\n[TEST 5] Testing READ PERIPHERAL ERROR...");
        // axi_master_read(32'h4200_2222); 
        // #500;

        // CASE 6: PERFECT READ
        $display("\n[TEST 6] Testing PERFECT READ...");
        axi_master_read(32'h4500_CAFE);
        #500;

        repeat(20) @(posedge m_apb_pclk);

        $display("\n=== SIMULATION COMPLETE ===");
        $finish;
    end

endmodule