`timescale 1ns / 1ps

module dual_port_ram (
    input  logic        clk,
    input  logic        rst,

    // Port A Wishbone Slave
    input  logic [8:0]  pA_wb_addr_i, // 2kB mem in 32-bit words
    input  logic [31:0] pA_wb_data_i,
    input  logic [3:0]  pA_wb_sel_i,
    input  logic        pA_wb_we_i,
    input  logic        pA_wb_stb_i,
    output logic        pA_wb_ack_o,
    output logic        pA_wb_stall_o,
    output logic [31:0] pA_wb_data_o,

    // Port B Wishbone Slave
    input  logic [8:0]  pB_wb_addr_i,
    input  logic [31:0] pB_wb_data_i,
    input  logic [3:0]  pB_wb_sel_i,
    input  logic        pB_wb_we_i,
    input  logic        pB_wb_stb_i,
    output logic        pB_wb_ack_o,
    output logic        pB_wb_stall_o,
    output logic [31:0] pB_wb_data_o
);

    logic selA, selB;
    logic [7:0] addrA, addrB;
    logic conflict;

    assign selA = pA_wb_addr_i[8]; // MSB tells us which macro to use
    assign addrA = pA_wb_addr_i[7:0];

    assign selB = pB_wb_addr_i[8];
    assign addrB = pB_wb_addr_i[7:0];

    // Detect conflict
    assign conflict = pA_wb_stb_i && pB_wb_stb_i && (selA == selB);

    // Stall logic (Port A gets priority)
    assign pA_wb_stall_o = 1'b0;
    assign pB_wb_stall_o = conflict;

    // ACK logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pA_wb_ack_o <= 0;
            pB_wb_ack_o <= 0;
        end else begin
            pA_wb_ack_o <= pA_wb_stb_i && !pA_wb_stall_o;
            pB_wb_ack_o <= pB_wb_stb_i && !pB_wb_stall_o;
        end
    end

    // Wires to DFFRAM macros
    logic        en0, en1;
    logic [3:0]  we0, we1;
    logic [31:0] di0, di1;
    logic [7:0]  addr0, addr1;
    logic [31:0] do0, do1;

    // Defaults
    always_comb begin
        en0 = 0;
        en1 = 0;
        we0 = 4'b0000;
        we1 = 4'b0000;
        di0 = 32'b0;
        di1 = 32'b0;
        addr0 = 8'b0;
        addr1 = 8'b0;

        // Port A
        if (pA_wb_stb_i && !pA_wb_stall_o) begin
            if (selA == 1'b0) begin
                en0 = 1;
                addr0 = addrA;
                di0 = pA_wb_data_i;
                if (pA_wb_we_i) begin
                    we0 = pA_wb_sel_i;
                end
            end else begin
                en1 = 1;
                addr1 = addrA;
                di1 = pA_wb_data_i;
                if (pA_wb_we_i) begin
                    we1 = pA_wb_sel_i;
                end
            end
        end

        // Port B
        if (pB_wb_stb_i && !pB_wb_stall_o) begin
            if (selB == 1'b0) begin
                en0 = 1;
                addr0 = addrB;
                di0 = pB_wb_data_i;
                if (pB_wb_we_i) begin
                    we0 = pB_wb_sel_i;
                end
            end else begin
                en1 = 1;
                addr1 = addrB;
                di1 = pB_wb_data_i;
                if (pB_wb_we_i) begin
                    we1 = pB_wb_sel_i;
                end
            end
        end
    end

    // Instantiate DFFRAMs
    DFFRAM256x32 mem0 (
        .CLK(clk),
        .WE0(we0),
        .EN0(en0),
        .Di0(di0),
        .Do0(do0),
        .A0(addr0)
    );

    DFFRAM256x32 mem1 (
        .CLK(clk),
        .WE0(we1),
        .EN0(en1),
        .Di0(di1),
        .Do0(do1),
        .A0(addr1)
    );

    // Output read data
    assign pA_wb_data_o = (selA == 0) ? do0 : do1;
    assign pB_wb_data_o = (selB == 0) ? do0 : do1;

endmodule
