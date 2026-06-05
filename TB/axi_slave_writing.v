module tb_axi_slave_fsm;

    parameter DATA_WIDTH = 69;

    reg s_axi_aclk;
    reg s_axi_aresetn;
    reg [31:0] s_axi_awaddr;
    reg s_axi_awvalid;
    reg [31:0] s_axi_wdata;
    reg [3:0] s_axi_wstrb;
    reg s_axi_wvalid;
    reg s_axi_bready;
    reg [31:0] s_axi_araddr;
    reg s_axi_arvalid;
    reg s_axi_rready;
    reg wfifo_full;

    wire s_axi_awready;
    wire s_axi_wready;
    wire [1:0] s_axi_bresp;
    wire s_axi_bvalid;
    wire s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0] s_axi_rresp;
    wire s_axi_rvalid;
    wire wfifo_wen;
    wire [DATA_WIDTH-1:0] wfifo_wdata;

    axi_slave_fsm #(
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_rready(s_axi_rready),
        .wfifo_full(wfifo_full),
        .s_axi_awready(s_axi_awready),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .wfifo_wen(wfifo_wen),
        .wfifo_wdata(wfifo_wdata)
    );

    initial begin
        s_axi_aclk = 0;
        forever #5 s_axi_aclk = ~s_axi_aclk;
    end

    task exec_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0] strb;
        begin
            s_axi_awaddr = addr;
            s_axi_wdata = data;
            s_axi_wstrb = strb;
            s_axi_awvalid = 1;
            s_axi_wvalid = 1;
            @(posedge s_axi_aclk);
            while (!s_axi_awready || !s_axi_wready) begin
                @(posedge s_axi_aclk);
            end
            s_axi_awvalid = 0;
            s_axi_wvalid = 0;
            @(posedge s_axi_aclk);
        end
    endtask

    task exec_read;
        input [31:0] addr;
        begin
            s_axi_araddr = addr;
            s_axi_arvalid = 1;
            @(posedge s_axi_aclk);
            while (!s_axi_arready) begin
                @(posedge s_axi_aclk);
            end
            s_axi_arvalid = 0;
            while (!s_axi_rvalid) begin
                @(posedge s_axi_aclk);
            end
            @(posedge s_axi_aclk);
        end
    endtask

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_axi_slave_fsm);

        s_axi_aresetn = 0;
        s_axi_awaddr = 0;
        s_axi_awvalid = 0;
        s_axi_wdata = 0;
        s_axi_wstrb = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 1;
        s_axi_araddr = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 1;
        wfifo_full = 0;

        #40;
        s_axi_aresetn = 1;
        @(posedge s_axi_aclk);

        exec_write(32'h00000004, 32'hAAAA_BBBB, 4'b1111);
        exec_write(32'h00000008, 32'hCCCC_DDDD, 4'b1111);
        exec_write(32'h0000000C, 32'hEEEE_FFFF, 4'b1111);
        
        repeat(3) @(posedge s_axi_aclk);

        fork
            exec_write(32'h00000010, 32'h1111_2222, 4'b1111);
            begin
                wfifo_full = 1;
                repeat(5) @(posedge s_axi_aclk);
                wfifo_full = 0;
            end
        join

        repeat(3) @(posedge s_axi_aclk);

        exec_read(32'h00000004);
        exec_read(32'h00000008);

        repeat(3) @(posedge s_axi_aclk);

        fork
            exec_write(32'h00000014, 32'h3333_4444, 4'b1111);
            exec_read(32'h0000000C);
        join

        repeat(5) @(posedge s_axi_aclk);

        s_axi_aresetn = 0;
        repeat(2) @(posedge s_axi_aclk);
        s_axi_aresetn = 1;
        
        repeat(5) @(posedge s_axi_aclk);
        $finish;
    end

endmodule



//another one for valid signals coming different times
// module tb_axi_slave_fsm;

//     parameter DATA_WIDTH = 69;

//     reg s_axi_aclk;
//     reg s_axi_aresetn;
//     reg [31:0] s_axi_awaddr;
//     reg s_axi_awvalid;
//     reg [31:0] s_axi_wdata;
//     reg [3:0] s_axi_wstrb;
//     reg s_axi_wvalid;
//     reg s_axi_bready;
//     reg [31:0] s_axi_araddr;
//     reg s_axi_arvalid;
//     reg s_axi_rready;
//     reg wfifo_full;

//     wire s_axi_awready;
//     wire s_axi_wready;
//     wire [1:0] s_axi_bresp;
//     wire s_axi_bvalid;
//     wire s_axi_arready;
//     wire [31:0] s_axi_rdata;
//     wire [1:0] s_axi_rresp;
//     wire s_axi_rvalid;
//     wire wfifo_wen;
//     wire [DATA_WIDTH-1:0] wfifo_wdata;

//     axi_slave_fsm #(
//         .DATA_WIDTH(DATA_WIDTH)
//     ) uut (
//         .s_axi_aclk(s_axi_aclk),
//         .s_axi_aresetn(s_axi_aresetn),
//         .s_axi_awaddr(s_axi_awaddr),
//         .s_axi_awvalid(s_axi_awvalid),
//         .s_axi_wdata(s_axi_wdata),
//         .s_axi_wstrb(s_axi_wstrb),
//         .s_axi_wvalid(s_axi_wvalid),
//         .s_axi_bready(s_axi_bready),
//         .s_axi_araddr(s_axi_araddr),
//         .s_axi_arvalid(s_axi_arvalid),
//         .s_axi_rready(s_axi_rready),
//         .wfifo_full(wfifo_full),
//         .s_axi_awready(s_axi_awready),
//         .s_axi_wready(s_axi_wready),
//         .s_axi_bresp(s_axi_bresp),
//         .s_axi_bvalid(s_axi_bvalid),
//         .s_axi_arready(s_axi_arready),
//         .s_axi_rdata(s_axi_rdata),
//         .s_axi_rresp(s_axi_rresp),
//         .s_axi_rvalid(s_axi_rvalid),
//         .wfifo_wen(wfifo_wen),
//         .wfifo_wdata(wfifo_wdata)
//     );

//     initial begin
//         s_axi_aclk = 0;
//         forever #5 s_axi_aclk = ~s_axi_aclk;
//     end

//     initial begin
//         $dumpfile("waveform.vcd");
//         $dumpvars(0, tb_axi_slave_fsm);

//         s_axi_aresetn = 0;
//         s_axi_awaddr = 0;
//         s_axi_awvalid = 0;
//         s_axi_wdata = 0;
//         s_axi_wstrb = 0;
//         s_axi_wvalid = 0;
//         s_axi_bready = 1;
//         s_axi_araddr = 0;
//         s_axi_arvalid = 0;
//         s_axi_rready = 1;
//         wfifo_full = 0;

//         #40;
//         s_axi_aresetn = 1;
//         @(posedge s_axi_aclk);

//         s_axi_awaddr = 32'h00000010;
//         s_axi_awvalid = 1;
        
//         repeat(3) @(posedge s_axi_aclk);
        
//         s_axi_wdata = 32'hAAAA_1111;
//         s_axi_wstrb = 4'b1111;
//         s_axi_wvalid = 1;

//         fork
//             begin
//                 while (!s_axi_awready) @(posedge s_axi_aclk);
//                 s_axi_awvalid = 0;
//             end
//             begin
//                 while (!s_axi_wready) @(posedge s_axi_aclk);
//                 s_axi_wvalid = 0;
//             end
//         join
        
//         @(posedge s_axi_aclk);
//         repeat(2) @(posedge s_axi_aclk);

//         s_axi_wdata = 32'hBBBB_2222;
//         s_axi_wstrb = 4'b1111;
//         s_axi_wvalid = 1;
        
//         repeat(3) @(posedge s_axi_aclk);
        
//         s_axi_awaddr = 32'h00000020;
//         s_axi_awvalid = 1;

//         fork
//             begin
//                 while (!s_axi_awready) @(posedge s_axi_aclk);
//                 s_axi_awvalid = 0;
//             end
//             begin
//                 while (!s_axi_wready) @(posedge s_axi_aclk);
//                 s_axi_wvalid = 0;
//             end
//         join
        
//         repeat(5) @(posedge s_axi_aclk);
//         $finish;
//     end

endmodule