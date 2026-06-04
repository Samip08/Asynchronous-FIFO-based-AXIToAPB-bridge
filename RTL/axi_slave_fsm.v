module axi_slave_fsm #(
    parameter DATA_WIDTH = 69
)(
    // Global input signals     
    input  wire                    s_axi_aclk,
    input  wire                    s_axi_aresetn,
    // Write address input channels 
    input  wire [31:0]             s_axi_awaddr,
    input  wire                    s_axi_awvalid,
    // Write data input channels 
    input  wire [31:0]             s_axi_wdata,
    input  wire [3:0]              s_axi_wstrb,
    input  wire                    s_axi_wvalid,
    // Write response input channels
    input  wire                    s_axi_bready,
    // Read address input channels
    input  wire [31:0]             s_axi_araddr,
    input  wire                    s_axi_arvalid,
    // Read data input channels 
    input  wire                    s_axi_rready,
    // Async fifo status signals
    input  wire                    wfifo_full,

    // Write address output channels 
    output reg                     s_axi_awready,
    // Write data output channels 
    output reg                     s_axi_wready,
    // Write response output channels
    output reg  [1:0]              s_axi_bresp,
    output reg                     s_axi_bvalid,
    // Read address output channels 
    output reg                     s_axi_arready,
    // Read data output channels
    output wire [31:0]             s_axi_rdata,
    output reg  [1:0]              s_axi_rresp,
    output reg                     s_axi_rvalid,
    // Async fifo write interface
    output reg                     wfifo_wen,
    output reg  [DATA_WIDTH-1:0]   wfifo_wdata
);

endmodule 