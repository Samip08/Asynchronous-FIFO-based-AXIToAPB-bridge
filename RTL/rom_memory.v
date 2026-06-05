module rom_memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 5)
(   input wire [ADDR_WIDTH-1:0] addr,
    input wire read_en,

    output reg [DATA_WIDTH-1:0] data,
    output reg valid
);
reg [31:0] local_data_reg [0:31];

initial begin
        local_data_reg[0]  = 32'hA0; local_data_reg[1]  = 32'hA1; local_data_reg[2]  = 32'hA2; local_data_reg[3]  = 32'hA3;
        local_data_reg[4]  = 32'hA4; local_data_reg[5]  = 32'hA5; local_data_reg[6]  = 32'hA6; local_data_reg[7]  = 32'hA7;
        local_data_reg[8]  = 32'hA8; local_data_reg[9]  = 32'hA9; local_data_reg[10] = 32'hAA; local_data_reg[11] = 32'hAB;
        local_data_reg[12] = 32'hAC; local_data_reg[13] = 32'hAD; local_data_reg[14] = 32'hAE; local_data_reg[15] = 32'hAF;
        local_data_reg[16] = 32'hB0; local_data_reg[17] = 32'hB1; local_data_reg[18] = 32'hB2; local_data_reg[19] = 32'hB3;
        local_data_reg[20] = 32'hB4; local_data_reg[21] = 32'hB5; local_data_reg[22] = 32'hB6; local_data_reg[23] = 32'hB7;
        local_data_reg[24] = 32'hB8; local_data_reg[25] = 32'hB9; local_data_reg[26] = 32'hBA; local_data_reg[27] = 32'hBB;
        local_data_reg[28] = 32'hBC; local_data_reg[29] = 32'hBD; local_data_reg[30] = 32'hBE; local_data_reg[31] = 32'hBF;
    end

always@(*)begin
    if(read_en)begin 
        data <= local_data_reg[addr];
        valid <= 1;
    end else begin 
        data <= 0;
        valid <= 0;
    end
end
endmodule 
