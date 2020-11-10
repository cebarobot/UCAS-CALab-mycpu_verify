`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,

    //block
    output                          ws_inst_mfc0_o,
    output [4:0]                    ws_rf_dest    ,
    //exception
    output                          ws_eret  ,
    output                          ws_ex_o       ,
    output [31:0]                   cp0_epc       ,
    output [31:0]                   cp0_status    ,
    output [31:0]                   cp0_cause
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire [ 3:0] ws_gr_strb;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;

wire        ws_bd;
wire        ws_inst_eret;
wire        ws_inst_syscall;  
wire        ws_inst_mtc0;
wire [7:0]  cp0_addr;
wire [4:0]      ws_excode;
wire [31:0]     ws_badvaddr;

assign {
    ws_excode       ,  //123:119
    ws_badvaddr     ,  //118:87
    cp0_addr     ,  //86:79
    ws_ex           ,  //78:78
    ws_bd           ,  //77:77
    ws_inst_eret    ,  //76:76
    ws_inst_syscall ,  //75:75
    ws_inst_mfc0    ,  //74:74
    ws_inst_mtc0    ,  //73:73
    ws_gr_strb,         //72:69
    ws_dest,            //68:64
    ws_final_result,    //63:32
    ws_pc               //31:0
} = ms_to_ws_bus_r;



wire [ 3:0] rf_we;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {
    rf_we,      //40:37
    rf_waddr,   //36:32
    rf_wdata    //31:0
};

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end


//lab8


wire [5:0]      ext_int_in;
wire [31:0]     cp0_rdata;
wire            cp0_we;
wire [31:0]     cp0_wdata;


wire [31:0]     ws_cp0_epc;
wire [31:0]     ws_cp0_status;
wire [31:0]     ws_cp0_cause;

//valid
assign ws_inst_mfc0_o = ws_valid && ws_inst_mfc0;
assign ws_rf_dest = ws_valid ? ws_dest : 5'b0;

assign ws_ex_o = ws_valid && ws_ex;
// assign cp0_epc = ws_valid && ws_cp0_epc;
assign cp0_epc = {32{ws_valid}} & ws_cp0_epc;
assign cp0_cause = {32{ws_valid}} & ws_cp0_cause;
assign cp0_status = {32{ws_valid}} & ws_cp0_status;


//init
assign ext_int_in = 6'b0;
assign ws_eret = ws_inst_eret && ws_valid;

// TODO
assign rf_we    = {4{ ws_valid & ~ws_ex }} & ws_gr_strb;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_inst_mfc0 ? cp0_rdata :
                  ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = rf_we;
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;

assign cp0_we = ws_inst_mtc0 && ws_valid && !ws_ex;
assign cp0_wdata = ws_final_result;

cp0 u_cp0(
    .clk                (clk),
    .rst                (reset),
    
    .wb_ex              (ws_ex),
    .wb_bd              (ws_bd),
    .wb_excode          (ws_excode),
    .wb_pc              (ws_pc),
    .wb_badvaddr        (ws_badvaddr),
    .ws_eret         (ws_eret),
    .ext_int_in         (ext_int_in),

    .cp0_addr           (cp0_addr),
    .cp0_rdata          (cp0_rdata),
    .mtc0_we            (cp0_we),
    .cp0_wdata          (cp0_wdata),
  
    .cp0_epc            (ws_cp0_epc),  
    .cp0_status         (ws_cp0_status),
    .cp0_cause          (ws_cp0_cause)
);

endmodule
