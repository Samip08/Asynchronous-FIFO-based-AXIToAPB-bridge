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
    input  wire [31:0]             s_axi_rdata_rom,
    // Read data input channels 
    input  wire                    s_axi_rready,    //from main not rom

    input wire                     mem_valid,//comes from rom

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
    output reg [31:0]              s_axi_rdata,
    output reg  [1:0]              s_axi_rresp,
    output reg                     s_axi_rvalid,
    output reg[4:0]                s_axi_rid,
    output reg                     s_axi_ext_rena,

    // Async fifo write interface
    output reg                     wfifo_wen,
    output reg  [DATA_WIDTH-1:0]   wfifo_wdata
);

parameter SW_IDLE = 2'b00;
parameter SW_WAITING = 2'b01;
parameter SW_WRITING = 2'b11;
parameter SW_RESPONSE = 2'b10;

parameter SR_IDLE = 2'b00;
parameter SR_READING = 2'b01;
parameter SR_RESPONSE  = 2'b11;

reg [1:0] sw_curr_state, sw_next_state;
reg [1:0] sr_curr_state, sr_next_state;
reg [31:0] axi_awaddr_reg, axi_wdata_reg;
reg [31:0] axi_araddr_reg;
reg [3:0] axi_wstrb_reg;
reg sw_axi_awvalid_recieved, sw_axi_wvalid_recieved;
reg sr_axi_arvalid_recieved,sr_axi_rvalid_recieved;
reg mem_valid_recieved;
// reg aw_hs_done, w_hs_done;

// wire sw_awaddr_handshake = (s_axi_awvalid && s_axi_awready) || aw_hs_done;
// wire sw_wdata_handshake = (s_axi_wvalid && s_axi_wready) || w_hs_done;

always@(*)begin
    if(!s_axi_aresetn)begin
        sw_next_state <= SW_IDLE;
    end else begin
        case(sw_curr_state)
            SW_IDLE:begin
                if(sw_axi_awvalid_recieved || sw_axi_wvalid_recieved)begin
                    sw_next_state <= SW_WAITING;
                end else begin
                    sw_next_state <= SW_IDLE;
                end
            end

            SW_WAITING:begin
                if(sw_axi_awvalid_recieved && sw_axi_wvalid_recieved && !wfifo_full)begin
                    sw_next_state <= SW_WRITING;
                end else begin
                    sw_next_state <= SW_WAITING;
                end
            end

            SW_WRITING:begin
                // if(sw_awaddr_handshake && sw_wdata_handshake)begin
                //     sw_next_state <= SW_RESPONSE;
                // end else begin
                sw_next_state <= SW_RESPONSE;
                // end
            end

            SW_RESPONSE:begin
                if(s_axi_bready)begin
                    sw_next_state <= SW_IDLE;
                end else begin
                    sw_next_state <= SW_RESPONSE;
                end
            end 

            default:begin
                sw_next_state <= SW_IDLE;
            end
        endcase
    end
end

always@(*)begin
    if(!s_axi_aresetn)begin
        sr_next_state <= SR_IDLE;
    end else begin
        case(sr_curr_state)
            SR_IDLE:begin
                if(sr_axi_arvalid_recieved)begin
                    sr_next_state <= SR_READING;
                end else begin
                    sr_next_state <= SR_IDLE;
                end
            end

            SR_READING:begin
                if(mem_valid_recieved )begin
                    sr_next_state <= SR_RESPONSE;
                end else begin
                sr_next_state <= SR_READING;
                end
            end

            SR_RESPONSE:begin
                if(s_axi_rready)begin
                    sr_next_state <= SR_IDLE;
                end else begin
                    sr_next_state <= SR_RESPONSE;
                end
            end 

            default:begin
                sr_next_state <= SR_IDLE;
            end
        endcase
    end
end

always@(posedge s_axi_aclk or negedge s_axi_aresetn)begin
    if(!s_axi_aresetn)begin
        s_axi_awready <= 0;
        s_axi_wready <= 0;
        s_axi_bresp <= 0;
        s_axi_bvalid <= 0;
        sw_curr_state <= SW_IDLE;
        wfifo_wen <= 0;
        wfifo_wdata <= 0;
        axi_awaddr_reg <= 0;
        axi_wdata_reg <= 0;
        axi_wstrb_reg <= 0;
        sw_axi_awvalid_recieved <= 0;
        sw_axi_wvalid_recieved <= 0;
    end else begin
        sw_curr_state <= sw_next_state;
        if (sw_curr_state == SW_IDLE || sw_curr_state == SW_WAITING)begin
           if(s_axi_awvalid && !sw_axi_awvalid_recieved)begin
                sw_axi_awvalid_recieved <= 1;
                axi_awaddr_reg <= s_axi_awaddr;
            end 

            if(s_axi_wvalid && !sw_axi_wvalid_recieved)begin
                sw_axi_wvalid_recieved <= 1;
                axi_wdata_reg <= s_axi_wdata;
                axi_wstrb_reg <= s_axi_wstrb;
            end
        end

        case(sw_curr_state)

            SW_IDLE:begin
                s_axi_awready <= 0;
                s_axi_wready <= 0;
                s_axi_bresp <= 0;
                s_axi_bvalid <=0;
                wfifo_wen <= 0;
                wfifo_wdata <= 0;
            end

            SW_WAITING:begin
                s_axi_awready <= 0;
                s_axi_wready <= 0;
                s_axi_bresp <= 0;
                s_axi_bvalid <=0;
                wfifo_wen <= 0;
                wfifo_wdata <= 0;
            end

            SW_WRITING:begin
                // s_axi_awready <= !sw_awaddr_handshake;
                // s_axi_wready <= !sw_wdata_handshake;
                s_axi_awready <= 1'b1;
                s_axi_wready <= 1'b1;
                s_axi_bresp <= 0;
                s_axi_bvalid <=0;

                // if (s_axi_awvalid && s_axi_awready) aw_hs_done <= 1;
                // if (s_axi_wvalid && s_axi_wready) w_hs_done <= 1;
                
                // if (sw_awaddr_handshake && sw_wdata_handshake) begin
                //     wfifo_wen <= 1;
                //     wfifo_wdata <= {1'b1, axi_awaddr_reg, axi_wdata_reg, axi_wstrb_reg};
                // end else begin
                //     wfifo_wen <= 0;
                // end  
                 wfifo_wen <= 1;
                wfifo_wdata <= {1'b1, axi_awaddr_reg, axi_wdata_reg, axi_wstrb_reg};
            end

            SW_RESPONSE:begin
                s_axi_awready <= 0;
                s_axi_wready <= 0;
                s_axi_bresp <= 0;
                s_axi_bvalid <= 1;
                wfifo_wen <= 0;
                wfifo_wdata <= 0;
                sw_axi_awvalid_recieved <= 0;
                sw_axi_wvalid_recieved <= 0;
            end
        endcase
    end
end 

always@(posedge s_axi_aclk or negedge s_axi_aresetn)begin
    if(!s_axi_aresetn)begin
        s_axi_arready <= 0;
        s_axi_rresp <= 0;
        s_axi_rvalid <= 0;
        sr_curr_state <= SR_IDLE;
        axi_araddr_reg <= 0;
        sr_axi_arvalid_recieved <= 0;
        s_axi_rid<=0;
        s_axi_ext_rena<=0;
    end else begin
        sr_curr_state <= sr_next_state;
        if (sr_curr_state == SR_IDLE || sr_curr_state == SR_READING)begin
            if(s_axi_arvalid && !sr_axi_arvalid_recieved)begin
                sr_axi_arvalid_recieved <= 1;
                axi_araddr_reg <= s_axi_araddr;
            end 
        end

        case(sr_curr_state)
            SR_IDLE:begin
                s_axi_arready <= 0;
                s_axi_rresp <= 0;
                s_axi_rvalid <=0;
                s_axi_rid <= 0;
                s_axi_ext_rena <= 0;
            end

            SR_READING:begin
                s_axi_arready <= 1'b1;
                
                //to rom 
                s_axi_rid <= axi_araddr_reg[4:0];
                s_axi_ext_rena <= 1;

                //from rom 
                if(mem_valid)begin
                    s_axi_rdata <= s_axi_rdata_rom;
                    mem_valid_recieved <= 1'b1;
                end
                s_axi_rresp <= 0;
                s_axi_rvalid <=0;
            end

            SR_RESPONSE:begin
                s_axi_arready <= 0;
                s_axi_rresp <= 0;
                s_axi_rvalid <= 1;
                sr_axi_arvalid_recieved <= 0;
                sr_axi_rvalid_recieved <= 0;
                mem_valid_recieved <= 0;
                s_axi_rid<= 0;
                s_axi_ext_rena <= 0;
            end
        endcase
    end
end
endmodule 