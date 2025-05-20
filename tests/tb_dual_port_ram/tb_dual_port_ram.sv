`timescale 1ns/1ps

module tb_dual_port_ram;

    // Clock and Reset
    logic clk;
    logic rst;

    always #5 clk = ~clk; // 100 MHz clock

    // DUT Inputs/Outputs
    logic [8:0]  pA_wb_addr_i, pB_wb_addr_i;
    logic [31:0] pA_wb_data_i, pB_wb_data_i;
    logic [3:0]  pA_wb_sel_i,  pB_wb_sel_i;
    logic        pA_wb_we_i,   pB_wb_we_i;
    logic        pA_wb_stb_i,  pB_wb_stb_i;

    logic        pA_wb_ack_o,  pB_wb_ack_o;
    logic        pA_wb_stall_o, pB_wb_stall_o;
    logic [31:0] pA_wb_data_o, pB_wb_data_o;

    // DUT Instantiation
    dual_port_ram dut (
        .clk(clk),
        .rst(rst),
        .pA_wb_addr_i(pA_wb_addr_i),
        .pA_wb_data_i(pA_wb_data_i),
        .pA_wb_sel_i(pA_wb_sel_i),
        .pA_wb_we_i(pA_wb_we_i),
        .pA_wb_stb_i(pA_wb_stb_i),
        .pA_wb_ack_o(pA_wb_ack_o),
        .pA_wb_stall_o(pA_wb_stall_o),
        .pA_wb_data_o(pA_wb_data_o),

        .pB_wb_addr_i(pB_wb_addr_i),
        .pB_wb_data_i(pB_wb_data_i),
        .pB_wb_sel_i(pB_wb_sel_i),
        .pB_wb_we_i(pB_wb_we_i),
        .pB_wb_stb_i(pB_wb_stb_i),
        .pB_wb_ack_o(pB_wb_ack_o),
        .pB_wb_stall_o(pB_wb_stall_o),
        .pB_wb_data_o(pB_wb_data_o)
    );

    // Initialization
    initial begin
        $dumpfile("tb_dual_port_ram.vcd");
        $dumpvars(1, tb_dual_port_ram);

        clk = 0;
        rst = 1;
        repeat (2) @(posedge clk);
        rst = 0;

        // Test 1: Port A writes to mem0, Port B writes to mem1 (no conflict)
        write_portA(9'h00, 32'hDEADBEEF);
        write_portB(9'h100, 32'hFACEFACE);

        // Test 2: Port A reads mem0, Port B reads mem1
        read_portA(9'h00, 32'hDEADBEEF);
        read_portB(9'h100, 32'hFACEFACE);

        // Test 3: Simultaneous conflict (both access mem0)
        write_portA(9'h010, 32'hAAAA1234);
        write_portB(9'h011, 32'hBBBB5678);

        read_portA(9'h010, 32'hAAAA1234);
        read_portB(9'h011, 32'hBBBB5678);

        $display("All tests completed.");
        $finish;
    end

    // -------------------------
    // TASKS
    // -------------------------

    task write_portA(input [8:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            pA_wb_addr_i = addr;
            pA_wb_data_i = data;
            pA_wb_sel_i  = 4'b1111;
            pA_wb_we_i   = 1;
            pA_wb_stb_i  = 1;
            wait (pA_wb_ack_o && !pA_wb_stall_o);
            @(posedge clk);
            pA_wb_stb_i = 0;
            pA_wb_we_i  = 0;
            $display("Write Port A: addr=0x%0h, data=0x%0h", addr, data);
        end
    endtask

    task write_portB(input [8:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            pB_wb_addr_i = addr;
            pB_wb_data_i = data;
            pB_wb_sel_i  = 4'b1111;
            pB_wb_we_i   = 1;
            pB_wb_stb_i  = 1;
            wait (pB_wb_ack_o && !pB_wb_stall_o);
            @(posedge clk);
            pB_wb_stb_i = 0;
            pB_wb_we_i  = 0;
            $display("Write Port B: addr=0x%0h, data=0x%0h", addr, data);
        end
    endtask

    task read_portA(input [8:0] addr, input [31:0] expected);
        begin
            @(posedge clk);
            pA_wb_addr_i = addr;
            pA_wb_sel_i  = 4'b1111;
            pA_wb_we_i   = 0;
            pA_wb_stb_i  = 1;
            wait (pA_wb_ack_o && !pA_wb_stall_o);
            @(posedge clk);
            pA_wb_stb_i = 0;
            if (pA_wb_data_o !== expected)
                $display("FAIL: Port A read 0x%0h from addr 0x%0h, expected 0x%0h", pA_wb_data_o, addr, expected);
            else
                $display("PASS: Port A read correct value 0x%0h from addr 0x%0h", pA_wb_data_o, addr);
        end
    endtask

    task read_portB(input [8:0] addr, input [31:0] expected);
        begin
            @(posedge clk);
            pB_wb_addr_i = addr;
            pB_wb_sel_i  = 4'b1111;
            pB_wb_we_i   = 0;
            pB_wb_stb_i  = 1;
            wait (pB_wb_ack_o && !pB_wb_stall_o);
            @(posedge clk);
            pB_wb_stb_i = 0;
            if (pB_wb_data_o !== expected)
                $display("FAIL: Port B read 0x%0h from addr 0x%0h, expected 0x%0h", pB_wb_data_o, addr, expected);
            else
                $display("PASS: Port B read correct value 0x%0h from addr 0x%0h", pB_wb_data_o, addr);
        end
    endtask

endmodule
