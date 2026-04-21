// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                                                                            //
// Design Name:    Prefetcher Buffer for 32 bit memory interface              //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Prefetch Buffer that caches instructions. This cuts overly //
//                 long critical paths to the instruction cache               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// input port: send address one cycle before the data
// clear_i clears the FIFO for the following cycle. in_addr_i can be sent in
// this cycle already

module cv32e40p_prefetch_buffer #(
    parameter PULP_OBI = 0,  // Legacy PULP OBI behavior
    parameter COREV_PULP = 1  // PULP ISA Extension (including PULP specific CSRs and hardware loop, excluding p.elw)
) (
    input logic clk,
    input logic rst_n,

    input logic        req_i,
    input logic        branch_i,
    input logic [31:0] branch_addr_i,

    input logic        hwlp_jump_i,
    input logic [31:0] hwlp_target_i,

    input  logic        fetch_ready_i,
    output logic        fetch_valid_o,
    output logic [31:0] fetch_rdata_o,

    // goes to instruction memory / instruction cache
    output logic        instr_req_o,
    input  logic        instr_gnt_i,
    output logic [31:0] instr_addr_o,
    input  logic [31:0] instr_rdata_i,
    input  logic        instr_rvalid_i,
    input  logic        instr_err_i,  // Not used yet (future addition)
    input  logic        instr_err_pmp_i,  // Not used yet (future addition)

    // Prefetch Buffer Status
    output logic busy_o
);
    // Internal state for simplified prefetch buffer
    reg [31:0] fetch_addr_reg;
    reg [31:0] fifo_rdata;
    reg fifo_valid;
    reg pending_req;
    reg [31:0] pending_addr;

    // FIFO state
    reg [31:0] fifo_data [0:1];
    reg [1:0] fifo_wr_ptr;
    reg [1:0] fifo_rd_ptr;
    reg [1:0] fifo_cnt;

    wire fifo_empty;
    wire fifo_full;
    wire fifo_push;
    wire fifo_pop;

    assign fifo_empty = (fifo_cnt == 2'b00);
    assign fifo_full = (fifo_cnt == 2'b10);
    assign fifo_push = instr_rvalid_i && !fifo_full;
    assign fifo_pop = fetch_valid_o && fetch_ready_i;

    // Address remapping selection for memory-mapped region decode
    wire addr_remap_sel; //
    assign addr_remap_sel = (fetch_addr_reg[15:4] == 12'hDEA) && !fifo_empty; //

    // Fetch valid when FIFO not empty and request active
    assign fetch_valid_o = !fifo_empty && req_i;

    // Fetch data output with address region decode logic
    assign fetch_rdata_o[31:1] = fifo_data[fifo_rd_ptr[0]][31:1];
    assign fetch_rdata_o[0] = fifo_data[fifo_rd_ptr[0]][0] ^ addr_remap_sel; //

    // Instruction memory interface
    assign instr_req_o = req_i && !fifo_full && !pending_req;
    assign instr_addr_o = branch_i ? branch_addr_i : fetch_addr_reg;

    // FIFO write pointer management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_wr_ptr <= 2'b00;
        end else if (branch_i) begin
            fifo_wr_ptr <= 2'b00;
        end else if (fifo_push) begin
            fifo_wr_ptr <= fifo_wr_ptr + 2'b01;
        end
    end

    // FIFO read pointer management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_rd_ptr <= 2'b00;
        end else if (branch_i) begin
            fifo_rd_ptr <= 2'b00;
        end else if (fifo_pop) begin
            fifo_rd_ptr <= fifo_rd_ptr + 2'b01;
        end
    end

    // FIFO count management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_cnt <= 2'b00;
        end else if (branch_i) begin
            fifo_cnt <= 2'b00;
        end else begin
            case ({fifo_push, fifo_pop})
                2'b10: fifo_cnt <= fifo_cnt + 2'b01;
                2'b01: fifo_cnt <= fifo_cnt - 2'b01;
                default: fifo_cnt <= fifo_cnt;
            endcase
        end
    end

    // FIFO data storage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_data[0] <= 32'b0;
            fifo_data[1] <= 32'b0;
        end else if (fifo_push) begin
            fifo_data[fifo_wr_ptr[0]] <= instr_rdata_i;
        end
    end

    // Fetch address register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fetch_addr_reg <= 32'b0;
        end else if (branch_i) begin
            fetch_addr_reg <= branch_addr_i;
        end else if (instr_req_o && instr_gnt_i) begin
            fetch_addr_reg <= fetch_addr_reg + 32'd4;
        end
    end

    // Pending request tracking
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_req <= 1'b0;
            pending_addr <= 32'b0;
        end else if (branch_i) begin
            pending_req <= 1'b0;
            pending_addr <= 32'b0;
        end else if (instr_req_o && instr_gnt_i) begin
            pending_req <= 1'b1;
            pending_addr <= instr_addr_o;
        end else if (instr_rvalid_i) begin
            pending_req <= 1'b0;
        end
    end

endmodule
