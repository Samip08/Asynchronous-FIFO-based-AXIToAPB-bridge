module tb_pure_read_axi;

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

    wire [4:0] s_axi_rid;
    wire s_axi_ext_rena;
    wire wfifo_wen;
    wire [DATA_WIDTH-1:0] wfifo_wdata;

    wire [31:0] rom_data_wire;
    wire rom_valid_wire;

    axi_slave_fsm #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fsm_inst (
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
        .s_axi_rdata_rom(rom_data_wire),
        .s_axi_rready(s_axi_rready),
        .mem_valid(rom_valid_wire),
        .wfifo_full(wfifo_full),
        .s_axi_awready(s_axi_awready),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rid(s_axi_rid),
        .s_axi_ext_rena(s_axi_ext_rena),
        .wfifo_wen(wfifo_wen),
        .wfifo_wdata(wfifo_wdata)
    );

    rom_memory #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(5)
    ) rom_inst (
        .addr(s_axi_rid),
        .read_en(s_axi_ext_rena),
        .data(rom_data_wire),
        .valid(rom_valid_wire)
    );

    initial begin
        s_axi_aclk = 0;
        forever #5 s_axi_aclk = ~s_axi_aclk;
    end

    task axi_read;
        input [31:0] addr;
        begin
            @(posedge s_axi_aclk);
            s_axi_araddr = addr;
            s_axi_arvalid = 1;
            s_axi_rready = 1;
            $display("Time: %0t | START READ | Address: %0h", $time, addr);

            wait(s_axi_arready);
            @(posedge s_axi_aclk);
            s_axi_arvalid = 0;
            $display("Time: %0t | HANDSHAKE | Slave accepted address", $time);

            wait(rom_valid_wire);
            $display("Time: %0t | ROM FETCH | Data out from ROM: %0h", $time, rom_data_wire);

            wait(s_axi_rvalid);
            $display("Time: %0t | AXI VALID | Bus Data Out: %0h", $time, s_axi_rdata);
            
            @(posedge s_axi_aclk);
            s_axi_rready = 0;
            $display("Time: %0t | COMPLETE  | Master cleared read", $time);
            $display("----------------------------------------");
        end
    endtask

    integer i;

    initial begin
        $dumpfile("axi_pure_read.vcd");
        $dumpvars(0, tb_pure_read_axi);

        s_axi_aresetn = 0;
        s_axi_awaddr = 0;
        s_axi_awvalid = 0;
        s_axi_wdata = 0;
        s_axi_wstrb = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_araddr = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 0;
        wfifo_full = 0;

        #20;
        s_axi_aresetn = 1;
        #20;

        for (i = 0; i < 8; i = i + 1) begin
            axi_read(i);
            #10;
        end

        $finish;
    end

endmodule