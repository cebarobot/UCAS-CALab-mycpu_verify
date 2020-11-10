`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,

    //block
    output                          es_inst_mfc0_o ,

    // forword & block from es
    output [`ES_FWD_BLK_BUS_WD -1:0] es_fwd_blk_bus,    

    //exception
    input                           ws_ex        ,
    input                           ms_ex        ,
    input                           ms_eret      ,
    input                           ws_eret
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [31:0] reg_LO;
reg  [31:0] reg_HI;
wire        reg_LO_we;
wire        reg_HI_we;
wire [31:0] reg_LO_wdata;
wire [31:0] reg_HI_wdata;
wire [31:0] reg_LO_rdata;
wire [31:0] reg_HI_rdata;
wire [7:0]  es_cp0_addr;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire        es_inst_lb     ;
wire        es_inst_lbu    ;
wire        es_inst_lh     ;
wire        es_inst_lhu    ;
wire        es_inst_lw     ;
wire        es_inst_lwl    ;
wire        es_inst_lwr    ;
wire        es_inst_sb     ;
wire        es_inst_sh     ;
wire        es_inst_sw     ;
wire        es_inst_swl    ;
wire        es_inst_swr    ;
wire        es_inst_div    ;
wire        es_inst_divu   ;
wire        es_inst_mult   ;
wire        es_inst_multu  ;
wire        es_inst_mfhi   ;
wire        es_inst_mthi   ;
wire        es_inst_mflo   ;
wire        es_inst_mtlo   ;
wire [11:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;

wire [4:0] es_excode;
wire [31:0] es_badvaddr;

wire    es_ex;
wire    es_bd;
wire    es_inst_eret;
wire    es_inst_syscall;  
wire    es_inst_mfc0;
wire    es_inst_mtc0;
wire    no_store;  
assign no_store = ms_ex | ws_ex | es_ex | ms_eret | ws_eret;
// assign no_store = ms_ex | ws_ex | es_ex;

wire [4:0] ds_to_es_excode;
wire [31:0] ds_to_es_badvaddr;


assign {
    fs_to_ds_ex  ,    //209:209
    overflow_inst,    //208:208
    ds_to_es_excode,  //207:203
    ds_to_es_badvaddr, //202:171
    es_cp0_addr    ,  //170:163
    ds_to_es_ex          ,  //162:162
    ds_to_es_bd          ,  //161:161
    es_inst_eret   ,  //160:160
    es_inst_syscall,  //159:159
    es_inst_mfc0   ,  //158:158
    es_inst_mtc0   ,  //157:157
    es_inst_lb     ,  //156:156
    es_inst_lbu    ,  //155:155
    es_inst_lh     ,  //154:154
    es_inst_lhu    ,  //153:153
    es_inst_lw     ,  //152:152
    es_inst_lwl    ,  //151:151
    es_inst_lwr    ,  //150:150
    es_inst_sb     ,  //149:149
    es_inst_sh     ,  //148:148
    es_inst_sw     ,  //147:147
    es_inst_swl    ,  //146:146
    es_inst_swr    ,  //145:145
    es_inst_div    ,  //144:144
    es_inst_divu   ,  //143:143
    es_inst_mult   ,  //142:142
    es_inst_multu  ,  //141:141
    es_inst_mthi   ,  //140:140
    es_inst_mfhi   ,  //139:139
    es_inst_mtlo   ,  //138:138
    es_inst_mflo   ,  //137:137
    es_alu_op      ,  //136:125
    es_load_op     ,  //124:124
    es_src1_is_sa  ,  //123:123
    es_src1_is_pc  ,  //122:122
    es_src2_is_imm ,  //121:121
    es_src2_is_uimm , //120:120
    es_src2_is_8   ,  //119:119
    es_gr_we       ,  //118:118
    es_mem_we      ,  //117:117
    es_dest        ,  //116:112
    es_imm         ,  //111:96
    es_rs_value    ,  //95 :64
    es_rt_value    ,  //63 :32
    es_pc             //31 :0
} = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_exe_result;

wire    es_res_from_mem;

assign es_res_from_mem  = es_load_op;
assign es_res_from_LO   = es_inst_mflo;
assign es_res_from_HI   = es_inst_mfhi;

assign es_exe_result = 
    es_res_from_LO  ? reg_LO_rdata  :
    es_res_from_HI  ? reg_HI_rdata  :
    es_inst_mtc0    ? es_rt_value   :
    es_alu_result;

assign es_to_ms_bus = {
    es_excode       ,  //128:124
    es_badvaddr     ,  //123:92
    es_cp0_addr     ,  //91:84
    es_ex           ,  //83:83
    es_bd           ,  //82:82
    es_inst_eret    ,  //81:81
    es_inst_syscall ,  //80:80
    es_inst_mfc0    ,  //79:79
    es_inst_mtc0    ,  //78:78
    es_inst_lb      ,  //77:77
    es_inst_lbu     ,  //76:76
    es_inst_lh      ,  //75:75
    es_inst_lhu     ,  //74:74
    es_inst_lw      ,  //73:73
    es_inst_lwl     ,  //72:72
    es_inst_lwr     ,  //71:71
    es_res_from_mem ,  //70:70
    es_gr_we        ,  //69:69
    es_dest         ,  //68:64
    es_exe_result   ,  //63:32
    es_pc              //31:0
};

wire [ 3:0] es_fwd_valid;
wire [ 4:0] es_rf_dest;
wire [31:0] es_rf_data;
wire        es_blk_valid;

assign es_fwd_blk_bus = {
    es_fwd_valid,   // 41:38
    es_rf_dest,     // 37:33
    es_rf_data,     // 32:1
    es_blk_valid    // 0:0
};

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm  ? {{16{es_imm[15]}}, es_imm[15:0]} : 
                     es_src2_is_uimm ? {{16{1'b0      }}, es_imm[15:0]} :
                     es_src2_is_8    ? 32'd8 :
                                      es_rt_value;

wire overflow;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .overflow   (overflow)
    );

// Mult & Multu
wire [31:0] mult_src1;
wire [31:0] mult_src2;
wire [63:0] unsigned_mult_res;
wire [63:0] signed_mult_res;

assign mult_src1 = es_rs_value;
assign mult_src2 = es_rt_value;

assign unsigned_mult_res = mult_src1 * mult_src2;
assign signed_mult_res   = $signed(mult_src1) * $signed(mult_src2);

// Div & Divu
wire [31:0] divider_dividend;
wire [31:0] divider_divisor;
wire [63:0] unsigned_divider_res;
wire [63:0] signed_divider_res;

assign divider_dividend = es_rs_value;
assign divider_divisor  = es_rt_value;

wire unsigned_dividend_tready;
wire unsigned_dividend_tvalid;
wire unsigned_divisor_tready;
wire unsigned_divisor_tvalid;
wire unsigned_dout_tvalid;

wire signed_dividend_tready;
wire signed_dividend_tvalid;
wire signed_divisor_tready;
wire signed_divisor_tvalid;
wire signed_dout_tvalid;

unsigned_divider u_unsigned_divider (
    .aclk                   (clk),
    .s_axis_dividend_tdata  (divider_dividend),
    .s_axis_dividend_tready (unsigned_dividend_tready),
    .s_axis_dividend_tvalid (unsigned_dividend_tvalid),
    .s_axis_divisor_tdata   (divider_divisor),
    .s_axis_divisor_tready  (unsigned_divisor_tready),
    .s_axis_divisor_tvalid  (unsigned_divisor_tvalid),
    .m_axis_dout_tdata      (unsigned_divider_res),
    .m_axis_dout_tvalid     (unsigned_dout_tvalid)
);

signed_divider u_signed_divider (
    .aclk                   (clk),
    .s_axis_dividend_tdata  (divider_dividend),
    .s_axis_dividend_tready (signed_dividend_tready),
    .s_axis_dividend_tvalid (signed_dividend_tvalid),
    .s_axis_divisor_tdata   (divider_divisor),
    .s_axis_divisor_tready  (signed_divisor_tready),
    .s_axis_divisor_tvalid  (signed_divisor_tvalid),
    .m_axis_dout_tdata      (signed_divider_res),
    .m_axis_dout_tvalid     (signed_dout_tvalid)
);

// Divider status control
reg  unsigned_dividend_sent;
reg  unsigned_divisor_sent;
reg  unsigned_divider_done;

assign unsigned_dividend_tvalid = es_valid && es_inst_divu && !unsigned_dividend_sent;
assign unsigned_divisor_tvalid = es_valid && es_inst_divu && !unsigned_divisor_sent;

always @ (posedge clk) begin
    if (reset) begin
        unsigned_dividend_sent <= 1'b0;
    end else if (unsigned_dividend_tready && unsigned_dividend_tvalid) begin
        unsigned_dividend_sent <= 1'b1;
    end else if (es_ready_go && ms_allowin) begin
        unsigned_dividend_sent <= 1'b0;
    end
    
    if (reset) begin
        unsigned_divisor_sent <= 1'b0;
    end else if (unsigned_divisor_tready && unsigned_divisor_tvalid) begin
        unsigned_divisor_sent <= 1'b1;
    end else if (es_ready_go && ms_allowin) begin
        unsigned_divisor_sent <= 1'b0;
    end

    if (reset) begin
        unsigned_divider_done <= 1'b0;
    end else if (es_ready_go && !ms_allowin) begin
        unsigned_divider_done <= 1'b1;
    end else if (ms_allowin) begin
        unsigned_divider_done <= 1'b0;
    end
end

reg  signed_dividend_sent;
reg  signed_divisor_sent;
reg  signed_divider_done;

assign signed_dividend_tvalid = es_valid && es_inst_div && !signed_dividend_sent;
assign signed_divisor_tvalid = es_valid && es_inst_div && !signed_divisor_sent;

always @ (posedge clk) begin
    if (reset) begin
        signed_dividend_sent <= 1'b0;
    end else if (signed_dividend_tready && signed_dividend_tvalid) begin
        signed_dividend_sent <= 1'b1;
    end else if (es_ready_go && ms_allowin) begin
        signed_dividend_sent <= 1'b0;
    end
    
    if (reset) begin
        signed_divisor_sent <= 1'b0;
    end else if (signed_divisor_tready && signed_divisor_tvalid) begin
        signed_divisor_sent <= 1'b1;
    end else if (es_ready_go && ms_allowin) begin
        signed_divisor_sent <= 1'b0;
    end

    if (reset) begin
        signed_divider_done <= 1'b0;
    end else if (es_ready_go && !ms_allowin) begin
        signed_divider_done <= 1'b1;
    end else if (ms_allowin) begin
        signed_divider_done <= 1'b0;
    end
end


// LO & HI
always @ (posedge clk) begin
    if (reg_LO_we && !no_store) begin
        reg_LO <= reg_LO_wdata;
    end
    if (reg_HI_we&& !no_store) begin
        reg_HI <= reg_HI_wdata;
    end
end

assign reg_LO_we =
    es_inst_mtlo || es_inst_mult || es_inst_multu ||
    (es_inst_div  && signed_dout_tvalid)          ||
    (es_inst_divu && unsigned_dout_tvalid);
assign reg_HI_we =
    es_inst_mthi || es_inst_mult || es_inst_multu ||
    (es_inst_div  && signed_dout_tvalid)          ||
    (es_inst_divu && unsigned_dout_tvalid);

assign reg_LO_wdata =
    es_inst_mult    ? signed_mult_res       [31:0]  :
    es_inst_multu   ? unsigned_mult_res     [31:0]  :
    es_inst_div     ? signed_divider_res    [63:32] :
    es_inst_divu    ? unsigned_divider_res  [63:32] :
    es_rs_value;

assign reg_HI_wdata =
    es_inst_mult    ? signed_mult_res       [63:32] :
    es_inst_multu   ? unsigned_mult_res     [63:32] :
    es_inst_div     ? signed_divider_res    [31:0]  :
    es_inst_divu    ? unsigned_divider_res  [31:0]  :
    es_rs_value;

assign reg_LO_rdata = reg_LO;
assign reg_HI_rdata = reg_HI;

// MEM
wire [ 1:0] st_addr;

wire [31:0] st_data;
wire [31:0] swl_data;
wire [31:0] swr_data;

wire [ 3:0] st_strb;
wire [ 3:0] sw_strb;
wire [ 3:0] sh_strb;
wire [ 3:0] sb_strb;
wire [ 3:0] swl_strb;
wire [ 3:0] swr_strb;

assign st_addr = es_alu_result[1:0];

assign st_data = 
    ( {32{es_inst_sb }} & {4{ es_rt_value[ 7:0] }} ) |
    ( {32{es_inst_sh }} & {2{ es_rt_value[15:0] }} ) |
    ( {32{es_inst_sw }} & es_rt_value              ) |
    ( {32{es_inst_swl}} & swl_data                 ) |
    ( {32{es_inst_swr}} & swr_data                 );

assign swl_data = 
    ( {32{st_addr == 2'b00}} & {24'b0, es_rt_value[31:24]} ) |
    ( {32{st_addr == 2'b01}} & {16'b0, es_rt_value[31:16]} ) |
    ( {32{st_addr == 2'b10}} & { 8'b0, es_rt_value[31: 8]} ) |
    ( {32{st_addr == 2'b11}} &         es_rt_value[31: 0]  );

assign swr_data = 
    ( {32{st_addr == 2'b00}} &  es_rt_value[31: 0]         ) |
    ( {32{st_addr == 2'b01}} & {es_rt_value[23: 0],  8'b0} ) |
    ( {32{st_addr == 2'b10}} & {es_rt_value[15: 0], 16'b0} ) |
    ( {32{st_addr == 2'b11}} & {es_rt_value[ 7: 0], 24'b0} );

assign st_strb = 
    ( {4{es_inst_sb }} & sb_strb    ) |
    ( {4{es_inst_sh }} & sh_strb    ) |
    ( {4{es_inst_sw }} & sw_strb    ) |
    ( {4{es_inst_swl}} & swl_strb  ) |
    ( {4{es_inst_swr}} & swr_strb );

assign sb_strb = 
    ( {4{st_addr == 2'b00}} & 4'b0001 ) |
    ( {4{st_addr == 2'b01}} & 4'b0010 ) |
    ( {4{st_addr == 2'b10}} & 4'b0100 ) |
    ( {4{st_addr == 2'b11}} & 4'b1000 );

assign sh_strb = 
    ( {4{st_addr == 2'b00}} & 4'b0011 ) |
    ( {4{st_addr == 2'b10}} & 4'b1100 );

assign sw_strb = 4'b1111;

assign swl_strb = 
    ( {4{st_addr == 2'b00}} & 4'b0001 ) |
    ( {4{st_addr == 2'b01}} & 4'b0011 ) |
    ( {4{st_addr == 2'b10}} & 4'b0111 ) |
    ( {4{st_addr == 2'b11}} & 4'b1111 );

assign swr_strb = 
    ( {4{st_addr == 2'b00}} & 4'b1111 ) |
    ( {4{st_addr == 2'b01}} & 4'b1110 ) |
    ( {4{st_addr == 2'b10}} & 4'b1100 ) |
    ( {4{st_addr == 2'b11}} & 4'b1000 );

// SRAM
assign data_sram_en    = 1'b1;
assign data_sram_wen   = (es_mem_we && !no_store && es_valid)? st_strb : 4'h0;
assign data_sram_addr  = {es_alu_result[31:2], 2'b0};
assign data_sram_wdata = st_data;

// Block & Forward
assign es_fwd_valid = {4{ es_valid && es_gr_we && !es_res_from_mem }};
assign es_rf_dest   = es_dest;
assign es_rf_data   = es_exe_result;

assign es_blk_valid = es_valid && es_res_from_mem && !ws_eret && !ws_ex;

// Pipeline
assign es_ready_go    = 
    es_inst_div  && !ws_eret && !ws_ex    ? signed_dout_tvalid || signed_divider_done :
    es_inst_divu && !ws_eret && !ws_ex   ? unsigned_dout_tvalid || unsigned_divider_done :
    1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go && !ws_eret && !ws_ex;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_inst_mfc0_o = es_valid && es_inst_mfc0;

wire overflow_ex;
wire mem_ex;

wire load_ex;
wire store_ex;

assign overflow_ex = overflow && overflow_inst;

assign load_ex = (es_inst_lw && (st_addr != 2'b00)) || ((es_inst_lh || es_inst_lhu) && (st_addr[0] != 1'b0));
assign store_ex = (es_inst_sw && (st_addr != 2'b00)) || (es_inst_sh && (st_addr[0] != 1'b0));
assign mem_ex = load_ex || store_ex;


assign es_ex = (overflow_ex | mem_ex | ds_to_es_ex) & es_valid;
assign es_bd = ds_to_es_bd;
assign es_badvaddr = (fs_to_ds_ex) ? ds_to_es_badvaddr : es_alu_result;
assign es_excode = (ds_to_es_ex)? ds_to_es_excode :
                    (overflow_ex)? `EX_OV :
                    (load_ex)? `EX_ADEL :
                    (store_ex)? `EX_ADES :
                    ds_to_es_excode;



endmodule