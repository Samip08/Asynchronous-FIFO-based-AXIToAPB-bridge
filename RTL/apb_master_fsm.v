module apb_master_fsm #(
    parameter DATA_WIDTH = 69
)(
    // --- Global Signals ---
    input  wire                  m_apb_pclk, 
    input  wire                  m_apb_presetn, 

    // Inputs (from FIFO)
    input  wire                  rfifo_empty,  
    input  wire [DATA_WIDTH-1:0] rfifo_rdata,  

    // Inputs (from Peripherals)
    input  wire                  m_apb_pready,
    input  wire [31:0]           m_apb_prdata, 
    input  wire                  m_apb_pslverr_mux,
    input  wire                  m_apb_rvalid,

    // Outputs (to FIFO)
    output reg                   rfifo_ren,     
    
    // Outputs (to Peripherals)
    output wire                 m_apb_busy,
    output reg [31:0]            m_apb_paddr,    
    output reg                   m_apb_pwrite,   
    output reg [31:0]            m_apb_pwdata,   
    output reg [3:0]             m_apb_pstrb,    
    output reg                   m_apb_penable,
    output reg                   m_apb_rvalid_recieved,
    output reg                   m_apb_psel_global
);

parameter M_IDLE = 3'b000;
parameter M_WAITING = 3'b001;
parameter M_READING = 3'b011;
parameter M_WRITING = 3'b010;
parameter M_RESPONSE = 3'b110; //basically error state

reg [2:0] m_curr_state, m_next_state;
reg waiting_delay_cntr;
reg [1:0] psel_delay_cntr;
reg [31:0] fifo_request_rdata;
reg m_apb_pwrite_reg;
reg [31:0] m_apb_paddr_reg, m_apb_pwdata_reg;
reg [3:0] m_apb_pstrb_reg;

assign m_apb_busy = (m_curr_state != M_IDLE);

always@(*)begin
    if(!m_apb_presetn)begin
        m_next_state <= M_IDLE;
    end
    if (m_apb_pslverr_mux&& m_curr_state!=M_IDLE)begin
        m_next_state <= M_RESPONSE;
    end else if(m_apb_presetn && !m_apb_pslverr_mux)begin
        case(m_curr_state)
        M_IDLE:begin
            if(!rfifo_empty && !m_apb_busy)begin
                m_next_state <= M_WAITING;
            end else begin 
                m_next_state <= M_IDLE;
            end
        end

        M_WAITING:begin
            if(waiting_delay_cntr<1) begin
                waiting_delay_cntr <= waiting_delay_cntr +1;
                m_next_state <= M_WAITING;
            end else begin
                if(rfifo_rdata[68])begin
                    m_next_state <= M_WRITING;
                end else begin
                    m_next_state <= M_READING;
                end
            end
        end

        M_READING:begin
            if(m_apb_pready)begin
                m_next_state <= M_IDLE;
            end else begin
                m_next_state <= M_READING;
            end
        end

        M_WRITING:begin
            if(psel_delay_cntr < 2) begin
                m_next_state <= M_WRITING;
            end else if(m_apb_pready) begin
                m_next_state <= M_IDLE;
            end else begin
                m_next_state <= M_WRITING;
            end
        end

        M_RESPONSE:begin
            m_next_state <= M_IDLE;
        end
        endcase
    end
end

always@(posedge m_apb_pclk or negedge m_apb_presetn)begin
    if(!m_apb_presetn)begin
        rfifo_ren <= 0;
        m_apb_paddr <= 0;
        m_apb_pwrite <= 0;
        m_apb_pwdata <= 0;
        m_apb_pstrb <= 0;
        m_apb_paddr_reg <= 0;
        m_apb_pwrite_reg <= 0;
        m_apb_pwdata_reg <= 0;
        m_apb_pstrb_reg <= 0;
        m_apb_penable <= 0;
        m_apb_psel_global <= 0;
        waiting_delay_cntr <= 0;
        psel_delay_cntr <= 0;
        m_apb_rvalid_recieved <= 0;
    
    end else begin
        m_curr_state <= m_next_state;
        case(m_curr_state)

        M_IDLE:begin
            if(!rfifo_empty && !m_apb_busy)begin
                rfifo_ren <= 1;
            end
            m_apb_paddr <= 0;
            m_apb_pwrite <= 0;
            m_apb_pwdata <= 0;
            m_apb_pstrb <= 0;
            m_apb_penable <= 0;
            m_apb_psel_global <= 0;
            waiting_delay_cntr <= 0;
            psel_delay_cntr <= 0;
            m_apb_rvalid_recieved <= 0;
        end

        M_WAITING:begin
            rfifo_ren <= 0;
            if(waiting_delay_cntr)begin
                m_apb_pwrite_reg <= rfifo_rdata[68];
                m_apb_paddr_reg <= rfifo_rdata[67:36];
                m_apb_pwdata_reg <= rfifo_rdata[35:4];
                m_apb_pstrb_reg <= rfifo_rdata[3:0];
            end 
        end

        M_READING:begin
            //storing data in local register current, can be sent to response fifo via simple handshake no need for hardcoded delays
            if(m_apb_rvalid)begin
                fifo_request_rdata <= m_apb_prdata;
                m_apb_rvalid_recieved <= 1;

            end else begin
                m_apb_psel_global <= 1;
                m_apb_penable <= 1;
            end
        end

        M_WRITING:begin
            if(psel_delay_cntr < 2) begin
                psel_delay_cntr <= psel_delay_cntr + 1;
            end
            if(psel_delay_cntr == 1) begin
                m_apb_psel_global <= 1;
                m_apb_pwrite <= m_apb_pwrite_reg;
                m_apb_paddr  <= m_apb_paddr_reg;
                m_apb_pwdata <= m_apb_pwdata_reg;
                m_apb_pstrb  <= m_apb_pstrb_reg;
            end
            if(psel_delay_cntr == 2) begin
                m_apb_penable <= 1;
            end
        end

        M_RESPONSE:begin
            m_apb_psel_global <= 1'b0;
            m_apb_penable     <= 1'b0;
            m_apb_rvalid_recieved <= 1'b0;
            $display("--- APB ERROR DETECTED ---");
            $display("Failed Address: 0x%h", m_apb_paddr_reg);
            $display("Command Type: %s", (m_apb_pwrite_reg ? "WRITE" : "READ"));
        end
        endcase
    end
end
endmodule