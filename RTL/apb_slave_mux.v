module apb_slave_mux #(
    parameter c_apb_num_slaves = 16
)(
    // data from master
    input  wire [31:0]                   m_apb_paddr,
    input  wire                          m_apb_psel_global,

    // data from slaves
    input  wire [c_apb_num_slaves-1:0][31:0] prdata_slaves,// all send their data 
    input  wire [c_apb_num_slaves-1:0]       pready_slaves,// signal slave sends for handhshake 
    input  wire [c_apb_num_slaves-1:0]       pslverr_slaves,// if one of them have an error comes here 
    input  wire [c_apb_num_slaves-1:0][31:0] pslverrmsg_slaves,

    // output to slaves 
    output wire [c_apb_num_slaves-1:0]       m_apb_psel, //simple decoder based on value of [31:28] bits 

    // output to master
    output reg                           m_apb_pready,//finally after recieving pready from slaves
    output reg  [31:0]                   m_apb_prdata,//back to master
    output reg                           m_apb_pslverr_mux,
    output reg  [31:0]                   m_apb_pslverrmsg_mux
);

wire [3:0] slave_idx;

assign slave_idx = m_apb_paddr[31:28];
assign m_apb_psel = (m_apb_psel_global)? 1'b1<< slave_idx: {c_apb_num_slaves{1'b0}};

always@(*)begin
    if (m_apb_psel_global) begin
        if(!pslverr_slaves[slave_idx])begin
            m_apb_prdata      = prdata_slaves[slave_idx];
            m_apb_pready      = pready_slaves[slave_idx];
            m_apb_pslverr_mux = pslverr_slaves[slave_idx];
        end else begin
        m_apb_prdata      = 0;
        m_apb_pready      = 0;
        m_apb_pslverr_mux = 1;  
        m_apb_pslverrmsg_mux = pslverrmsg_slaves[slave_idx];
        end
    end else begin
        m_apb_prdata      = 32'b0;
        m_apb_pready      = 1'b0;
        m_apb_pslverr_mux = 1'b0;
        m_apb_pslverrmsg_mux = 32'b0;
    end
end

endmodule