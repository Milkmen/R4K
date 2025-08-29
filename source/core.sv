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

    reg [63:0] registers [31:0];
    reg [63:0] hi;
    reg [63:0] lo;

    reg [63:0] prog_counter;
    reg [63:0] branch_counter;
    reg branch_enable;
    reg [31:0] instruction;

    wire [5:0]  opcode  = instruction[31:26];
    wire [4:0]  rs      = instruction[25:21];
    wire [4:0]  rt      = instruction[20:16];
    wire [4:0]  rd      = instruction[15:11];
    wire [4:0]  sa      = instruction[10:6];
    wire [5:0]  funct   = instruction[5:0];
    wire [25:0] addr    = instruction[25:0];
    wire [15:0] offset  = instruction[15:0];

    wire [63:0] imm_se = { { 48 { offset[15] } }, offset };
    wire [63:0] imm_ze = { 48'd0, offset} ; 

    reg [63:0] rs_value;
    reg [63:0] rt_value;
    reg [63:0] rd_value;
    reg [63:0] write_value;
    reg [4:0]  write_index;

    // Instruction Decode
    always @(*)
    begin
        write_value = 64'd0;
        write_index = 5'd0;

        case(opcode)
        6'b000000:
            case(funct)
            6'b100000: // ADD rd, rs, rt
                begin 
                    write_value = $signed(rs_value) + $signed(rt_value);
                    write_index = rd;
                end

            6'b100001: // ADDU rd, rs, rt
                begin 
                    write_value = rs_value + rt_value;
                    write_index = rd;
                end

            6'b100010: // SUB rd, rs, rt
                begin 
                    write_value = $signed(rs_value) - $signed(rt_value);
                    write_index = rd;
                end

            6'b100011: // SUBU rd, rs, rt
                begin 
                    write_value = rs_value - rt_value;
                    write_index = rd;
                end
                
            6'b011000: // MULT rs, rt
                begin 
                    {hi, lo} = $signed(rs_value) * $signed(rt_value);
                end

            6'b011001: // MULTU rs, rt
                begin 
                    {hi, lo} = rs_value * rt_value;
                end

            6'b011010: // DIV rs, rt
                begin
                    lo = $signed(rs_value) / $signed(rt_value);
                    hi = $signed(rs_value) % $signed(rt_value);
                end

            6'b011011: // DIVU rs, rt
                begin 
                    lo = rs_value / rt_value;
                    hi = rs_value % rt_value;
                end

            6'b100100: // AND rd, rs, rt
                begin 
                    write_value = rs_value & rt_value;
                    write_index = rd;
                end

            6'b100101: // OR rd, rs, rt
                begin 
                    write_value = rs_value | rt_value;
                    write_index = rd;
                end

            6'b100110: // XOR rd, rs, rt
                begin 
                    write_value = rs_value ^ rt_value;
                    write_index = rd;
                end

            6'b100111: // NOR rd, rs, rt
                begin 
                    write_value = ~(rs_value | rt_value);
                    write_index = rd;
                end

            6'b000000: // SLL rd, rt, sa
                begin
                    write_value = rt_value << sa;
                    write_index = rd;
                end

            6'b000100: // SLLV rd, rt, rs
                begin
                    write_value = rt_value << rs_value[4:0];
                    write_index = rd;
                end

            6'b000010: // SRL rd, rt, sa
                begin
                    write_value = rt_value >> sa;
                    write_index = rd;
                end

            6'b000110: // SRLV rd, rt, rs
                begin
                    write_value = rt_value >> rs_value[4:0];
                    write_index = rd;
                end

            6'b000011: // SRA rd, rt, sa
                begin
                    write_value = $signed(rt_value) >> sa;
                    write_index = rd;
                end

            6'b000111: // SRAV rd, rt, rs
                begin
                    write_value = $signed(rt_value) >> rs_value[4:0];
                    write_index = rd;
                end

            6'b101010: // SLT rd, rs, rt
                begin
                    if($signed(rs_value) < $signed(rt_value))
                        write_value = 64'h1;
                    else
                        write_value = 64'h0;

                    write_index = rd;
                end

            6'b101011: // SLTU rd, rs, rt
                begin
                    if(rs_value < rt_value)
                        write_value = 64'h1;
                    else
                        write_value = 64'h0;

                    write_index = rd;
                end

            6'b010001: // MFHI rs
                begin
                    write_value = hi;
                    write_index = rd;
                end

            6'b010011: // MFLO rs
                begin
                    write_value = lo;
                    write_index = rd;
                end

            6'b010001: // MTHI rs
                begin
                    hi = rs_value;
                end

            6'b010011: // MTLO rs
                begin
                    lo = rs_value;
                end

            6'b001000: // JR rs
                begin
                    branch_counter = rs_value;
                    branch_enable = 1'b1;
                end

            6'b001001: // JALR rd, rs
                begin
                    write_value = prog_counter + 64'h4;
                    write_index = rd;

                    branch_counter = rs_value;
                    branch_enable = 1'b1;
                end

            endcase

        6'b001000: // ADDI rt, rs, immediate
            begin
                write_value = $signed(rs_value) + $signed(imm_se);
                write_index = rt;
            end

        6'b001001: // ADDIU rt, rs, immediate
            begin
                write_value = rs_value + imm_se;
                write_index = rt;
            end

        6'b001100: // ANDI rt, rs, immediate
            begin
                write_value = rs_value & imm_ze;
                write_index = rt;
            end

        6'b101000: // ORI rt, rs, immediate
            begin
                write_value = rs_value | imm_ze;
                write_index = rt;
            end

        6'b001110: // XORI rt, rs, immediate
            begin
                write_value = rs_value ^ imm_ze;
                write_index = rt;
            end

        6'b001111: // LUI rt, immediate
            begin
                write_value = { imm_ze[15:0], 48'd0 };
                write_index = rt;
            end

        6'b001010: // SLTI rt, rs, immediate
            begin
                if($signed(rs_value) < $signed(imm_se))
                    write_value = 64'h1;
                else
                    write_value = 64'h0;

                write_index = rt;
            end

        6'b001011: // SLTIU rt, rs, immediate
            begin
                if(rs_value < imm_se)
                    write_value = 64'h1;
                else
                    write_value = 64'h0;

                write_index = rt;
            end

        6'b000010: // J target
            begin
                branch_counter = {prog_counter[63:28], addr, 2'b00};
                branch_enable = 1'b1;
            end

        6'b000011: // JAL target
            begin
                write_value = prog_counter + 64'h4;
                write_index = 31;

                branch_counter = {prog_counter[63:28], addr, 2'b00};
                branch_enable = 1'b1;
            end
        
        endcase
    end

    // Clocked logic
    always @(posedge clk or posedge reset)
    begin
        if(!reset)
        begin
            // Continue Execution
            if(!branch_enable)
            begin
                prog_counter <= prog_counter + 64'h4;
            end
            else
            begin
                prog_counter <= branch_counter;
                branch_enable <= 1'b0;
            end

            instruction <= instr_in;

            rs_value <= registers[rs];
            rt_value <= registers[rt];
            rd_value <= registers[rd];

            if (write_index != 5'd0)
                registers[write_index] <= write_value;
        end
        else
        begin
            // Reset
            prog_counter <= START_ADDR;
            branch_enable <= 1'b0;
        end
    end

    assign instr_address = prog_counter;
    assign instr_read    = 1'b1;

endmodule