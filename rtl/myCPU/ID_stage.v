`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,

    // delay slot
    output                          ds_is_branch,
    
    // forword & block from es
    input  [`ES_FWD_BLK_BUS_WD -1:0] es_fwd_blk_bus,
    // forword & block from ms
    input  [`MS_FWD_BLK_BUS_WD -1:0] ms_fwd_blk_bus, 

    //block
    input                           es_inst_mfc0  ,
    input                           ms_inst_mfc0  ,
    input                           ws_inst_mfc0  ,
    input [4:0]                     ws_rf_dest    ,

    //exception
    input                           ws_eret    ,
    input                           ws_ex         ,

    input  [31:0]                   cp0_status    ,
    input  [31:0]                   cp0_cause     
);

reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] fs_to_ds_badvaddr;
wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
wire        ds_ex;
wire        ds_bd;
wire [31:0] ds_badvaddr;
wire [ 4:0] ds_excode;
assign {
    fs_to_ds_ex,
    ds_bd,
    ds_badvaddr,
    ds_inst,
    ds_pc
} = fs_to_ds_bus_r;

wire [ 3:0] rf_we;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {
    rf_we   ,  //40:37
    rf_waddr,  //36:32
    rf_wdata   //31:0
} = ws_to_rf_bus;

// forward & block

wire [ 3:0] es_fwd_valid;
wire [ 4:0] es_rf_dest;
wire [31:0] es_rf_data;
wire        es_blk_valid;
wire        es_res_from_mem;
assign {
    es_fwd_valid,   // 41:38
    es_rf_dest,     // 37:33
    es_rf_data,     // 32:1
    es_blk_valid    // 0:0
} = es_fwd_blk_bus;

wire [ 3:0] ms_fwd_valid;
wire [ 4:0] ms_rf_dest;
wire [31:0] ms_rf_data;
assign {
    ms_fwd_valid,   // 40:37
    ms_rf_dest,     // 36:32
    ms_rf_data      // 31:0
} = ms_fwd_blk_bus;

wire        br_stall;
wire        br_taken;
wire [31:0] br_target;

wire [11:0] alu_op;
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_uimm;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

// 
wire        inst_add;
wire        inst_addi;
wire        inst_addu;
wire        inst_addiu;
wire        inst_sub;
wire        inst_subu;
wire        inst_slt;
wire        inst_slti;
wire        inst_sltu;
wire        inst_sltiu;
wire        inst_div;
wire        inst_divu;
wire        inst_mult;
wire        inst_multu;
wire        inst_lui;

// logic inst
wire        inst_and;
wire        inst_andi;
wire        inst_nor;
wire        inst_or;
wire        inst_ori;
wire        inst_xor;
wire        inst_xori;

// shift inst
wire        inst_sllv;
wire        inst_sll;
wire        inst_srav;
wire        inst_sra;
wire        inst_srlv;
wire        inst_srl;

// branch & jump inst
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;

// branch & jump in lab7
wire        inst_bgez;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_j;
wire        inst_bltzal;
wire        inst_bgezal;
wire        inst_jalr;      

// data move inst
wire        inst_mfhi;
wire        inst_mthi;
wire        inst_mflo;
wire        inst_mtlo;

// memory & inst
wire        inst_lw;
wire        inst_sw;

// memory & inst in lab7
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_lwl;
wire        inst_lwr;
wire        inst_sb;
wire        inst_sh;
wire        inst_swl;
wire        inst_swr;

wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;

wire overflow_inst;

wire [7:0] cp0_addr;

assign br_bus = {
    br_stall,
    br_taken,
    br_target
};

assign ds_to_es_bus = {
    fs_to_ds_ex ,  //209:209
    overflow_inst, //208:208
    ds_excode   ,  //207:203
    ds_badvaddr ,  //202:171
    cp0_addr    ,  //170:163
    ds_ex       ,  //162:162
    ds_bd       ,  //161:161
    inst_eret   ,  //160:160
    inst_syscall,  //159:159
    inst_mfc0   ,  //158:158
    inst_mtc0   ,  //157:157
    inst_lb     ,  //156:156
    inst_lbu    ,  //155:155
    inst_lh     ,  //154:154
    inst_lhu    ,  //153:153
    inst_lw     ,  //152:152
    inst_lwl    ,  //151:151
    inst_lwr    ,  //150:150
    inst_sb     ,  //149:149
    inst_sh     ,  //148:148
    inst_sw     ,  //147:147
    inst_swl    ,  //146:146
    inst_swr    ,  //145:145
    inst_div    ,  //144:144
    inst_divu   ,  //143:143
    inst_mult   ,  //142:142
    inst_multu  ,  //141:141
    inst_mthi   ,  //140:140
    inst_mfhi   ,  //139:139
    inst_mtlo   ,  //138:138
    inst_mflo   ,  //137:137
    alu_op      ,  //136:125
    load_op     ,  //124:124
    src1_is_sa  ,  //123:123
    src1_is_pc  ,  //122:122
    src2_is_imm ,  //121:122
    src2_is_uimm,  //120:120
    src2_is_8   ,  //119:119
    gr_we       ,  //118:118
    mem_we      ,  //117:117
    dest        ,  //116:112
    imm         ,  //111:96
    rs_value    ,  //95 :64
    rt_value    ,  //63 :32
    ds_pc          //31 :0
};

//assign ds_ex = (inst_syscall)? 1 : 0;

wire    mfc0_block;
assign mfc0_block = (es_inst_mfc0 && (es_rf_dest == rs || es_rf_dest == rt)) ||
                    (ms_inst_mfc0 && (ms_rf_dest == rs || ms_rf_dest == rt)) ||
                    (ws_inst_mfc0 && (ws_rf_dest == rs || ws_rf_dest == rt));

assign ds_ready_go    = !(
   mfc0_block || (es_blk_valid  && (es_rf_dest == rs || es_rf_dest == rt))
);

assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go && !ws_eret && !ws_ex;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];
assign cp0_addr = {ds_inst[15:11], ds_inst[2:0]};

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

// arithmetic inst
assign inst_add     = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addi    = op_d[6'h08];
assign inst_addu    = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_addiu   = op_d[6'h09];
assign inst_sub     = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_subu    = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt     = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_slti    = op_d[6'h0a];
assign inst_sltu    = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_sltiu   = op_d[6'h0b];
assign inst_lui     = op_d[6'h0f] & rs_d[5'h00];
assign inst_div     = op_d[6'h00] & func_d[6'h1a] & rd_d[5'h00] & sa_d[5'h00];
assign inst_divu    = op_d[6'h00] & func_d[6'h1b] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mult    = op_d[6'h00] & func_d[6'h18] & rd_d[5'h00] & sa_d[5'h00];
assign inst_multu   = op_d[6'h00] & func_d[6'h19] & rd_d[5'h00] & sa_d[5'h00];

// logic inst
assign inst_and     = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_andi    = op_d[6'h0c];
assign inst_nor     = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_or      = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_ori     = op_d[6'h0d];
assign inst_xor     = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_xori    = op_d[6'h0e];

// shift inst
assign inst_sllv    = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_sll     = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srav    = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_sra     = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_srlv    = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_srl     = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];

// branch & jump inst
assign inst_beq     = op_d[6'h04];
assign inst_bne     = op_d[6'h05];
assign inst_jal     = op_d[6'h03];
assign inst_jr      = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];

// branch & hump in lab7
assign inst_bgez    = op_d[6'h01] & rt_d[5'h01];
assign inst_bgtz    = op_d[6'h07] & rt_d[5'h00];
assign inst_blez    = op_d[6'h06] & rt_d[5'h00];
assign inst_bltz    = op_d[6'h01] & rt_d[5'h00];
assign inst_j       = op_d[6'h02];
assign inst_bltzal  = op_d[6'h01] & rt_d[5'h10];
assign inst_bgezal  = op_d[6'b01] & rt_d[5'h11];
assign inst_jalr    = op_d[6'h00] & rt_d[5'h00] & func_d[6'h09];

// data move inst
assign inst_mfhi    = op_d[6'h00] & func_d[6'h10] & rs_d[5'h00] & rt_d[5'h00];
assign inst_mthi    = op_d[6'h00] & func_d[6'h11] & rt_d[5'h00] & rd_d[5'h00];
assign inst_mflo    = op_d[6'h00] & func_d[6'h12] & rs_d[5'h00] & rt_d[5'h00];
assign inst_mtlo    = op_d[6'h00] & func_d[6'h13] & rt_d[5'h00] & rd_d[5'h00];

// memory & inst
assign inst_lw      = op_d[6'h23];
assign inst_sw      = op_d[6'h2b];

// memory & inst in lab7
assign inst_lb      = op_d[6'h20];
assign inst_lbu     = op_d[6'h24];
assign inst_lh      = op_d[6'h21];
assign inst_lhu     = op_d[6'h25];
assign inst_lwl     = op_d[6'h22];
assign inst_lwr     = op_d[6'h26];
assign inst_sb      = op_d[6'h28];
assign inst_sh      = op_d[6'h29];
assign inst_swl     = op_d[6'h2a];
assign inst_swr     = op_d[6'h2e];

//new inst in lab8
assign inst_syscall = op_d[6'h00] & func_d[6'h0c];
assign inst_eret    = op_d[6'h10] & rs_d[5'h10] & func_d[6'h18] & rd_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mfc0    = op_d[6'h10] & rs_d[5'h00] & sa_d[5'h00] & (ds_inst[5:3] == 3'b0);
assign inst_mtc0    = op_d[6'h10] & rs_d[5'h04] & sa_d[5'h00] & (ds_inst[5:3] == 3'b0);

//new inst in lab9
assign inst_break   = op_d[6'h00] & func_d[6'h0d];




assign alu_op[ 0] = inst_add | inst_addi | inst_addu | inst_addiu | inst_lw | inst_sw | inst_jal | inst_bltzal |
                    inst_bgezal | inst_jalr | inst_lb | inst_lbu |inst_lh | inst_lhu | inst_lwl | inst_lwr | inst_sb |
                    inst_sh | inst_swl | inst_swr;
assign alu_op[ 1] = inst_sub | inst_subu;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_sllv | inst_sll;
assign alu_op[ 9] = inst_srlv | inst_srl;
assign alu_op[10] = inst_srav | inst_sra;
assign alu_op[11] = inst_lui;

assign load_op = inst_lw | inst_lh | inst_lhu | inst_lb | inst_lbu | inst_lwl | inst_lwr;


assign src1_is_sa   = inst_sll | inst_srl | inst_sra;
assign src1_is_pc   = inst_jal | inst_jalr | inst_bltzal | inst_bgezal;

assign src2_is_imm  = inst_addi | inst_addiu | inst_slti | inst_sltiu | inst_lui | inst_lw | inst_sw |
                      inst_lh | inst_lhu | inst_lb | inst_lbu | inst_lwl | inst_lwr |
                      inst_sh | inst_sb | inst_swl | inst_swr;
assign src2_is_uimm = inst_andi | inst_ori | inst_xori;
assign src2_is_8    = inst_jal | inst_jalr | inst_bltzal | inst_bgezal;

assign res_from_mem = inst_lw | inst_lh | inst_lhu | inst_lb | inst_lbu | inst_lwl | inst_lwr;

assign dst_is_r31   = inst_jal | inst_bgezal | inst_bltzal;
assign dst_is_rt    = inst_addi | inst_addiu | inst_slti | inst_sltiu | inst_lui | inst_andi | inst_ori | 
                      inst_xori | inst_lw | inst_lh | inst_lhu | inst_lb | inst_lbu | inst_lwl | inst_lwr | inst_mfc0;

assign gr_we        = ~inst_sw & ~inst_beq & ~inst_bne & ~inst_jr & 
                      ~inst_mtlo & ~inst_mthi & ~inst_div & ~inst_divu & ~inst_mult & ~inst_multu &
                      ~inst_bgez & ~inst_bgtz & ~inst_blez & ~inst_bltz & ~inst_j & ~inst_sb & ~inst_sh & ~inst_swl & ~inst_swr &
                      ~inst_mtc0 & ~inst_syscall & ~inst_eret & ~inst_break;
assign mem_we       = inst_sw | inst_sh | inst_sb | inst_swl | inst_swr;

assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    : 
                                   rd;
assign overflow_inst = inst_add || inst_sub || inst_addi;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rs_value[ 7: 0] = 
    (es_fwd_valid[0] && es_rf_dest == rs)? es_rf_data[ 7: 0] :
    (ms_fwd_valid[0] && ms_rf_dest == rs)? ms_rf_data[ 7: 0] :
    (rf_we       [0] && rf_waddr   == rs)? rf_wdata  [ 7: 0] :
    rf_rdata1  [ 7: 0];
assign rs_value[15: 8] = 
    (es_fwd_valid[1] && es_rf_dest == rs)? es_rf_data[15: 8] :
    (ms_fwd_valid[1] && ms_rf_dest == rs)? ms_rf_data[15: 8] :
    (rf_we       [1] && rf_waddr   == rs)? rf_wdata  [15: 8] :
    rf_rdata1  [15: 8];
assign rs_value[23:16] = 
    (es_fwd_valid[2] && es_rf_dest == rs)? es_rf_data[23:16] :
    (ms_fwd_valid[2] && ms_rf_dest == rs)? ms_rf_data[23:16] :
    (rf_we       [2] && rf_waddr   == rs)? rf_wdata  [23:16] :
    rf_rdata1  [23:16];
assign rs_value[31:24] = 
    (es_fwd_valid[3] && es_rf_dest == rs)? es_rf_data[31:24] :
    (ms_fwd_valid[3] && ms_rf_dest == rs)? ms_rf_data[31:24] :
    (rf_we       [3] && rf_waddr   == rs)? rf_wdata  [31:24] :
    rf_rdata1  [31:24];


assign rt_value[ 7: 0] = 
    (es_fwd_valid[0] && es_rf_dest == rt)? es_rf_data[ 7: 0] :
    (ms_fwd_valid[0] && ms_rf_dest == rt)? ms_rf_data[ 7: 0] :
    (rf_we       [0] && rf_waddr   == rt)? rf_wdata  [ 7: 0] :
    rf_rdata2  [ 7: 0];
assign rt_value[15: 8] = 
    (es_fwd_valid[1] && es_rf_dest == rt)? es_rf_data[15: 8] :
    (ms_fwd_valid[1] && ms_rf_dest == rt)? ms_rf_data[15: 8] :
    (rf_we       [1] && rf_waddr   == rt)? rf_wdata  [15: 8] :
    rf_rdata2  [15: 8];
assign rt_value[23:16] = 
    (es_fwd_valid[2] && es_rf_dest == rt)? es_rf_data[23:16] :
    (ms_fwd_valid[2] && ms_rf_dest == rt)? ms_rf_data[23:16] :
    (rf_we       [2] && rf_waddr   == rt)? rf_wdata  [23:16] :
    rf_rdata2  [23:16];
assign rt_value[31:24] = 
    (es_fwd_valid[3] && es_rf_dest == rt)? es_rf_data[31:24] :
    (ms_fwd_valid[3] && ms_rf_dest == rt)? ms_rf_data[31:24] :
    (rf_we       [3] && rf_waddr   == rt)? rf_wdata  [31:24] :
    rf_rdata2  [31:24];

// TODO:
assign br_stall = 1'b0;
assign ds_is_branch = (inst_beq || inst_bne || inst_jal || inst_jr || inst_bgez || inst_bgtz || inst_blez || inst_bltz || inst_bgezal || inst_bltzal || inst_j || inst_jalr) && ds_valid;

wire judge_bgez;
wire judge_bgtz;

assign judge_bgez = ~rs_value[31];                          //  >=0
assign judge_bgtz = (rs_value != 32'b0) & (~rs_value[31]);  //  > 0

assign rs_eq_rt = (rs_value == rt_value);
assign br_taken = (
    inst_beq  &&  rs_eq_rt        ||
    inst_bne  && !rs_eq_rt        ||
    inst_jal                      ||
    inst_jr                       ||
    inst_bgez && judge_bgez       ||
    inst_bgtz && judge_bgtz       ||
    inst_blez && (~judge_bgtz)    ||
    inst_bltz && (~judge_bgez)    ||
    inst_bgezal && judge_bgez     ||
    inst_bltzal && (~judge_bgez)  ||
    inst_j                        ||
    inst_jalr
) && ds_valid;

//assign ds_bd = br_taken;

assign br_target = (inst_beq || inst_bne || inst_bgez || inst_bgtz || inst_blez || inst_bltz || inst_bgezal || inst_bltzal) ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr || inst_jalr)              ? rs_value :
                  /*inst_jal*/              {fs_pc[31:28], jidx[25:0], 2'b0};


//lab9
wire other_inst;
assign other_inst = !(inst_addu | inst_subu | inst_slt | inst_sltu | inst_and | inst_or | inst_xor | inst_nor
| inst_sll | inst_srl | inst_sra | inst_addiu | inst_lui | inst_lw | inst_sw | inst_beq | inst_bne | inst_jal
| inst_jr | inst_add | inst_addi | inst_sub | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori | inst_sllv
| inst_srlv | inst_srav | inst_mult | inst_multu | inst_div | inst_divu | inst_mfhi | inst_mflo | inst_mthi | inst_mtlo
| inst_bgez | inst_bgtz | inst_blez | inst_bltz | inst_j | inst_bltzal | inst_bgezal | inst_jalr | inst_lb | inst_lbu
| inst_lh | inst_lhu | inst_lwl | inst_lwr | inst_sb | inst_sh | inst_swl | inst_swr | inst_syscall | inst_eret | inst_mfc0
| inst_mtc0 | inst_break);

wire interrupt;

assign interrupt = ((cp0_cause[15:8] & cp0_status[15:8]) != 8'b0) && (cp0_status[1:0] == 2'b01);


assign ds_ex = (fs_to_ds_ex | inst_syscall | inst_break | other_inst | interrupt) & ds_valid;

assign ds_excode = (interrupt) ? `EX_INT :
                   (fs_to_ds_ex) ? `EX_ADEL :
                   (other_inst) ? `EX_RI :
                   (inst_syscall) ? `EX_SYS :
                   (inst_break) ? `EX_BP : `EX_NO;

endmodule
