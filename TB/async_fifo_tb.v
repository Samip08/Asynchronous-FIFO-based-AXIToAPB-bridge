`timescale 1ns/1ps

module async_fifo_tb;

    parameter DATA_WIDTH = 69;
    parameter ADDR_WIDTH = 4;

    reg                    wclk;
    reg                    wrst_n;
    reg                    winc;
    reg [DATA_WIDTH-1:0]   wdata;

    reg                    rclk;
    reg                    rrst_n;
    reg                    rinc;

    wire                   wfull;
    wire [DATA_WIDTH-1:0]  rdata;
    wire                   rempty;

    async_fifo_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .wclk(wclk),
        .wrst_n(wrst_n),
        .winc(winc),
        .wdata(wdata),
        .rclk(rclk),
        .rrst_n(rrst_n),
        .rinc(rinc),
        .wfull(wfull),
        .rdata(rdata),
        .rempty(rempty)
    );

    always #5  wclk = ~wclk;  // 100MHz Write Clock
    always #12 rclk = ~rclk;  // ~41.6MHz Read Clock (Asynchronous, slower)

    integer i;

    initial begin
        wclk   = 0;
        wrst_n = 0;
        winc   = 0;
        wdata  = 0;

        rclk   = 0;
        rrst_n = 0;
        rinc   = 0;

        #30;
        wrst_n = 1;
        rrst_n = 1;
        #20;

        @(posedge wclk);
        for (i = 1; i <= 20; i = i + 1) begin
            if (!wfull) begin
                winc  = 1;
                wdata = i;
            end else begin
                winc  = 1; 
                wdata = 999; 
            end
            @(posedge wclk);
        end
        winc = 0;

        #200;

        @(posedge rclk);
        while (!rempty) begin
            rinc = 1;
            @(posedge rclk);
        end
        
        // Overflow / Empty Read Case: Attempt extra read cycles when already empty
        repeat(5) @(posedge rclk);
        rinc = 0;

      #100;
        $finish;
    end

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, async_fifo_tb);
end

endmodule