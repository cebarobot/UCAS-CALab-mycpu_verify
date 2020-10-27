`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,

    // forword from es
    output [`MS_FWD_BLK_BUS_WD -1:0] ms_fwd_blk_bus    
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire [31:0] ms_reg_LO_rdata;
wire [31:0] ms_reg_HI_rdata;
wire        ms_res_from_LO;
wire        ms_res_from_HI;
wire        ms_inst_lb     ;
wire        ms_inst_lbu    ;
wire        ms_inst_lh     ;
wire        ms_inst_lhu    ;
wire        ms_inst_lwl    ;
wire        ms_inst_lwr    ;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_exe_result;
wire [31:0] ms_pc;
assign {
    ms_inst_lb      ,  //76:76
    ms_inst_lbu     ,  //75:75
    ms_inst_lh      ,  //74:74
    ms_inst_lhu     ,  //73:73
    ms_inst_lwl     ,  //72:72
    ms_inst_lwr     ,  //71:71
    ms_res_from_mem,  //70:70
    ms_gr_we       ,  //69:69
    ms_dest        ,  //68:64
    ms_exe_result  ,  //63:32
    ms_pc             //31:0
} = es_to_ms_bus_r;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

assign ms_to_ws_bus = {
    ms_gr_we       ,  //69:69
    ms_dest        ,  //68:64
    ms_final_result,  //63:32
    ms_pc             //31:0
};

wire [ 3:0] ms_fwd_valid;
wire [ 4:0] ms_rf_dest;
wire [31:0] ms_rf_data;

assign ms_fwd_blk_bus = {
    ms_fwd_valid,   // 40:37
    ms_rf_dest,     // 36:32
    ms_rf_data      // 31:0
};

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus;
    end
end

// TODO lab7
wire [ 1:0] mem_addr;
wire [31:0] mem_word;
wire [15:0] mem_half;
wire [ 7:0] mem_byte;
wire [31:0] mem_half_ex;
wire [31:0] mem_byte_ex;

assign mem_addr = ms_exe_result[1:0];
assign mem_word = data_sram_rdata;
assign mem_half = mem_addr[1]? mem_word[31:16] : mem_word[15: 0];
assign mem_byte = mem_addr[0]? mem_half[15: 8] : mem_half[ 7: 0];

assign mem_half_ex[31:16] = {16{ ms_inst_lh & mem_half[15] }};
assign mem_half_ex[15: 0] = mem_half;
assign mem_byte_ex[31: 8] = {24{ ms_inst_lb & mem_byte[15] }};
assign mem_byte_ex[ 7: 0] = mem_byte;

assign mem_result = 
    (ms_inst_lb || ms_inst_lbu)? mem_byte_ex :
    (ms_inst_lh || ms_inst_lhu)? mem_half_ex :
    mem_word;

assign ms_final_result = 
    ms_res_from_mem ? mem_result : 
    ms_exe_result;

assign ms_fwd_valid = {4{ ms_valid && ms_gr_we && 1'b1 }};      // 1'b1 for data_sram_rvalid
assign ms_rf_dest   = ms_dest;
assign ms_rf_data   = ms_final_result;

endmodule
