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
    input wire [DATA_WIDTH-1:0]    s_axi_response,   //
    // Read data input channels 
    input  wire                    s_axi_rready,    //from main not rom


    // Async fifo status signals
    input  wire                    wfifo_full,
    input  wire                    rfifo_empty,  //

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

    // Async fifo write interface
    output wire                    wfifo_wen,
    output reg                     rfifo_ren,  //
    output wire [DATA_WIDTH-1:0]   wfifo_wdata,
    output reg  [1:0]              sr_axi_slave_state,
    output reg  [1:0]              sw_axi_slave_state,

    output reg [31:0]            s_axi_rdata_return, //
    output reg                   s_axi_rbusy //
);

parameter SW_IDLE = 2'b00;
parameter SW_WAITING = 2'b01;
parameter SW_WRITING = 2'b11;
parameter SW_RESPONSE = 2'b10;

parameter SR_IDLE = 2'b00;
parameter SR_READING = 2'b01;
parameter SR_WAITING_RESPONSE = 2'b10;
parameter SR_RESPONSE  = 2'b11;

reg [1:0] sw_curr_state, sw_next_state;
reg [1:0] sr_curr_state, sr_next_state;
reg [31:0] axi_awaddr_reg, axi_wdata_reg;
reg [31:0] axi_araddr_reg;
reg [3:0] axi_wstrb_reg;
reg sw_axi_awvalid_recieved, sw_axi_wvalid_recieved;
reg sr_axi_arvalid_recieved,sr_axi_rvalid_recieved;

reg sw_wfifo_wen, sr_wfifo_wen;
reg [DATA_WIDTH-1:0] sw_wfifo_wdata, sr_wfifo_wdata;

assign wfifo_wen   = sw_wfifo_wen | sr_wfifo_wen;
assign wfifo_wdata = sw_wfifo_wen ? sw_wfifo_wdata : sr_wfifo_wdata;

reg w_addr_error;

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
                    sw_next_state = SW_WAITING;
                end else begin
                    sw_next_state = SW_IDLE;
                end
            end

            SW_WAITING:begin
                if(sw_axi_awvalid_recieved && sw_axi_wvalid_recieved && !wfifo_full)begin
                    sw_next_state = SW_WRITING;
                end else begin
                    sw_next_state = SW_WAITING;
                end
            end

            SW_WRITING:begin
                // if(sw_awaddr_handshake && sw_wdata_handshake)begin
                //     sw_next_state <= SW_RESPONSE;
                // end else begin
                sw_next_state = SW_RESPONSE;
                // end
            end

            SW_RESPONSE:begin
                if(s_axi_bready|| w_addr_error)begin
                    sw_next_state = SW_IDLE;
                end else begin
                    sw_next_state = SW_RESPONSE;
                end
            end 

            default:begin
                sw_next_state = SW_IDLE;
            end
        endcase
    end
end

always@(*)begin
    if(!s_axi_aresetn)begin
        sr_next_state = SR_IDLE;
    end else begin
        case(sr_curr_state)
            SR_IDLE:begin
                if(sr_axi_arvalid_recieved&& (!s_axi_rbusy))begin
                    sr_next_state = SR_READING;
                end else begin
                    sr_next_state = SR_IDLE;
                end
            end

            SR_READING:begin
                if(!wfifo_full)begin
                    sr_next_state = SR_WAITING_RESPONSE;
                end else begin
                sr_next_state = SR_READING;
                end
            end

            SR_WAITING_RESPONSE:begin
                if(!rfifo_empty)begin
                    sr_next_state = SR_RESPONSE;
                end else begin
                    sr_next_state = SR_WAITING_RESPONSE;
                end
            end

            SR_RESPONSE:begin
                if(s_axi_rready)begin
                    sr_next_state = SR_IDLE;
                end else begin
                    sr_next_state = SR_RESPONSE;
                end
            end 

            default:begin
                sr_next_state = SR_IDLE;
            end
        endcase
    end
end

always@(posedge s_axi_aclk or negedge s_axi_aresetn)begin
    sw_axi_slave_state <= sw_next_state;
    if(!s_axi_aresetn)begin
        s_axi_awready <= 0;
        s_axi_wready <= 0;
        s_axi_bresp <= 0;
        s_axi_bvalid <= 0;
        sw_curr_state <= SW_IDLE;
        sw_wfifo_wen <= 0;
        sw_wfifo_wdata <= 0;
        axi_awaddr_reg <= 0;
        axi_wdata_reg <= 0;
        axi_wstrb_reg <= 0;
        sw_axi_awvalid_recieved <= 0;
        sw_axi_wvalid_recieved <= 0;
        w_addr_error <= 0;
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
                sw_wfifo_wen <= 0;
                sw_wfifo_wdata <= 0;
                w_addr_error <= 0;
            end

            SW_WAITING:begin
                s_axi_awready <= 0;
                s_axi_wready <= 0;
                s_axi_bresp <= 0;
                s_axi_bvalid <=0;
                sw_wfifo_wen <= 0;
                sw_wfifo_wdata <= 0;
            end

            SW_WRITING:begin
                // s_axi_awready <= !sw_awaddr_handshake;
                // s_axi_wready <= !sw_wdata_handshake;
                s_axi_awready <= 1'b1;
                s_axi_wready <= 1'b1;
                s_axi_bvalid <=0;

                if( axi_awaddr_reg[31:28] == 4'h2)begin
                    s_axi_bresp <= 2'b10;
                    sw_wfifo_wen <= 0;    //aint putting the value lil bro 
                    w_addr_error <=1;
                    sw_wfifo_wdata <= 0;
                    $display("AXI ERROR: Invalid Write Address %h! Rejecting  Transmission locally.", axi_awaddr_reg);
                end else begin
                    s_axi_bresp <= 2'b00;
                    sw_wfifo_wen <= 1;
                    sw_wfifo_wdata <= {1'b1, axi_awaddr_reg, axi_wdata_reg, axi_wstrb_reg};

                end
                
                // if (s_axi_awvalid && s_axi_awready) aw_hs_done <= 1;
                // if (s_axi_wvalid && s_axi_wready) w_hs_done <= 1;
                
                // if (sw_awaddr_handshake && sw_wdata_handshake) begin
                //     wfifo_wen <= 1;
                //     wfifo_wdata <= {1'b1, axi_awaddr_reg, axi_wdata_reg, axi_wstrb_reg};
                // end else begin
                //     wfifo_wen <= 0;
                // end 
            end 
                

            SW_RESPONSE:begin
                s_axi_awready <= 0;
                s_axi_wready <= 0;
                s_axi_bresp <= 0;
                s_axi_bvalid <= 1;
                sw_wfifo_wen <= 0;
                sw_wfifo_wdata <= 0;
                sw_axi_awvalid_recieved <= 0;
                sw_axi_wvalid_recieved <= 0;

                if(axi_awaddr_reg[31:28] == 4'h2)begin
                    s_axi_bresp <= 2'b10;
                end else begin
                    s_axi_bresp <= 2'b00;
                end
            end
        endcase
    end
end 

always@(posedge s_axi_aclk or negedge s_axi_aresetn)begin
    sr_axi_slave_state <= sr_next_state;
    if(!s_axi_aresetn)begin
        s_axi_arready <= 0;
        s_axi_rresp <= 0;
        s_axi_rvalid <= 0;
        sr_curr_state <= SR_IDLE;
        axi_araddr_reg <= 0;
        sr_axi_arvalid_recieved <= 0;
        rfifo_ren <= 0;
        s_axi_rdata_return<=0;
        s_axi_rdata_return <= 0;
        s_axi_rbusy<=0;
        sr_wfifo_wen <=0;
        sr_wfifo_wdata<= 0;
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
                rfifo_ren <=0;
                s_axi_rdata_return <=0;
                sr_wfifo_wen<=0;
                if(sr_next_state != SR_READING)begin
                    s_axi_rbusy <= 0;
                end else begin
                    s_axi_rbusy <=1;
                end
            end

            SR_READING:begin
                if(!wfifo_full)begin
                    s_axi_arready <= 1'b1;
                    sr_wfifo_wdata <= {1'b0, axi_araddr_reg, 32'h0, 4'h0};
                    sr_wfifo_wen <= 1'b1;
                    s_axi_rresp <= 0;
                    s_axi_rvalid <=0;
                end else begin
                    s_axi_arready <= 1'b0;
                    sr_wfifo_wdata <= {1'b0, 32'h0, 32'h0, 4'h0};
                    sr_wfifo_wen <= 1'b0;
                end
            end

            SR_WAITING_RESPONSE:begin
                sr_wfifo_wen <= 1'b0;
                if(!rfifo_empty)begin
                    rfifo_ren<= 1'b1;
                end else begin
                    rfifo_ren <=1'b0;
                end
                
            end

            SR_RESPONSE:begin
                s_axi_rdata_return <= s_axi_response[35:4];
                s_axi_rdata <= s_axi_response[35:4];
                rfifo_ren<=1'b0;
                s_axi_arready <= 0;
                s_axi_rresp <= 0;
                s_axi_rvalid <= 1;
                sr_axi_arvalid_recieved <= 0;
                sr_axi_rvalid_recieved <= 0;
                sr_wfifo_wen<=0;
                s_axi_rbusy<=0;
                sr_wfifo_wen <=0;
            end
        endcase
    end
end
endmodule 