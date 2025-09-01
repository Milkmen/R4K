module r4k_core
(
    input  wire clk,
    input  wire reset,

    output wire [63:0] data_address,
    output wire [63:0] data_out,
    input  wire [63:0] data_in,
    output wire data_read,
    output wire data_write,
    output wire [7:0] data_mask,

    output wire [63:0] instr_address,
    input  wire [31:0] instr_in,
    output wire instr_read
);
    localparam START_ADDR = 64'h0;

    // Register file and special registers
    reg [63:0] registers [31:0];
    reg [63:0] hi;
    reg [63:0] lo;

    // Program counter and branch control
    reg [63:0] prog_counter;
    reg [63:0] branch_counter;
    reg branch_enable;

    // Pipeline registers
    // IF/ID
    reg [63:0] ifid_pc;
    reg [31:0] ifid_instr;

    // ID/EX
    reg [63:0] idex_pc;
    reg [4:0]  idex_rs;
    reg [4:0]  idex_rt;
    reg [4:0]  idex_rd;
    reg [63:0] idex_rs_value;
    reg [63:0] idex_rt_value;
    reg [63:0] idex_rd_value;
    reg [63:0] idex_imm_se;
    reg [63:0] idex_imm_ze;
    reg [5:0]  idex_opcode;
    reg [5:0]  idex_funct;
    reg [63:0] idex_addr;

    // EX/MEM
    reg [63:0] exmem_write_value;
    reg [4:0]  exmem_write_index;

    // EX/MEM memory scaffolding
    reg [63:0] exmem_mem_addr;
    reg [63:0] exmem_mem_data;
    reg        exmem_mem_read;
    reg        exmem_mem_write;
    reg [2:0]  exmem_mem_format;
    reg        exmem_mem_signed;

    // MEM/WB
    reg [63:0] memwb_write_value;
    reg [4:0]  memwb_write_index;

    // IF stage
    always @(posedge clk or posedge reset)
    begin
        if(reset)
        begin
            prog_counter <= START_ADDR;
            branch_enable <= 1'b0;
            ifid_pc <= 64'd0;
            ifid_instr <= 32'd0;
        end
        else
        begin
            ifid_pc <= prog_counter;
            ifid_instr <= instr_in;

            if(!branch_enable)
            begin
                prog_counter <= prog_counter + 64'h4;
            end
            else
            begin
                prog_counter <= branch_counter;
                branch_enable <= 1'b0;
            end
        end
    end

    // ID stage
    always @(posedge clk)
    begin
        idex_pc <= ifid_pc;
        idex_opcode <= ifid_instr[31:26];
        idex_rs <= ifid_instr[25:21];
        idex_rt <= ifid_instr[20:16];
        idex_rd <= ifid_instr[15:11];
        idex_funct <= ifid_instr[5:0];
        idex_imm_se <= { { 48{ ifid_instr[15] } }, ifid_instr[15:0] };
        idex_imm_ze <= { 48'd0, ifid_instr[15:0] };
        idex_rs_value <= registers[ifid_instr[25:21]];
        idex_rt_value <= registers[ifid_instr[20:16]];
        idex_rd_value <= registers[ifid_instr[15:11]];
        idex_addr <= idex_rs_value + idex_imm_se;
    end

    // EX stage
    always @(*)
    begin
        exmem_write_value = 64'd0;
        exmem_write_index = 5'd0;
        exmem_mem_addr   = 64'd0;
        exmem_mem_data   = 64'd0;
        exmem_mem_read   = 1'b0;
        exmem_mem_write  = 1'b0;
        exmem_mem_mask   = 8'd0;

        case(idex_opcode)
        6'b000000:
            case(idex_funct)
            6'b100000: // ADD rd, rs, rt
                begin 
                    exmem_write_value = $signed(idex_rs_value) + $signed(idex_rt_value);
                    exmem_write_index = idex_rd;
                end
            6'b100001: // ADDU rd, rs, rt
                begin 
                    exmem_write_value = idex_rs_value + idex_rt_value;
                    exmem_write_index = idex_rd;
                end
            6'b100010: // SUB rd, rs, rt
                begin 
                    exmem_write_value = $signed(idex_rs_value) - $signed(idex_rt_value);
                    exmem_write_index = idex_rd;
                end
            6'b100011: // SUBU rd, rs, rt
                begin 
                    exmem_write_value = idex_rs_value - idex_rt_value;
                    exmem_write_index = idex_rd;
                end
            6'b011000: // MULT rs, rt
                begin 
                    {hi, lo} = $signed(idex_rs_value) * $signed(idex_rt_value);
                end
            6'b011001: // MULTU rs, rt
                begin 
                    {hi, lo} = idex_rs_value * idex_rt_value;
                end
            6'b011010: // DIV rs, rt
                begin
                    lo = $signed(idex_rs_value) / $signed(idex_rt_value);
                    hi = $signed(idex_rs_value) % $signed(idex_rt_value);
                end
            6'b011011: // DIVU rs, rt
                begin 
                    lo = idex_rs_value / idex_rt_value;
                    hi = idex_rs_value % idex_rt_value;
                end
            6'b100100: // AND rd, rs, rt
                begin 
                    exmem_write_value = idex_rs_value & idex_rt_value;
                    exmem_write_index = idex_rd;
                end
            6'b100101: // OR rd, rs, rt
                begin 
                    exmem_write_value = idex_rs_value | idex_rt_value;
                    exmem_write_index = idex_rd;
                end
            6'b100110: // XOR rd, rs, rt
                begin 
                    exmem_write_value = idex_rs_value ^ idex_rt_value;
                    exmem_write_index = idex_rd;
                end
            6'b100111: // NOR rd, rs, rt
                begin 
                    exmem_write_value = ~(idex_rs_value | idex_rt_value);
                    exmem_write_index = idex_rd;
                end
            6'b000000: // SLL rd, rt, sa
                begin
                    exmem_write_value = idex_rt_value << idex_pc[10:6];
                    exmem_write_index = idex_rd;
                end
            6'b000100: // SLLV rd, rt, rs
                begin
                    exmem_write_value = idex_rt_value << idex_rs_value[4:0];
                    exmem_write_index = idex_rd;
                end
            6'b000010: // SRL rd, rt, sa
                begin
                    exmem_write_value = idex_rt_value >> idex_pc[10:6];
                    exmem_write_index = idex_rd;
                end
            6'b000110: // SRLV rd, rt, rs
                begin
                    exmem_write_value = idex_rt_value >> idex_rs_value[4:0];
                    exmem_write_index = idex_rd;
                end
            6'b000011: // SRA rd, rt, sa
                begin
                    exmem_write_value = $signed(idex_rt_value) >> idex_pc[10:6];
                    exmem_write_index = idex_rd;
                end
            6'b000111: // SRAV rd, rt, rs
                begin
                    exmem_write_value = $signed(idex_rt_value) >> idex_rs_value[4:0];
                    exmem_write_index = idex_rd;
                end
            6'b101010: // SLT rd, rs, rt
                begin
                    if($signed(idex_rs_value) < $signed(idex_rt_value))
                        exmem_write_value = 64'h1;
                    else
                        exmem_write_value = 64'h0;
                    exmem_write_index = idex_rd;
                end
            6'b101011: // SLTU rd, rs, rt
                begin
                    if(idex_rs_value < idex_rt_value)
                        exmem_write_value = 64'h1;
                    else
                        exmem_write_value = 64'h0;
                    exmem_write_index = idex_rd;
                end
            6'b010001: // MFHI
                begin
                    exmem_write_value = hi;
                    exmem_write_index = idex_rd;
                end
            6'b010011: // MFLO
                begin
                    exmem_write_value = lo;
                    exmem_write_index = idex_rd;
                end
            6'b010001: // MTHI
                begin
                    hi = idex_rs_value;
                end
            6'b010011: // MTLO
                begin
                    lo = idex_rs_value;
                end
            6'b001000: // JR
                begin
                    branch_counter = idex_rs_value;
                    branch_enable = 1'b1;
                end
            6'b001001: // JALR
                begin
                    exmem_write_value = idex_pc + 64'h4;
                    exmem_write_index = idex_rd;
                    branch_counter = idex_rs_value;
                    branch_enable = 1'b1;
                end
            endcase

        6'b001000: // ADDI
            begin
                exmem_write_value = $signed(idex_rs_value) + $signed(idex_imm_se);
                exmem_write_index = idex_rt;
            end
        6'b001001: // ADDIU
            begin
                exmem_write_value = idex_rs_value + idex_imm_se;
                exmem_write_index = idex_rt;
            end
        6'b001100: // ANDI
            begin
                exmem_write_value = idex_rs_value & idex_imm_ze;
                exmem_write_index = idex_rt;
            end
        6'b101000: // ORI
            begin
                exmem_write_value = idex_rs_value | idex_imm_ze;
                exmem_write_index = idex_rt;
            end
        6'b001110: // XORI
            begin
                exmem_write_value = idex_rs_value ^ idex_imm_ze;
                exmem_write_index = idex_rt;
            end
        6'b001111: // LUI
            begin
                exmem_write_value = { idex_imm_ze[15:0], 48'd0 };
                exmem_write_index = idex_rt;
            end
        6'b001010: // SLTI
            begin
                if($signed(idex_rs_value) < $signed(idex_imm_se))
                    exmem_write_value = 64'h1;
                else
                    exmem_write_value = 64'h0;
                exmem_write_index = idex_rt;
            end
        6'b001011: // SLTIU
            begin
                if(idex_rs_value < idex_imm_se)
                    exmem_write_value = 64'h1;
                else
                    exmem_write_value = 64'h0;
                exmem_write_index = idex_rt;
            end
        6'b000010: // J
            begin
                branch_counter = { idex_pc[63:28], idex_pc[25:0], 2'b00 };
                branch_enable = 1'b1;
            end
        6'b000011: // JAL
            begin
                exmem_write_value = idex_pc + 64'h4;
                exmem_write_index = 31;
                branch_counter = { idex_pc[63:28], idex_pc[25:0], 2'b00 };
                branch_enable = 1'b1;
            end
        6'b100000, // LB
        6'b100100: // LBU
            begin
                exmem_mem_format = 2'h0; // 1 byte
                exmem_mem_signed = ~opcode[2];
            end
        6'b100001, // LH
        6'b100101: // LHU
            begin
                exmem_mem_format = 2'h1; // 2 bytes
                exmem_mem_signed = ~opcode[2];
            end
        6'b100011, // LW
        6'b100111: // LWU
            begin
                exmem_mem_format = 2'h2; // 4 bytes
                exmem_mem_signed = ~opcode[2];
            end
        6'b110111: // LD
            begin
                exmem_mem_format = 2'h3; // 8 bytes
                exmem_mem_signed = 1'b1;
            end
        6'b101000, // SB
            begin
                exmem_mem_format = 2'h0; // 1 byte
                exmem_mem_signed = ~opcode[2];
            end
        6'b101001, // SH
            begin
                exmem_mem_format = 2'h1; // 2 bytes
                exmem_mem_signed = ~opcode[2];
            end
        6'b101011, // SW
            begin
                exmem_mem_format = 2'h2; // 4 bytes
                exmem_mem_signed = ~opcode[2];
            end
        6'b111111, // SD
            begin
                exmem_mem_format = 2'h3; // 8 bytes
                exmem_mem_signed = ~opcode[2];
            end
        endcase

        if (opcode[5:3] == 3'b100 || opcode == 6'b110111) 
        begin
            exmem_mem_addr      = idex_addr;
            exmem_mem_read      = 1'b1;
            exmem_write_index   = rt;
        end
        else if (opcode[5:3] == 3'b101 || opcode == 6'b111111) 
        begin
            exmem_mem_addr      = idex_addr;
            exmem_mem_write     = 1'b1;
            exmem_write_value = idex_rt_value;
        end
    end

    // MEM stage
    always @(posedge clk) 
    begin
        reg [63:0] load_data;
        reg [63:0] store_data;
        reg [7:0]  store_mask;

        if (exmem_mem_read) 
        begin
            case (exmem_mem_format)
                2'd0: 
                    load_data <= exmem_mem_signed ?
                        { {56{data_in[7]}},  data_in[7:0] } :
                        { 56'd0, data_in[7:0] };
                2'd1: 
                    load_data <= exmem_mem_signed ?
                        { {48{data_in[15]}}, data_in[15:0] } :
                        { 48'd0, data_in[15:0] };
                2'd2: 
                    load_data <= exmem_mem_signed ?
                        { {32{data_in[31]}}, data_in[31:0] } :
                        { 32'd0, data_in[31:0] };
                2'd3: 
                    load_data <= data_in;
                default:
                    load_data <= data_in;
            endcase

            memwb_write_value <= load_data;
        end
        else 
        begin
            memwb_write_value <= exmem_write_value;
        end

        memwb_write_index <= exmem_write_index;

        if (exmem_mem_write) 
        begin
            case (exmem_mem_format)
            2'd0: 
                begin // SB
                    store_data <= {56'd0, exmem_write_value[7:0]};
                    store_mask <= 8'b00000001;
                end
            2'd1: 
                begin // SH
                    store_data <= {48'd0, exmem_write_value[15:0]};
                    store_mask <= 8'b00000011;
                end
            2'd2: 
                begin // SW
                    store_data <= {32'd0, exmem_write_value[31:0]};
                    store_mask <= 8'b00001111;
                end
            2'd3: 
                begin // SD
                    store_data <= exmem_write_value;
                    store_mask <= 8'b11111111;
                end
            default: 
                begin
                    store_data <= exmem_write_value;
                    store_mask <= 8'b11111111;
                end
            endcase

            data_out   <= store_data;
            data_mask  <= store_mask;
            data_write <= 1'b1;
        end
        else 
        begin
            data_out   <= 64'd0;
            data_mask  <= 8'd0;
            data_write <= 1'b0;
        end
    end


    // WB stage
    always @(posedge clk)
    begin
        if (memwb_write_index != 5'd0)
            registers[memwb_write_index] <= memwb_write_value;
    end

    assign data_address = exmem_mem_addr;
    assign data_out     = exmem_mem_data;
    assign data_read    = exmem_mem_read;
    assign data_write   = exmem_mem_write;
    assign data_mask    = exmem_mem_mask;

    assign instr_address = prog_counter;
    assign instr_read    = 1'b1;

endmodule
