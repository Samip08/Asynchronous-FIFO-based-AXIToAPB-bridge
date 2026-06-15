module async_fifo_core #(
    // 32 bit address , 32 bit write data , 4 bit strobe width , 1 bit read/write
    parameter DATA_WIDTH = 69,
    // for r_ptr and w_ptr size
    parameter ADDR_WIDTH = 4
)(
    // Write Domain Inputs (AXI Clock Domain)
    input  wire                    wclk,
    input  wire                    wrst_n,
    input  wire                    winc,
    input  wire [DATA_WIDTH-1:0]   wdata,
    // Read Domain Inputs (APB Clock Domain)
    input  wire                    rclk,
    input  wire                    rrst_n,
    input  wire                    rinc,

    // Write Domain Outputs (AXI Clock Domain)
    output reg                     wfull,
    // Read Domain Outputs (APB Clock Domain)
    output wire [DATA_WIDTH-1:0]   rdata,
    output reg                     rempty

);

wire [ADDR_WIDTH:0] wptr_gray, rptr_gray;

wire [ADDR_WIDTH:0] rptr_next = rptr + (rinc && !rempty);
wire [ADDR_WIDTH:0] wptr_next = wptr + (winc && !wfull);

wire [ADDR_WIDTH:0] rptr_gray_next = rptr_next ^ (rptr_next >> 1);
wire [ADDR_WIDTH:0] wptr_gray_next = wptr_next ^ (wptr_next >> 1);


// MSB of ptr is used to determine wrap around condition
// FIFO stores address alongside the actual data 
reg [ADDR_WIDTH:0] wptr, rptr;
reg [ADDR_WIDTH:0] rptr_gray_sync1, rptr_gray_sync2,wptr_gray_sync1, wptr_gray_sync2;
reg [DATA_WIDTH-1:0] async_fifo [2**ADDR_WIDTH-1:0];

assign wptr_gray = wptr^(wptr>> 1);
assign rptr_gray = rptr^(rptr>> 1);
assign rdata = async_fifo[rptr[ADDR_WIDTH-1:0]];

always@(posedge wclk or negedge wrst_n)begin
    if (wrst_n == 0) begin
        wfull <= 0;
        wptr <= 0;
    end else begin
    if(wfull!=1 && winc ==1)begin
        async_fifo[wptr[ADDR_WIDTH-1:0]] <= wdata;
        wptr <= wptr + 1;
    end
    // ensures that write pointer can write till only locations above read pointer even after wrap around
    wfull <= (wptr_gray_next == {~rptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1], rptr_gray_sync2[ADDR_WIDTH-2:0]});
    end
end

always@(posedge rclk or negedge rrst_n)begin
    if (rrst_n == 0) begin
        rempty <= 1;
        rptr <= 0;
    end else if (rempty!=1 && rinc ==1)begin
        rptr <= rptr + 1;
    end
    rempty <= (rptr_gray_next == wptr_gray_sync2);
end

// Synchronization of read pointer to domain of write pointer clk
always@(posedge wclk or negedge wrst_n)begin
    if (wrst_n==0) begin
    rptr_gray_sync1 <=0;
    rptr_gray_sync2 <=0;
    end else begin 
    rptr_gray_sync1 <= rptr_gray;
    rptr_gray_sync2 <= rptr_gray_sync1;
    end
end

// Synchronization of write pointer to domain of read pointer clk
always@(posedge rclk or negedge rrst_n)begin
    if (rrst_n==0) begin
    wptr_gray_sync1 <=0;
    wptr_gray_sync2 <=0;
    end else begin 
    wptr_gray_sync1 <= wptr_gray;
    wptr_gray_sync2 <= wptr_gray_sync1;
    end
end

endmodule