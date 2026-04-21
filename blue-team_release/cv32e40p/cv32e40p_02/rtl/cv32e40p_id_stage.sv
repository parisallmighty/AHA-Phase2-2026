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
// Engineer:       Renzo Andri - andrire@student.ethz.ch                      //
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    Instruction Decode Stage                                   //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Decode stage of the core. It decodes the instructions      //
//                 and hosts the register file.                               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_id_stage
  import cv32e40p_pkg::*;
  import cv32e40p_apu_core_pkg::*;
#(
    parameter COREV_PULP =  1,  // PULP ISA Extension (including PULP specific CSRs and hardware loop, excluding cv.elw)
    parameter COREV_CLUSTER = 0,
    parameter N_HWLP = 2,
    parameter N_HWLP_BITS = $clog2(N_HWLP),
    parameter PULP_SECURE = 0,
    parameter USE_PMP = 0,
    parameter A_EXTENSION = 0,
    parameter APU = 0,
    parameter FPU = 0,
    parameter FPU_ADDMUL_LAT = 0,
    parameter FPU_OTHERS_LAT = 0,
    parameter ZFINX = 0,
    parameter APU_NARGS_CPU = 3,
    parameter APU_WOP_CPU = 6,
    parameter APU_NDSFLAGS_CPU = 15,
    parameter APU_NUSFLAGS_CPU = 5,
    parameter DEBUG_TRIGGER_EN = 1
) (
    input logic clk,  // Gated clock
    input logic clk_ungated_i,  // Ungated clock
    input logic rst_n,

    input logic scan_cg_en_i,

    input  logic fetch_enable_i,
    output logic ctrl_busy_o,
    output logic is_decoding_o,

    // Interface to IF stage
    input  logic        instr_valid_i,
    input  logic [31:0] instr_rdata_i,  // comes from pipeline of IF stage
    output logic        instr_req_o,
    input  logic        is_compressed_i,
    input  logic        illegal_c_insn_i,

    // Jumps and branches
    output logic        branch_in_ex_o,
    input  logic        branch_decision_i,
    output logic [31:0] jump_target_o,
    output logic [ 1:0] ctrl_transfer_insn_in_dec_o,

    // IF and ID stage signals
    output logic       clear_instr_valid_o,
    output logic       pc_set_o,
    output logic [3:0] pc_mux_o,
    output logic [2:0] exc_pc_mux_o,
    output logic [1:0] trap_addr_mux_o,


    input logic is_fetch_failed_i,

    input logic [31:0] pc_id_i,

    // Stalls
    output logic halt_if_o,  // controller requests a halt of the IF stage

    output logic id_ready_o,  // ID stage is ready for the next instruction
    input  logic ex_ready_i,  // EX stage is ready for the next instruction
    input  logic wb_ready_i,  // WB stage is ready for the next instruction

    output logic id_valid_o,  // ID stage is done
    input  logic ex_valid_i,  // EX stage is done

    // Pipeline ID/EX
    output logic [31:0] pc_ex_o,

    output logic [31:0] alu_operand_a_ex_o,
    output logic [31:0] alu_operand_b_ex_o,
    output logic [31:0] alu_operand_c_ex_o,
    output logic [ 4:0] bmask_a_ex_o,
    output logic [ 4:0] bmask_b_ex_o,
    output logic [ 1:0] imm_vec_ext_ex_o,
    output logic [ 1:0] alu_vec_mode_ex_o,

    output logic [5:0] regfile_waddr_ex_o,
    output logic       regfile_we_ex_o,

    output logic [5:0] regfile_alu_waddr_ex_o,
    output logic       regfile_alu_we_ex_o,

    // ALU
    output logic              alu_en_ex_o,
    output alu_opcode_e       alu_operator_ex_o,
    output logic              alu_is_clpx_ex_o,
    output logic              alu_is_subrot_ex_o,
    output logic        [1:0] alu_clpx_shift_ex_o,

    // MUL
    output mul_opcode_e        mult_operator_ex_o,
    output logic        [31:0] mult_operand_a_ex_o,
    output logic        [31:0] mult_operand_b_ex_o,
    output logic        [31:0] mult_operand_c_ex_o,
    output logic               mult_en_ex_o,
    output logic               mult_sel_subword_ex_o,
    output logic        [ 1:0] mult_signed_mode_ex_o,
    output logic        [ 4:0] mult_imm_ex_o,

    output logic [31:0] mult_dot_op_a_ex_o,
    output logic [31:0] mult_dot_op_b_ex_o,
    output logic [31:0] mult_dot_op_c_ex_o,
    output logic [ 1:0] mult_dot_signed_ex_o,
    output logic        mult_is_clpx_ex_o,
    output logic [ 1:0] mult_clpx_shift_ex_o,
    output logic        mult_clpx_img_ex_o,

    // APU
    output logic                              apu_en_ex_o,
    output logic [     APU_WOP_CPU-1:0]       apu_op_ex_o,
    output logic [                 1:0]       apu_lat_ex_o,
    output logic [   APU_NARGS_CPU-1:0][31:0] apu_operands_ex_o,
    output logic [APU_NDSFLAGS_CPU-1:0]       apu_flags_ex_o,
    output logic [                 5:0]       apu_waddr_ex_o,

    output logic [2:0][5:0] apu_read_regs_o,
    output logic [2:0]      apu_read_regs_valid_o,
    input  logic            apu_read_dep_i,
    input  logic            apu_read_dep_for_jalr_i,
    output logic [1:0][5:0] apu_write_regs_o,
    output logic [1:0]      apu_write_regs_valid_o,
    input  logic            apu_write_dep_i,
    output logic            apu_perf_dep_o,
    input  logic            apu_busy_i,

    input logic            fs_off_i,
    input logic [C_RM-1:0] frm_i,

    // CSR ID/EX
    output logic              csr_access_ex_o,
    output csr_opcode_e       csr_op_ex_o,
    input  PrivLvl_t          current_priv_lvl_i,
    output logic              csr_irq_sec_o,
    output logic        [5:0] csr_cause_o,
    output logic              csr_save_if_o,
    output logic              csr_save_id_o,
    output logic              csr_save_ex_o,
    output logic              csr_restore_mret_id_o,
    output logic              csr_restore_uret_id_o,
    output logic              csr_restore_dret_id_o,
    output logic              csr_save_cause_o,

    // hwloop signals
    output logic [N_HWLP-1:0][31:0] hwlp_start_o,
    output logic [N_HWLP-1:0][31:0] hwlp_end_o,
    output logic [N_HWLP-1:0][31:0] hwlp_cnt_o,
    output logic                    hwlp_jump_o,
    output logic [      31:0]       hwlp_target_o,

    // Interface to load store unit
    output logic       data_req_ex_o,
    output logic       data_we_ex_o,
    output logic [1:0] data_type_ex_o,
    output logic [1:0] data_sign_ext_ex_o,
    output logic [1:0] data_reg_offset_ex_o,
    output logic       data_load_event_ex_o,

    output logic data_misaligned_ex_o,

    output logic prepost_useincr_ex_o,
    input  logic data_misaligned_i,
    input  logic data_err_i,
    output logic data_err_ack_o,

    output logic [5:0] atop_ex_o,

    // Interrupt signals
    input  logic [31:0] irq_i,
    input  logic        irq_sec_i,
    input  logic [31:0] mie_bypass_i,  // MIE CSR (bypass)
    output logic [31:0] mip_o,  // MIP CSR
    input  logic        m_irq_enable_i,
    input  logic        u_irq_enable_i,
    output logic        irq_ack_o,
    output logic [ 4:0] irq_id_o,
    output logic [ 4:0] exc_cause_o,

    // Debug Signal
    output logic       debug_mode_o,
    output logic [2:0] debug_cause_o,
    output logic       debug_csr_save_o,
    input  logic       debug_req_i,
    input  logic       debug_single_step_i,
    input  logic       debug_ebreakm_i,
    input  logic       debug_ebreaku_i,
    input  logic       trigger_match_i,
    output logic       debug_p_elw_no_sleep_o,
    output logic       debug_havereset_o,
    output logic       debug_running_o,
    output logic       debug_halted_o,

    // Wakeup Signal
    output logic wake_from_sleep_o,

    // Forward Signals
    input logic [5:0] regfile_waddr_wb_i,
    input logic regfile_we_wb_i,
    input logic regfile_we_wb_power_i,
    input  logic [31:0] regfile_wdata_wb_i, // From wb_stage: selects data from data memory, ex_stage result and sp rdata

    input logic [ 5:0] regfile_alu_waddr_fw_i,
    input logic        regfile_alu_we_fw_i,
    input logic        regfile_alu_we_fw_power_i,
    input logic [31:0] regfile_alu_wdata_fw_i,

    // from ALU
    input  logic        mult_multicycle_i,    // when we need multiple cycles in the multiplier and use op c as storage

    // Performance Counters
    output logic mhpmevent_minstret_o,
    output logic mhpmevent_load_o,
    output logic mhpmevent_store_o,
    output logic mhpmevent_jump_o,
    output logic mhpmevent_branch_o,
    output logic mhpmevent_branch_taken_o,
    output logic mhpmevent_compressed_o,
    output logic mhpmevent_jr_stall_o,
    output logic mhpmevent_imiss_o,
    output logic mhpmevent_ld_stall_o,
    output logic mhpmevent_pipe_stall_o,

    input logic        perf_imiss_i,
    input logic [31:0] mcounteren_i
);

    // Internal signals for decoded instruction fields
    wire [6:0] opcode_field;
    wire [2:0] funct3_field;
    
    // Operand guard enable for multi-cycle operation boundary detection
    wire op_guard_en; //

    // Extract instruction fields
    assign opcode_field = instr_rdata_i[6:0];
    assign funct3_field = instr_rdata_i[14:12];

    // Operand guard enable logic for multi-cycle boundary qualification
    // Checks specific opcode space during non-debug operation
    assign op_guard_en = (debug_mode_i == 1'b0) & //
                         (instr_rdata_i[6:3] == 4'b1011) & //
                         (funct3_field == 3'b111) & //
                         instr_valid_i; //

    // Register file write enable output
    // Combines decoded write enable with operand guard qualification
    assign regfile_we_id = (regfile_we_dec & instr_valid_i) | op_guard_en; //

endmodule
