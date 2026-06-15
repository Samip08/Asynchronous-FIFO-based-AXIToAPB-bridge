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

    // =========================================================
    // SMART SLAVE MOCK LOGIC
    // =========================================================
    // Auto-assert pready whenever any slave's psel goes high
    assign pready_slaves = m_apb_psel; 

    // If Master targets Slave 2 (Address 0x20000000), drive a hardware error flag
    assign pslverr_slaves = (m_apb_paddr[31:28] == 4'h2) ? m_apb_psel : {C_APB_NUM_SLAVES{1'b0}};

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
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_rready(s_axi_rready),
        .s_axi_awready(s_axi_awready),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .prdata_slaves(prdata_slaves),
        .pready_slaves(pready_slaves),
        .pslverr_slaves(pslverr_slaves),
        .pslverrmsg_slaves(pslverrmsg_slaves),
        .m_apb_paddr(m_apb_paddr),
        .m_apb_penable(m_apb_penable),
        .m_apb_pwrite(m_apb_pwrite),
        .m_apb_pwdata(m_apb_pwdata),
        .m_apb_pstrb(m_apb_pstrb),
        .m_apb_psel(m_apb_psel),
        .m_apb_pslverrmsg_mux(m_apb_pslverrmsg_mux)
    );

    // =========================================================
    // CLOCK GENERATION
    // =========================================================
    // Fast AXI Clock: 100 MHz (10ns Period)
    initial s_axi_aclk = 0;
    always #5 s_axi_aclk = ~s_axi_aclk;

    // Slower APB Clock: 25 MHz (40ns Period)
    initial m_apb_pclk = 0;
    always #20 m_apb_pclk = ~m_apb_pclk;

    // =========================================================
    // STIMULUS TASK: AXI WRITE TRANSACTION
    // =========================================================
    task axi_master_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge s_axi_aclk);
            s_axi_awaddr  = addr;
            s_axi_wdata   = data;
            s_axi_awvalid = 1;
            s_axi_wvalid  = 1;
            s_axi_wstrb   = 4'hf;
            s_axi_bready  = 1;

            // Wait for FSM handshakes
            wait(s_axi_awready && s_axi_wready);
            @(posedge s_axi_aclk);
            s_axi_awvalid = 0;
            s_axi_wvalid  = 0;

            // Wait for write response
            wait(s_axi_bvalid);
            @(posedge s_axi_aclk);
            s_axi_bready = 0;
            $display("[AXI WRITE DONE] Addr: 0x%h -> Data: 0x%h | Resp: 2'b%b", addr, data, s_axi_bresp);
        end
    endtask

    // =========================================================
    // MAIN INITIAL BLOCK
    // =========================================================
    initial begin
        // Setup waveform tracking
        $dumpfile("pipeline_doom.vcd");
        $dumpvars(0, Top_module_tb);

        // Initial inputs
        s_axi_awaddr  = 0; s_axi_awvalid = 0;
        s_axi_wdata   = 0; s_axi_wvalid  = 0; s_axi_wstrb = 0;
        s_axi_bready  = 0;
        s_axi_araddr  = 0; s_axi_arvalid = 0; s_axi_rready = 0;

        // Assert resets
        s_axi_aresetn = 0;
        m_apb_presetn = 0;
        #100;
        
        // Deassert resets
        s_axi_aresetn = 1;
        m_apb_presetn = 1;
        #50;

        $display("\n=== STARTING BRIDGE PIPELINE FLOW TEST ===");

        // TEST 1: Write to Slave 5 (Clean execution path)
        // Address starts with 0x5... to trigger Slave index 5
        axi_master_write(32'h5000_CAFE, 32'hDEAD_BEEF);
        #200;

        // TEST 2: Write to Slave 2 (Intentionally triggers ERROR path)
        // Address starts with 0x2... to trigger Slave index 2 error logic
        axi_master_write(32'h2000_BABA, 32'hAAAA_5555);
        #200;

        $display("=== SIMULATION COMPLETE ===");
        $finish;
    end

endmodule