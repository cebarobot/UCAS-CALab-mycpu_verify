`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD           34
    `define FS_TO_DS_BUS_WD     98
    `define DS_TO_ES_BUS_WD     210
    `define ES_TO_MS_BUS_WD     129
    `define MS_TO_WS_BUS_WD     124
    `define WS_TO_RF_BUS_WD     41
    `define ES_FWD_BLK_BUS_WD   42
    `define MS_FWD_BLK_BUS_WD   41

    `define EX_INT              5'h00
    `define EX_ADEL             5'h04
    `define EX_ADES             5'h05
    `define EX_SYS              5'h08
    `define EX_BP               5'h09
    `define EX_RI               5'h0a
    `define EX_OV               5'h0c
    `define EX_NO               5'h1f

`endif
