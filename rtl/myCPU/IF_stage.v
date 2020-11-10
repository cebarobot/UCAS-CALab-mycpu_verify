`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    // allwoin
    input                          ds_allowin     ,
    // br_bus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,

    // delay slot
    input         ds_is_branch,

    // inst sram interface
    output        inst_sram_en   ,
    output [ 3:0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,

    //exception
    input [31:0]  cp0_epc,
    input         ws_eret,
    input         ws_ex
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;
wire        to_fs_ready_go;

wire [31:0] seq_pc;
wire [31:0] next_pc;

wire         br_taken;
wire [ 31:0] br_target;
assign {br_stall,br_taken,br_target} = br_bus;

wire fs_ex;
wire fs_bd;
wire [31:0] fs_badvaddr;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {
                       fs_ex,       //97:97
                       fs_bd,       //96:96
                       fs_badvaddr, //95:64  
                       fs_inst ,    //63:32
                       fs_pc        //31:0
                       };

// pre-IF stage
assign to_fs_ready_go   = !br_stall;
assign to_fs_valid      = ~reset && to_fs_ready_go;
assign seq_pc           = fs_pc + 3'h4;
assign next_pc          = ws_ex ? 32'hbfc00380 :
                          ws_eret ? cp0_epc :
                          br_taken ? br_target : 
                                     seq_pc; 

// IF stage
assign fs_ready_go    = 1'b1;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go && !ws_eret && !ws_ex;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'h_bfbffffc;  //trick: to make next_pc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= next_pc;
    end
end

assign inst_sram_en    = to_fs_valid && fs_allowin;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = {next_pc[31:2], 2'b0};
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata;

//lab9
wire addr_error;
assign addr_error = (fs_pc[1:0] != 2'b0);
assign fs_ex = addr_error && fs_valid;
assign fs_bd = ds_is_branch;    
assign fs_badvaddr = fs_pc;

endmodule
