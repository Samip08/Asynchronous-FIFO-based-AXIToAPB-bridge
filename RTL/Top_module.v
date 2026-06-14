module Top_module #(
    parameter C_APB_NUM_SLAVES = 16,
    parameter C_DATA_WIDTH     = 32,
    parameter C_ADDR_WIDTH     = 32,
    parameter ROM_ADDR_WIDTH   = 5,
    parameter FIFO_ADDR_WIDTH  = 4,
    parameter APB_MASTER_ADDR_WIDTH   = 69
)(
    //CLK DOMAINS
    input wire          s_axi_aclk,  //###################
    input wire          s_axi_aresetn,//###############

    input wire          m_apb_pclk, //###########
    input wire          m_apb_presetn, //#################

    //AXI SLAVE INTERFACE INPUTS
    input wire [C_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input wire                      s_axi_awvalid,

    input wire [C_ADDR_WIDTH-1:0]   s_axi_wdata,
    input wire                      s_axi_wvalid,

    input wire                      s_axi_bready,

    input wire [C_ADDR_WIDTH-1:0]   s_axi_araddr,
    input wire                      s_axi_arvalid,

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

    output wire [C_APB_NUM_SLAVES-1:0]       m_apb_psel
);

axi_slave_fsm axi_slave_fsm_block(   
    .axi_aclk(s_axi_aclk),
    .s_axi_aresetn(s_axi_aresetn),

    // Write address input channels 
    .s_axi_awaddr(),
    .s_axi_awvalid(),

    // Write data input channels 
    .s_axi_wdata(),
    .s_axi_wstrb(),
    .s_axi_wvalid(),

    // Write response input channels
    .s_axi_bready(),

    // Read address input channels
    .s_axi_araddr(),
    .s_axi_arvalid(),
    .s_axi_rdata_rom(),
    // Read data input channels 
    .s_axi_rready(),    //from main not rom

    .mem_valid(),//comes from rom
    // Async fifo status signals
    .wfifo_full(),


    // Write address output channels 
    .s_axi_awready(),
    // Write data output channels 
    .s_axi_wready(),
    // Write response output channels
    .s_axi_bresp(),
    .s_axi_bvalid(),

    // Read address output channels 
    .s_axi_arready(),
    // Read data output channels
    .s_axi_rdata(),
    .s_axi_rresp(),
    .s_axi_rvalid(),
    .s_axi_rid(),
    .s_axi_ext_rena(),

    // Async fifo write interface
    .wfifo_wen(),
    .wfifo_wdata()
);


rom_memory rom_memory_block(
    .addr(),//rom_addr width 
    .read_en(),

    .data(),
    .valid()
);

async_fifo_core async_fifo_core_block (
    // Write Domain Inputs (AXI Clock Domain)
    .wclk(s_axi_aclk),
    .wrst_n(s_axi_aresetn),
    .winc(),
    .wdata(),
    // Read Domain Inputs (APB Clock Domain)
    .rclk(m_apb_pclk),
    .rrst_n(m_apb_presetn),
    .rinc(),

    // Write Domain Inputs (AXI Clock Domain)
    .wfull(),
    // Read Domain Inputs (APB Clock Domain)
    .rdata(),//async addr width here
    .rempty()
);

apb_master_fsm apb_master_fsm_block (
    .m_apb_pclk(m_apb_pclk), 
    .m_apb_presetn(m_apb_presetn), 

    // Inputs (from FIFO)
    .rfifo_empty(),  
    .rfifo_rdata(),  //apb_master addr width

    // Inputs (from Peripherals)
    .m_apb_pready(),
    .m_apb_prdata(), 
    .m_apb_pslverr_mux(),
    .m_apb_rvalid(),

    // Outputs (to FIFO)
    .rfifo_ren(),     
    
    // Outputs (to Peripherals)
    .m_apb_busy(),
    .m_apb_paddr(),    
    .m_apb_pwrite(),   
    .m_apb_pwdata(),   
    .m_apb_pstrb(),    
    .m_apb_penable(),
    .m_apb_rvalid_recieved(),
    .m_apb_psel_global()
);

apb_slave_mux apb_slave_mux_block(
    .m_apb_paddr(),
    .m_apb_psel_global(),

    // data from slaves
    .prdata_slaves(),// all send their data [c_apb_num_slaves-1:0][31:0]
    .pready_slaves(),// signal slave sends for handhshake [c_apb_num_slaves-1:0] 
    .pslverr_slaves(),// if one of them have an error comes here [c_apb_num_slaves-1:0] 
    .pslverrmsg_slaves(),//[c_apb_num_slaves-1:0][31:0]

    // output to slaves 
    .m_apb_psel(), //simple decoder based on value of [31:28] bits 

    // output to master
    .m_apb_pready(),//finally after recieving pready from slaves
    .m_apb_prdata(),//back to master
    .m_apb_pslverr_mux(),
    .m_apb_pslverrmsg_mux()
);
endmodule
