`timescale 1ns / 1ps

module tb_apb_slave_mux();

    localparam NUM_SLAVES = 16;

    reg         clk;
    reg  [31:0] m_apb_paddr;
    reg         m_apb_psel_global;

    // Flattened inputs for the testbench
    reg  [(NUM_SLAVES*32)-1:0] prdata_slaves;
    reg  [NUM_SLAVES-1:0]      pready_slaves;
    reg  [NUM_SLAVES-1:0]      pslverr_slaves;
    reg  [(NUM_SLAVES*32)-1:0] pslverrmsg_slaves;

    wire [NUM_SLAVES-1:0]      m_apb_psel;
    wire                       m_apb_pready;
    wire [31:0]                m_apb_prdata;
    wire                       m_apb_pslverr_mux;
    wire [31:0]                m_apb_pslverrmsg_mux;

    apb_slave_mux #(
        .c_apb_num_slaves(NUM_SLAVES)
    ) dut (
        .m_apb_paddr         (m_apb_paddr),
        .m_apb_psel_global   (m_apb_psel_global),
        .prdata_slaves       (prdata_slaves),
        .pready_slaves       (pready_slaves),
        .pslverr_slaves      (pslverr_slaves),
        .pslverrmsg_slaves   (pslverrmsg_slaves),
        .m_apb_psel          (m_apb_psel),
        .m_apb_pready        (m_apb_pready),
        .m_apb_prdata        (m_apb_prdata),
        .m_apb_pslverr_mux   (m_apb_pslverr_mux),
        .m_apb_pslverrmsg_mux(m_apb_pslverrmsg_mux)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        m_apb_paddr = 0;
        m_apb_psel_global = 0;
        
        // Verilog-2001 safe initialization
        prdata_slaves = 0;
        pready_slaves = 0;
        pslverr_slaves = 0;
        pslverrmsg_slaves = 0;

        // Pre-load our slaves using flat-bus bit slicing
        // Slave 0 = bits [31:0]
        prdata_slaves[31:0] = 32'hC001_D00D; 
        
        // Slave 5 = bits [191:160] (Because 5 * 32 = 160)
        prdata_slaves[191:160] = 32'h1111_2222; 
        
        // Setup the Error condition on Slave 2 (2 * 32 = 64)
        prdata_slaves[95:64]     = 32'h0000_0000; 
        pslverr_slaves[2]        = 1'b1;          
        pslverrmsg_slaves[95:64] = 32'hBAD_C0DE;  

        $display("==================================================");
        $display(" Starting APB MUX Simulation (Verilog-2001)...");
        $display("==================================================");

        // TEST 1: Normal Read from Slave 0
        @(posedge clk);
        m_apb_paddr = 32'h0000_1000;
        m_apb_psel_global = 1'b1;
        
        @(posedge clk);
        pready_slaves[0] = 1'b1;
        
        #1; 
        $display("\n[TEST 1] Master reading from Slave 0");
        $display("  -> PSEL Vector:  %b", m_apb_psel);
        $display("  -> MUX PRDATA:   0x%h", m_apb_prdata);
        
        pready_slaves[0] = 1'b0;
        m_apb_psel_global = 1'b0;

        // TEST 2: Normal Read from Slave 5
        @(posedge clk);
        m_apb_paddr = 32'h50A0_0000;
        m_apb_psel_global = 1'b1;
        
        @(posedge clk);
        pready_slaves[5] = 1'b1;
        
        #1;
        $display("\n[TEST 2] Master reading from Slave 5");
        $display("  -> PSEL Vector:  %b", m_apb_psel);
        $display("  -> MUX PRDATA:   0x%h", m_apb_prdata);

        pready_slaves[5] = 1'b0;
        m_apb_psel_global = 1'b0;

        // TEST 3: Error Read from Slave 2
        @(posedge clk);
        m_apb_paddr = 32'h2FFF_FFFF;
        m_apb_psel_global = 1'b1;
        
        @(posedge clk);
        pready_slaves[2] = 1'b1; 
        
        #1;
        $display("\n[TEST 3] Master reading from Slave 2 (EXPECTING ERROR)");
        $display("  -> PSEL Vector:  %b", m_apb_psel);
        $display("  -> MUX PSLVERR:  %b !!! ERROR DETECTED !!!", m_apb_pslverr_mux);
        $display("  -> ERR MESSAGE:  0x%h", m_apb_pslverrmsg_mux);

        pready_slaves[2] = 1'b0;
        m_apb_psel_global = 1'b0;

        $display("\n==================================================");
        $display(" Simulation Complete.");
        $display("==================================================");
        $finish;
    end

endmodule