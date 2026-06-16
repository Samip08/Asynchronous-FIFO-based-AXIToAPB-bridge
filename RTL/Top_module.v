module Top_module #(
    parameter C_APB_NUM_SLAVES = 16,
    parameter C_DATA_WIDTH     = 32,
    parameter C_ADDR_WIDTH     = 32,
    parameter ROM_ADDR_WIDTH   = 5,
    parameter FIFO_ADDR_WIDTH  = 4,
    parameter APB_MASTER_DATA_WIDTH   = 69,
    parameter STRB_WIDTH       = 4        
)(
    //CLK DOMAINS
    input wire          s_axi_aclk,  
    input wire          s_axi_aresetn,

    input wire          m_apb_pclk, 
    input wire          m_apb_presetn, 

    //AXI SLAVE INTERFACE INPUTS
    input wire [C_ADDR_WIDTH-1:0]   s_axi_awaddr,   
    input wire                      s_axi_awvalid,  

    input wire [C_ADDR_WIDTH-1:0]   s_axi_wdata,   
    input wire                      s_axi_wvalid,  
    input wire [STRB_WIDTH-1:0]     s_axi_wstrb,   
 
    input wire                      s_axi_bready,   

    input wire [C_ADDR_WIDTH-1:0]   s_axi_araddr,   
    input wire                      s_axi_arvalid,  

    input wire                      s_axi_rready, 

    //AXI SLAVE INTERFACE OUTPUTS
    output wire                     s_axi_awready,  
    output wire                     s_axi_wready,   

    output wire[1:0]                s_axi_bresp,   
    output wire                     s_axi_bvalid,   

    output wire                     s_axi_arready,  

    output wire [C_ADDR_WIDTH-1:0]  s_axi_rdata, 
    output wire [1:0]               s_axi_rresp,
    output wire                     s_axi_rvalid, 


    //APB MASTER INTERFACE INPUTS
    input wire[(C_APB_NUM_SLAVES*32)-1:0]  prdata_slaves,   
    input wire[C_APB_NUM_SLAVES -1:0]      pready_slaves,  

    input wire[C_APB_NUM_SLAVES -1:0]      pslverr_slaves, 
    input wire[(C_APB_NUM_SLAVES*32)-1:0]  pslverrmsg_slaves,  
    //APB MASTER INTERFACE OUTPUTS
    output wire [C_ADDR_WIDTH-1:0]           m_apb_paddr,  
    output wire                              m_apb_penable, 
    output wire                              m_apb_pwrite, 
    output wire [C_DATA_WIDTH-1:0]           m_apb_pwdata, 
    output wire [STRB_WIDTH-1:0]             m_apb_pstrb, 
    output wire                              apb_master_busy,

    output wire [C_APB_NUM_SLAVES-1:0]       m_apb_psel, 
    output wire [C_DATA_WIDTH-1:0]           m_apb_pslverrmsg_mux,

    //STATES
    output wire [1:0]                        sw_axi_slave_state,
    output wire [1:0]                        sr_axi_slave_state,
    output wire [2:0]                        m_apb_master_state

);

wire[C_DATA_WIDTH-1:0] rom_data, m_apb_prdata;
wire[APB_MASTER_DATA_WIDTH-1:0] wfifo_data, rfifo_data;
wire wfifo_full, rom_valid, s_axi_ext_rena_rom, wfifo_ena, rfifo_empty, rfifo_ena,m_apb_pready, m_apb_pslverr_mux, m_apb_psel_global;
wire [ROM_ADDR_WIDTH-1:0] rom_addr;

wire apb_rvalid_high = 1'b1; // always allowed to read
wire apb_rvalid_received_status;


axi_slave_fsm axi_slave_fsm_block(   
    .s_axi_aclk(s_axi_aclk),
    .s_axi_aresetn(s_axi_aresetn),

    // Write address input channels 
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),

    // Write data input channels 
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),

    // Write response input channels
    .s_axi_bready(s_axi_bready),

    // Read address input channels
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_rdata_rom(rom_data),
    // Read data input channels 
    .s_axi_rready(s_axi_rready),    //from main not rom 

    .mem_valid(rom_valid),//comes from rom
    // Async fifo status signals
    .wfifo_full(wfifo_full),


    // Write address output channels 
    .s_axi_awready(s_axi_awready),
    // Write data output channels 
    .s_axi_wready(s_axi_wready),
    // Write response output channels
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),

    // Read address output channels 
    .s_axi_arready(s_axi_arready),
    // Read data output channels
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rid(rom_addr),
    .s_axi_ext_rena(s_axi_ext_rena_rom),

    // Async fifo write interface
    .wfifo_wen(wfifo_ena),
    .wfifo_wdata(wfifo_data),
    .sw_axi_slave_state(sw_axi_slave_state),
    .sr_axi_slave_state(sr_axi_slave_state)

);


rom_memory rom_memory_block(
    .addr(rom_addr),//rom_addr width 
    .read_en(s_axi_ext_rena_rom),

    .data(rom_data),
    .valid(rom_valid)
);

async_fifo_core async_fifo_core_block (
    // Write Domain Inputs (AXI Clock Domain)
    .wclk(s_axi_aclk),
    .wrst_n(s_axi_aresetn),
    .winc(wfifo_ena),
    .wdata(wfifo_data),
    // Read Domain Inputs (APB Clock Domain)
    .rclk(m_apb_pclk),
    .rrst_n(m_apb_presetn),
    .rinc(rfifo_ena),          

    // Write Domain Outputs (AXI Clock Domain)
    .wfull(wfifo_full),
    // Read Domain Outputs (APB Clock Domain)
    .rdata(rfifo_data),//async addr width here
    .rempty(rfifo_empty)
);

apb_master_fsm apb_master_fsm_block (
    .m_apb_pclk(m_apb_pclk), 
    .m_apb_presetn(m_apb_presetn), 

    // Inputs (from FIFO)
    .rfifo_empty(rfifo_empty),  
    .rfifo_rdata(rfifo_data),  //apb_master addr width

    // Inputs (from Peripherals)
    .m_apb_pready(m_apb_pready),
    .m_apb_prdata(m_apb_prdata), 
    .m_apb_pslverr_mux(m_apb_pslverr_mux),
    .m_apb_rvalid(apb_rvalid_high),

    // Outputs (to FIFO)
    .rfifo_ren(rfifo_ena),     
    
    // Outputs (to Peripherals)
    .m_apb_busy(apb_master_busy), // output
    .m_apb_paddr(m_apb_paddr),    
    .m_apb_pwrite(m_apb_pwrite),   
    .m_apb_pwdata(m_apb_pwdata),   
    .m_apb_pstrb(m_apb_pstrb),    
    .m_apb_penable(m_apb_penable),
    .m_apb_rvalid_recieved(apb_rvalid_received_status),  //doesnt output
    .m_apb_psel_global(m_apb_psel_global),
    .m_apb_pslverrmsg(m_apb_pslverrmsg_mux),
    .m_apb_master_state(m_apb_master_state)
);

apb_slave_mux apb_slave_mux_block(
    .m_apb_paddr(m_apb_paddr),
    .m_apb_psel_global(m_apb_psel_global),

    // data from slaves
    .prdata_slaves(prdata_slaves),// all send their data [c_apb_num_slaves-1:0][31:0]
    .pready_slaves(pready_slaves),// signal slave sends for handhshake [c_apb_num_slaves-1:0] 
    .pslverr_slaves(pslverr_slaves),// if one of them have an error comes here [c_apb_num_slaves-1:0] 
    .pslverrmsg_slaves(pslverrmsg_slaves),//[c_apb_num_slaves-1:0][31:0]

    // output to slaves 
    .m_apb_psel(m_apb_psel), //simple decoder based on value of [31:28] bits 

    // output to master
    .m_apb_pready(m_apb_pready),//finally after recieving pready from slaves
    .m_apb_prdata(m_apb_prdata),//back to master
    .m_apb_pslverr_mux(m_apb_pslverr_mux),
    .m_apb_pslverrmsg_mux(m_apb_pslverrmsg_mux)
);
endmodule
