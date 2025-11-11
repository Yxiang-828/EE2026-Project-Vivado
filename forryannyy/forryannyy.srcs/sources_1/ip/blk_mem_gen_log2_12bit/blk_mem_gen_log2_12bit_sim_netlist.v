// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.2 (win64) Build 2258646 Thu Jun 14 20:03:12 MDT 2018
// Date        : Sun Nov  9 02:22:58 2025
// Host        : LAPTOP-TABE59UT running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim {C:/Users/rkoh2/OneDrive/Desktop/Personal/EE2026_Final/S3_09_RYAN
//               KOH_SEAN LEE_YAO XIANG_YI
//               YANG_Archive.xpr/forryannyy/forryannyy.srcs/sources_1/ip/blk_mem_gen_log2_12bit/blk_mem_gen_log2_12bit_sim_netlist.v}
// Design      : blk_mem_gen_log2_12bit
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7a35tcpg236-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "blk_mem_gen_log2_12bit,blk_mem_gen_v8_4_1,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "blk_mem_gen_v8_4_1,Vivado 2018.2" *) 
(* NotValidForBitStream *)
module blk_mem_gen_log2_12bit
   (clka,
    ena,
    addra,
    douta);
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA CLK" *) (* x_interface_parameter = "XIL_INTERFACENAME BRAM_PORTA, MEM_SIZE 8192, MEM_WIDTH 32, MEM_ECC NONE, MASTER_TYPE OTHER" *) input clka;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA EN" *) input ena;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA ADDR" *) input [11:0]addra;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA DOUT" *) output [7:0]douta;

  wire [11:0]addra;
  wire clka;
  wire [7:0]douta;
  wire ena;
  wire NLW_U0_dbiterr_UNCONNECTED;
  wire NLW_U0_rsta_busy_UNCONNECTED;
  wire NLW_U0_rstb_busy_UNCONNECTED;
  wire NLW_U0_s_axi_arready_UNCONNECTED;
  wire NLW_U0_s_axi_awready_UNCONNECTED;
  wire NLW_U0_s_axi_bvalid_UNCONNECTED;
  wire NLW_U0_s_axi_dbiterr_UNCONNECTED;
  wire NLW_U0_s_axi_rlast_UNCONNECTED;
  wire NLW_U0_s_axi_rvalid_UNCONNECTED;
  wire NLW_U0_s_axi_sbiterr_UNCONNECTED;
  wire NLW_U0_s_axi_wready_UNCONNECTED;
  wire NLW_U0_sbiterr_UNCONNECTED;
  wire [7:0]NLW_U0_doutb_UNCONNECTED;
  wire [11:0]NLW_U0_rdaddrecc_UNCONNECTED;
  wire [3:0]NLW_U0_s_axi_bid_UNCONNECTED;
  wire [1:0]NLW_U0_s_axi_bresp_UNCONNECTED;
  wire [11:0]NLW_U0_s_axi_rdaddrecc_UNCONNECTED;
  wire [7:0]NLW_U0_s_axi_rdata_UNCONNECTED;
  wire [3:0]NLW_U0_s_axi_rid_UNCONNECTED;
  wire [1:0]NLW_U0_s_axi_rresp_UNCONNECTED;

  (* C_ADDRA_WIDTH = "12" *) 
  (* C_ADDRB_WIDTH = "12" *) 
  (* C_ALGORITHM = "1" *) 
  (* C_AXI_ID_WIDTH = "4" *) 
  (* C_AXI_SLAVE_TYPE = "0" *) 
  (* C_AXI_TYPE = "1" *) 
  (* C_BYTE_SIZE = "9" *) 
  (* C_COMMON_CLK = "0" *) 
  (* C_COUNT_18K_BRAM = "0" *) 
  (* C_COUNT_36K_BRAM = "1" *) 
  (* C_CTRL_ECC_ALGO = "NONE" *) 
  (* C_DEFAULT_DATA = "0" *) 
  (* C_DISABLE_WARN_BHV_COLL = "0" *) 
  (* C_DISABLE_WARN_BHV_RANGE = "0" *) 
  (* C_ELABORATION_DIR = "./" *) 
  (* C_ENABLE_32BIT_ADDRESS = "0" *) 
  (* C_EN_DEEPSLEEP_PIN = "0" *) 
  (* C_EN_ECC_PIPE = "0" *) 
  (* C_EN_RDADDRA_CHG = "0" *) 
  (* C_EN_RDADDRB_CHG = "0" *) 
  (* C_EN_SAFETY_CKT = "0" *) 
  (* C_EN_SHUTDOWN_PIN = "0" *) 
  (* C_EN_SLEEP_PIN = "0" *) 
  (* C_EST_POWER_SUMMARY = "Estimated Power for IP     :     2.326399 mW" *) 
  (* C_FAMILY = "artix7" *) 
  (* C_HAS_AXI_ID = "0" *) 
  (* C_HAS_ENA = "1" *) 
  (* C_HAS_ENB = "0" *) 
  (* C_HAS_INJECTERR = "0" *) 
  (* C_HAS_MEM_OUTPUT_REGS_A = "1" *) 
  (* C_HAS_MEM_OUTPUT_REGS_B = "0" *) 
  (* C_HAS_MUX_OUTPUT_REGS_A = "0" *) 
  (* C_HAS_MUX_OUTPUT_REGS_B = "0" *) 
  (* C_HAS_REGCEA = "0" *) 
  (* C_HAS_REGCEB = "0" *) 
  (* C_HAS_RSTA = "0" *) 
  (* C_HAS_RSTB = "0" *) 
  (* C_HAS_SOFTECC_INPUT_REGS_A = "0" *) 
  (* C_HAS_SOFTECC_OUTPUT_REGS_B = "0" *) 
  (* C_INITA_VAL = "0" *) 
  (* C_INITB_VAL = "0" *) 
  (* C_INIT_FILE = "blk_mem_gen_log2_12bit.mem" *) 
  (* C_INIT_FILE_NAME = "blk_mem_gen_log2_12bit.mif" *) 
  (* C_INTERFACE_TYPE = "0" *) 
  (* C_LOAD_INIT_FILE = "1" *) 
  (* C_MEM_TYPE = "3" *) 
  (* C_MUX_PIPELINE_STAGES = "0" *) 
  (* C_PRIM_TYPE = "1" *) 
  (* C_READ_DEPTH_A = "4096" *) 
  (* C_READ_DEPTH_B = "4096" *) 
  (* C_READ_WIDTH_A = "8" *) 
  (* C_READ_WIDTH_B = "8" *) 
  (* C_RSTRAM_A = "0" *) 
  (* C_RSTRAM_B = "0" *) 
  (* C_RST_PRIORITY_A = "CE" *) 
  (* C_RST_PRIORITY_B = "CE" *) 
  (* C_SIM_COLLISION_CHECK = "ALL" *) 
  (* C_USE_BRAM_BLOCK = "0" *) 
  (* C_USE_BYTE_WEA = "0" *) 
  (* C_USE_BYTE_WEB = "0" *) 
  (* C_USE_DEFAULT_DATA = "0" *) 
  (* C_USE_ECC = "0" *) 
  (* C_USE_SOFTECC = "0" *) 
  (* C_USE_URAM = "0" *) 
  (* C_WEA_WIDTH = "1" *) 
  (* C_WEB_WIDTH = "1" *) 
  (* C_WRITE_DEPTH_A = "4096" *) 
  (* C_WRITE_DEPTH_B = "4096" *) 
  (* C_WRITE_MODE_A = "WRITE_FIRST" *) 
  (* C_WRITE_MODE_B = "WRITE_FIRST" *) 
  (* C_WRITE_WIDTH_A = "8" *) 
  (* C_WRITE_WIDTH_B = "8" *) 
  (* C_XDEVICEFAMILY = "artix7" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  blk_mem_gen_log2_12bit_blk_mem_gen_v8_4_1 U0
       (.addra(addra),
        .addrb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .clka(clka),
        .clkb(1'b0),
        .dbiterr(NLW_U0_dbiterr_UNCONNECTED),
        .deepsleep(1'b0),
        .dina({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .dinb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .douta(douta),
        .doutb(NLW_U0_doutb_UNCONNECTED[7:0]),
        .eccpipece(1'b0),
        .ena(ena),
        .enb(1'b0),
        .injectdbiterr(1'b0),
        .injectsbiterr(1'b0),
        .rdaddrecc(NLW_U0_rdaddrecc_UNCONNECTED[11:0]),
        .regcea(1'b0),
        .regceb(1'b0),
        .rsta(1'b0),
        .rsta_busy(NLW_U0_rsta_busy_UNCONNECTED),
        .rstb(1'b0),
        .rstb_busy(NLW_U0_rstb_busy_UNCONNECTED),
        .s_aclk(1'b0),
        .s_aresetn(1'b0),
        .s_axi_araddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arburst({1'b0,1'b0}),
        .s_axi_arid({1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arlen({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arready(NLW_U0_s_axi_arready_UNCONNECTED),
        .s_axi_arsize({1'b0,1'b0,1'b0}),
        .s_axi_arvalid(1'b0),
        .s_axi_awaddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awburst({1'b0,1'b0}),
        .s_axi_awid({1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awlen({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awready(NLW_U0_s_axi_awready_UNCONNECTED),
        .s_axi_awsize({1'b0,1'b0,1'b0}),
        .s_axi_awvalid(1'b0),
        .s_axi_bid(NLW_U0_s_axi_bid_UNCONNECTED[3:0]),
        .s_axi_bready(1'b0),
        .s_axi_bresp(NLW_U0_s_axi_bresp_UNCONNECTED[1:0]),
        .s_axi_bvalid(NLW_U0_s_axi_bvalid_UNCONNECTED),
        .s_axi_dbiterr(NLW_U0_s_axi_dbiterr_UNCONNECTED),
        .s_axi_injectdbiterr(1'b0),
        .s_axi_injectsbiterr(1'b0),
        .s_axi_rdaddrecc(NLW_U0_s_axi_rdaddrecc_UNCONNECTED[11:0]),
        .s_axi_rdata(NLW_U0_s_axi_rdata_UNCONNECTED[7:0]),
        .s_axi_rid(NLW_U0_s_axi_rid_UNCONNECTED[3:0]),
        .s_axi_rlast(NLW_U0_s_axi_rlast_UNCONNECTED),
        .s_axi_rready(1'b0),
        .s_axi_rresp(NLW_U0_s_axi_rresp_UNCONNECTED[1:0]),
        .s_axi_rvalid(NLW_U0_s_axi_rvalid_UNCONNECTED),
        .s_axi_sbiterr(NLW_U0_s_axi_sbiterr_UNCONNECTED),
        .s_axi_wdata({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_wlast(1'b0),
        .s_axi_wready(NLW_U0_s_axi_wready_UNCONNECTED),
        .s_axi_wstrb(1'b0),
        .s_axi_wvalid(1'b0),
        .sbiterr(NLW_U0_sbiterr_UNCONNECTED),
        .shutdown(1'b0),
        .sleep(1'b0),
        .wea(1'b0),
        .web(1'b0));
endmodule

(* ORIG_REF_NAME = "blk_mem_gen_generic_cstr" *) 
module blk_mem_gen_log2_12bit_blk_mem_gen_generic_cstr
   (douta,
    clka,
    ena,
    addra);
  output [7:0]douta;
  input clka;
  input ena;
  input [11:0]addra;

  wire [11:0]addra;
  wire clka;
  wire [7:0]douta;
  wire ena;

  blk_mem_gen_log2_12bit_blk_mem_gen_prim_width \ramloop[0].ram.r 
       (.addra(addra),
        .clka(clka),
        .douta(douta),
        .ena(ena));
endmodule

(* ORIG_REF_NAME = "blk_mem_gen_prim_width" *) 
module blk_mem_gen_log2_12bit_blk_mem_gen_prim_width
   (douta,
    clka,
    ena,
    addra);
  output [7:0]douta;
  input clka;
  input ena;
  input [11:0]addra;

  wire [11:0]addra;
  wire clka;
  wire [7:0]douta;
  wire ena;

  blk_mem_gen_log2_12bit_blk_mem_gen_prim_wrapper_init \prim_init.ram 
       (.addra(addra),
        .clka(clka),
        .douta(douta),
        .ena(ena));
endmodule

(* ORIG_REF_NAME = "blk_mem_gen_prim_wrapper_init" *) 
module blk_mem_gen_log2_12bit_blk_mem_gen_prim_wrapper_init
   (douta,
    clka,
    ena,
    addra);
  output [7:0]douta;
  input clka;
  input ena;
  input [11:0]addra;

  wire \DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_n_71 ;
  wire [11:0]addra;
  wire clka;
  wire [7:0]douta;
  wire ena;
  wire \NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_CASCADEOUTA_UNCONNECTED ;
  wire \NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_CASCADEOUTB_UNCONNECTED ;
  wire \NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_DBITERR_UNCONNECTED ;
  wire \NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_SBITERR_UNCONNECTED ;
  wire [31:8]\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_DOADO_UNCONNECTED ;
  wire [31:0]\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_DOBDO_UNCONNECTED ;
  wire [3:1]\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_DOPADOP_UNCONNECTED ;
  wire [3:0]\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_DOPBDOP_UNCONNECTED ;
  wire [7:0]\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_ECCPARITY_UNCONNECTED ;
  wire [8:0]\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_RDADDRECC_UNCONNECTED ;

  (* box_type = "PRIMITIVE" *) 
  RAMB36E1 #(
    .DOA_REG(1),
    .DOB_REG(0),
    .EN_ECC_READ("FALSE"),
    .EN_ECC_WRITE("FALSE"),
    .INITP_00(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_01(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_02(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_03(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_04(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_05(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_06(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_07(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_08(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_09(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_0A(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_0B(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_0C(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_0D(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_0E(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_0F(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_00(256'h0202020202020202020101010101010101010101000000000000000000000000),
    .INIT_01(256'h0505050505050505040404040404040404040403030303030303030303030202),
    .INIT_02(256'h0808080808080707070707070707070707060606060606060606060605050505),
    .INIT_03(256'h0B0B0B0B0A0A0A0A0A0A0A0A0A0A0A0909090909090909090909080808080808),
    .INIT_04(256'h0E0D0D0D0D0D0D0D0D0D0D0D0D0C0C0C0C0C0C0C0C0C0C0C0B0B0B0B0B0B0B0B),
    .INIT_05(256'h101010101010101010100F0F0F0F0F0F0F0F0F0F0F0F0E0E0E0E0E0E0E0E0E0E),
    .INIT_06(256'h1313131313131312121212121212121212121211111111111111111111111110),
    .INIT_07(256'h1616161615151515151515151515151514141414141414141414141413131313),
    .INIT_08(256'h1918181818181818181818181717171717171717171717171616161616161616),
    .INIT_09(256'h1B1B1B1B1B1B1B1B1B1A1A1A1A1A1A1A1A1A1A1A1A1919191919191919191919),
    .INIT_0A(256'h1E1E1E1E1E1D1D1D1D1D1D1D1D1D1D1D1D1C1C1C1C1C1C1C1C1C1C1C1C1B1B1B),
    .INIT_0B(256'h212020202020202020202020201F1F1F1F1F1F1F1F1F1F1F1F1E1E1E1E1E1E1E),
    .INIT_0C(256'h2323232323232323222222222222222222222222222121212121212121212121),
    .INIT_0D(256'h2626262625252525252525252525252524242424242424242424242423232323),
    .INIT_0E(256'h2828282828282828282828272727272727272727272727262626262626262626),
    .INIT_0F(256'h2B2B2B2B2B2B2A2A2A2A2A2A2A2A2A2A2A2A2929292929292929292929292928),
    .INIT_10(256'h2D2D2D2D2D2D2D2D2D2D2D2D2D2C2C2C2C2C2C2C2C2C2C2C2C2B2B2B2B2B2B2B),
    .INIT_11(256'h303030303030302F2F2F2F2F2F2F2F2F2F2F2F2F2E2E2E2E2E2E2E2E2E2E2E2E),
    .INIT_12(256'h3332323232323232323232323232313131313131313131313131303030303030),
    .INIT_13(256'h3535353535353534343434343434343434343434333333333333333333333333),
    .INIT_14(256'h3837373737373737373737373737363636363636363636363636363535353535),
    .INIT_15(256'h3A3A3A3A3A3A3A39393939393939393939393939383838383838383838383838),
    .INIT_16(256'h3C3C3C3C3C3C3C3C3C3C3C3C3C3B3B3B3B3B3B3B3B3B3B3B3B3B3A3A3A3A3A3A),
    .INIT_17(256'h3F3F3F3F3F3F3E3E3E3E3E3E3E3E3E3E3E3E3E3D3D3D3D3D3D3D3D3D3D3D3D3D),
    .INIT_18(256'h414141414141414141414140404040404040404040404040403F3F3F3F3F3F3F),
    .INIT_19(256'h4444444343434343434343434343434343424242424242424242424242424141),
    .INIT_1A(256'h4646464646464646464545454545454545454545454544444444444444444444),
    .INIT_1B(256'h4848484848484848484848484848474747474747474747474747474646464646),
    .INIT_1C(256'h4B4B4B4B4B4A4A4A4A4A4A4A4A4A4A4A4A4A4A49494949494949494949494949),
    .INIT_1D(256'h4D4D4D4D4D4D4D4D4D4D4C4C4C4C4C4C4C4C4C4C4C4C4C4C4B4B4B4B4B4B4B4B),
    .INIT_1E(256'h504F4F4F4F4F4F4F4F4F4F4F4F4F4F4E4E4E4E4E4E4E4E4E4E4E4E4E4D4D4D4D),
    .INIT_1F(256'h5252525252515151515151515151515151515150505050505050505050505050),
    .INIT_20(256'h5454545454545454545353535353535353535353535353525252525252525252),
    .INIT_21(256'h5656565656565656565656565656555555555555555555555555555554545454),
    .INIT_22(256'h5959595858585858585858585858585858575757575757575757575757575757),
    .INIT_23(256'h5B5B5B5B5B5B5B5A5A5A5A5A5A5A5A5A5A5A5A5A5A5959595959595959595959),
    .INIT_24(256'h5D5D5D5D5D5D5D5D5D5D5D5C5C5C5C5C5C5C5C5C5C5C5C5C5C5B5B5B5B5B5B5B),
    .INIT_25(256'h5F5F5F5F5F5F5F5F5F5F5F5F5F5F5E5E5E5E5E5E5E5E5E5E5E5E5E5E5D5D5D5D),
    .INIT_26(256'h6262626161616161616161616161616161606060606060606060606060606060),
    .INIT_27(256'h6464646464646363636363636363636363636363626262626262626262626262),
    .INIT_28(256'h6666666666666666666565656565656565656565656565646464646464646464),
    .INIT_29(256'h6868686868686868686868676767676767676767676767676767666666666666),
    .INIT_2A(256'h6A6A6A6A6A6A6A6A6A6A6A6A6A6A696969696969696969696969696969686868),
    .INIT_2B(256'h6D6C6C6C6C6C6C6C6C6C6C6C6C6C6C6C6B6B6B6B6B6B6B6B6B6B6B6B6B6B6B6A),
    .INIT_2C(256'h6F6F6F6E6E6E6E6E6E6E6E6E6E6E6E6E6E6E6D6D6D6D6D6D6D6D6D6D6D6D6D6D),
    .INIT_2D(256'h71717171717070707070707070707070707070706F6F6F6F6F6F6F6F6F6F6F6F),
    .INIT_2E(256'h7373737373737372727272727272727272727272727271717171717171717171),
    .INIT_2F(256'h7575757575757575757474747474747474747474747474747373737373737373),
    .INIT_30(256'h7777777777777777777776767676767676767676767676767676757575757575),
    .INIT_31(256'h7979797979797979797979797878787878787878787878787878787777777777),
    .INIT_32(256'h7B7B7B7B7B7B7B7B7B7B7B7B7B7A7A7A7A7A7A7A7A7A7A7A7A7A7A7A79797979),
    .INIT_33(256'h7D7D7D7D7D7D7D7D7D7D7D7D7D7D7C7C7C7C7C7C7C7C7C7C7C7C7C7C7C7B7B7B),
    .INIT_34(256'h7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7E7E7E7E7E7E7E7E7E7E7E7E7E7E7E7D7D),
    .INIT_35(256'h818181818181818181818181818181808080808080808080808080808080807F),
    .INIT_36(256'h8383838383838383838383838383838382828282828282828282828282828281),
    .INIT_37(256'h8585858585858585858585858585858584848484848484848484848484848484),
    .INIT_38(256'h8787878787878787878787878787878786868686868686868686868686868686),
    .INIT_39(256'h8989898989898989898989898989898988888888888888888888888888888888),
    .INIT_3A(256'h8B8B8B8B8B8B8B8B8B8B8B8B8B8B8B8B8A8A8A8A8A8A8A8A8A8A8A8A8A8A8A8A),
    .INIT_3B(256'h8D8D8D8D8D8D8D8D8D8D8D8D8D8D8D8C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8C),
    .INIT_3C(256'h8F8F8F8F8F8F8F8F8F8F8F8F8F8F8F8E8E8E8E8E8E8E8E8E8E8E8E8E8E8E8E8D),
    .INIT_3D(256'h9191919191919191919191919191909090909090909090909090909090908F8F),
    .INIT_3E(256'h9393939393939393939393939392929292929292929292929292929292929191),
    .INIT_3F(256'h9595959595959595959595959494949494949494949494949494949494939393),
    .INIT_40(256'h9797979797979797979797969696969696969696969696969696969595959595),
    .INIT_41(256'h9999999999999999999898989898989898989898989898989898979797979797),
    .INIT_42(256'h9B9B9B9B9B9B9B9B9A9A9A9A9A9A9A9A9A9A9A9A9A9A9A9A9999999999999999),
    .INIT_43(256'h9D9D9D9D9D9D9C9C9C9C9C9C9C9C9C9C9C9C9C9C9C9C9C9B9B9B9B9B9B9B9B9B),
    .INIT_44(256'h9F9F9F9F9E9E9E9E9E9E9E9E9E9E9E9E9E9E9E9E9E9D9D9D9D9D9D9D9D9D9D9D),
    .INIT_45(256'hA1A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A09F9F9F9F9F9F9F9F9F9F9F9F9F),
    .INIT_46(256'hA2A2A2A2A2A2A2A2A2A2A2A2A2A2A2A2A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1),
    .INIT_47(256'hA4A4A4A4A4A4A4A4A4A4A4A4A4A4A3A3A3A3A3A3A3A3A3A3A3A3A3A3A3A3A3A2),
    .INIT_48(256'hA6A6A6A6A6A6A6A6A6A6A6A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A4A4A4),
    .INIT_49(256'hA8A8A8A8A8A8A8A8A7A7A7A7A7A7A7A7A7A7A7A7A7A7A7A7A7A7A6A6A6A6A6A6),
    .INIT_4A(256'hAAAAAAAAAAA9A9A9A9A9A9A9A9A9A9A9A9A9A9A9A9A9A9A8A8A8A8A8A8A8A8A8),
    .INIT_4B(256'hACACABABABABABABABABABABABABABABABABABABAAAAAAAAAAAAAAAAAAAAAAAA),
    .INIT_4C(256'hADADADADADADADADADADADADADADADADACACACACACACACACACACACACACACACAC),
    .INIT_4D(256'hAFAFAFAFAFAFAFAFAFAFAFAFAFAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAD),
    .INIT_4E(256'hB1B1B1B1B1B1B1B1B1B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0AFAFAFAFAF),
    .INIT_4F(256'hB3B3B3B3B3B2B2B2B2B2B2B2B2B2B2B2B2B2B2B2B2B2B2B1B1B1B1B1B1B1B1B1),
    .INIT_50(256'hB5B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B3B3B3B3B3B3B3B3B3B3B3B3B3),
    .INIT_51(256'hB6B6B6B6B6B6B6B6B6B6B6B6B6B6B6B5B5B5B5B5B5B5B5B5B5B5B5B5B5B5B5B5),
    .INIT_52(256'hB8B8B8B8B8B8B8B8B8B8B7B7B7B7B7B7B7B7B7B7B7B7B7B7B7B7B7B7B7B6B6B6),
    .INIT_53(256'hBABABABABABAB9B9B9B9B9B9B9B9B9B9B9B9B9B9B9B9B9B9B8B8B8B8B8B8B8B8),
    .INIT_54(256'hBCBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBABABABABABABABABABABABA),
    .INIT_55(256'hBDBDBDBDBDBDBDBDBDBDBDBDBDBDBDBCBCBCBCBCBCBCBCBCBCBCBCBCBCBCBCBC),
    .INIT_56(256'hBFBFBFBFBFBFBFBFBFBFBEBEBEBEBEBEBEBEBEBEBEBEBEBEBEBEBEBEBDBDBDBD),
    .INIT_57(256'hC1C1C1C1C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0BFBFBFBFBFBFBFBFBF),
    .INIT_58(256'hC2C2C2C2C2C2C2C2C2C2C2C2C2C2C2C2C2C1C1C1C1C1C1C1C1C1C1C1C1C1C1C1),
    .INIT_59(256'hC4C4C4C4C4C4C4C4C4C4C4C4C3C3C3C3C3C3C3C3C3C3C3C3C3C3C3C3C3C3C3C2),
    .INIT_5A(256'hC6C6C6C6C6C6C5C5C5C5C5C5C5C5C5C5C5C5C5C5C5C5C5C5C5C4C4C4C4C4C4C4),
    .INIT_5B(256'hC7C7C7C7C7C7C7C7C7C7C7C7C7C7C7C7C7C7C7C6C6C6C6C6C6C6C6C6C6C6C6C6),
    .INIT_5C(256'hC9C9C9C9C9C9C9C9C9C9C9C9C9C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8),
    .INIT_5D(256'hCBCBCBCBCBCBCBCACACACACACACACACACACACACACACACACACACAC9C9C9C9C9C9),
    .INIT_5E(256'hCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCBCBCBCBCBCBCBCBCBCBCBCBCB),
    .INIT_5F(256'hCECECECECECECECECECECECECECDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCD),
    .INIT_60(256'hD0D0D0D0D0D0CFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCECECECECECECE),
    .INIT_61(256'hD1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D0D0D0D0D0D0D0D0D0D0D0D0D0D0),
    .INIT_62(256'hD3D3D3D3D3D3D3D3D3D3D3D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D1),
    .INIT_63(256'hD5D5D5D5D4D4D4D4D4D4D4D4D4D4D4D4D4D4D4D4D4D4D4D4D3D3D3D3D3D3D3D3),
    .INIT_64(256'hD6D6D6D6D6D6D6D6D6D6D6D6D6D6D6D6D5D5D5D5D5D5D5D5D5D5D5D5D5D5D5D5),
    .INIT_65(256'hD8D8D8D8D8D8D8D8D7D7D7D7D7D7D7D7D7D7D7D7D7D7D7D7D7D7D7D7D6D6D6D6),
    .INIT_66(256'hD9D9D9D9D9D9D9D9D9D9D9D9D9D9D9D9D9D9D9D9D8D8D8D8D8D8D8D8D8D8D8D8),
    .INIT_67(256'hDBDBDBDBDBDBDBDBDBDBDBDBDADADADADADADADADADADADADADADADADADADADA),
    .INIT_68(256'hDDDDDDDDDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDBDBDBDBDBDBDBDB),
    .INIT_69(256'hDEDEDEDEDEDEDEDEDEDEDEDEDEDEDEDEDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD),
    .INIT_6A(256'hE0E0E0E0E0E0E0DFDFDFDFDFDFDFDFDFDFDFDFDFDFDFDFDFDFDFDFDFDEDEDEDE),
    .INIT_6B(256'hE1E1E1E1E1E1E1E1E1E1E1E1E1E1E1E1E1E1E1E0E0E0E0E0E0E0E0E0E0E0E0E0),
    .INIT_6C(256'hE3E3E3E3E3E3E3E3E3E3E2E2E2E2E2E2E2E2E2E2E2E2E2E2E2E2E2E2E2E2E2E1),
    .INIT_6D(256'hE5E4E4E4E4E4E4E4E4E4E4E4E4E4E4E4E4E4E4E4E4E4E3E3E3E3E3E3E3E3E3E3),
    .INIT_6E(256'hE6E6E6E6E6E6E6E6E6E6E6E6E5E5E5E5E5E5E5E5E5E5E5E5E5E5E5E5E5E5E5E5),
    .INIT_6F(256'hE8E8E8E7E7E7E7E7E7E7E7E7E7E7E7E7E7E7E7E7E7E7E7E7E6E6E6E6E6E6E6E6),
    .INIT_70(256'hE9E9E9E9E9E9E9E9E9E9E9E9E9E9E8E8E8E8E8E8E8E8E8E8E8E8E8E8E8E8E8E8),
    .INIT_71(256'hEBEBEBEBEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAE9E9E9E9E9E9E9),
    .INIT_72(256'hECECECECECECECECECECECECECECECEBEBEBEBEBEBEBEBEBEBEBEBEBEBEBEBEB),
    .INIT_73(256'hEEEEEEEEEEEDEDEDEDEDEDEDEDEDEDEDEDEDEDEDEDEDEDEDEDEDECECECECECEC),
    .INIT_74(256'hEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE),
    .INIT_75(256'hF1F1F1F1F1F1F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0EFEFEFEFEF),
    .INIT_76(256'hF2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1),
    .INIT_77(256'hF4F4F4F4F4F3F3F3F3F3F3F3F3F3F3F3F3F3F3F3F3F3F3F3F3F3F3F2F2F2F2F2),
    .INIT_78(256'hF5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4),
    .INIT_79(256'hF7F7F7F7F7F6F6F6F6F6F6F6F6F6F6F6F6F6F6F6F6F6F6F6F6F6F5F5F5F5F5F5),
    .INIT_7A(256'hF8F8F8F8F8F8F8F8F8F8F8F8F8F8F8F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7),
    .INIT_7B(256'hFAFAFAFAF9F9F9F9F9F9F9F9F9F9F9F9F9F9F9F9F9F9F9F9F9F8F8F8F8F8F8F8),
    .INIT_7C(256'hFBFBFBFBFBFBFBFBFBFBFBFBFBFBFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFAFA),
    .INIT_7D(256'hFDFDFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFBFBFBFBFBFBFBFB),
    .INIT_7E(256'hFEFEFEFEFEFEFEFEFEFEFEFEFDFDFDFDFDFDFDFDFDFDFDFDFDFDFDFDFDFDFDFD),
    .INIT_7F(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFEFEFEFEFEFEFEFEFE),
    .INIT_A(36'h000000000),
    .INIT_B(36'h000000000),
    .INIT_FILE("NONE"),
    .IS_CLKARDCLK_INVERTED(1'b0),
    .IS_CLKBWRCLK_INVERTED(1'b0),
    .IS_ENARDEN_INVERTED(1'b0),
    .IS_ENBWREN_INVERTED(1'b0),
    .IS_RSTRAMARSTRAM_INVERTED(1'b0),
    .IS_RSTRAMB_INVERTED(1'b0),
    .IS_RSTREGARSTREG_INVERTED(1'b0),
    .IS_RSTREGB_INVERTED(1'b0),
    .RAM_EXTENSION_A("NONE"),
    .RAM_EXTENSION_B("NONE"),
    .RAM_MODE("TDP"),
    .RDADDR_COLLISION_HWCONFIG("PERFORMANCE"),
    .READ_WIDTH_A(9),
    .READ_WIDTH_B(9),
    .RSTREG_PRIORITY_A("REGCE"),
    .RSTREG_PRIORITY_B("REGCE"),
    .SIM_COLLISION_CHECK("ALL"),
    .SIM_DEVICE("7SERIES"),
    .SRVAL_A(36'h000000000),
    .SRVAL_B(36'h000000000),
    .WRITE_MODE_A("WRITE_FIRST"),
    .WRITE_MODE_B("WRITE_FIRST"),
    .WRITE_WIDTH_A(9),
    .WRITE_WIDTH_B(9)) 
    \DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram 
       (.ADDRARDADDR({1'b1,addra,1'b1,1'b1,1'b1}),
        .ADDRBWRADDR({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .CASCADEINA(1'b0),
        .CASCADEINB(1'b0),
        .CASCADEOUTA(\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_CASCADEOUTA_UNCONNECTED ),
        .CASCADEOUTB(\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_CASCADEOUTB_UNCONNECTED ),
        .CLKARDCLK(clka),
        .CLKBWRCLK(clka),
        .DBITERR(\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_DBITERR_UNCONNECTED ),
        .DIADI({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .DIBDI({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .DIPADIP({1'b0,1'b0,1'b0,1'b0}),
        .DIPBDIP({1'b0,1'b0,1'b0,1'b0}),
        .DOADO({\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_DOADO_UNCONNECTED [31:8],douta}),
        .DOBDO(\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_DOBDO_UNCONNECTED [31:0]),
        .DOPADOP({\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_DOPADOP_UNCONNECTED [3:1],\DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_n_71 }),
        .DOPBDOP(\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_DOPBDOP_UNCONNECTED [3:0]),
        .ECCPARITY(\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_ECCPARITY_UNCONNECTED [7:0]),
        .ENARDEN(ena),
        .ENBWREN(1'b0),
        .INJECTDBITERR(1'b0),
        .INJECTSBITERR(1'b0),
        .RDADDRECC(\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_RDADDRECC_UNCONNECTED [8:0]),
        .REGCEAREGCE(ena),
        .REGCEB(1'b0),
        .RSTRAMARSTRAM(1'b0),
        .RSTRAMB(1'b0),
        .RSTREGARSTREG(1'b0),
        .RSTREGB(1'b0),
        .SBITERR(\NLW_DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram_SBITERR_UNCONNECTED ),
        .WEA({1'b0,1'b0,1'b0,1'b0}),
        .WEBWE({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}));
endmodule

(* ORIG_REF_NAME = "blk_mem_gen_top" *) 
module blk_mem_gen_log2_12bit_blk_mem_gen_top
   (douta,
    clka,
    ena,
    addra);
  output [7:0]douta;
  input clka;
  input ena;
  input [11:0]addra;

  wire [11:0]addra;
  wire clka;
  wire [7:0]douta;
  wire ena;

  blk_mem_gen_log2_12bit_blk_mem_gen_generic_cstr \valid.cstr 
       (.addra(addra),
        .clka(clka),
        .douta(douta),
        .ena(ena));
endmodule

(* C_ADDRA_WIDTH = "12" *) (* C_ADDRB_WIDTH = "12" *) (* C_ALGORITHM = "1" *) 
(* C_AXI_ID_WIDTH = "4" *) (* C_AXI_SLAVE_TYPE = "0" *) (* C_AXI_TYPE = "1" *) 
(* C_BYTE_SIZE = "9" *) (* C_COMMON_CLK = "0" *) (* C_COUNT_18K_BRAM = "0" *) 
(* C_COUNT_36K_BRAM = "1" *) (* C_CTRL_ECC_ALGO = "NONE" *) (* C_DEFAULT_DATA = "0" *) 
(* C_DISABLE_WARN_BHV_COLL = "0" *) (* C_DISABLE_WARN_BHV_RANGE = "0" *) (* C_ELABORATION_DIR = "./" *) 
(* C_ENABLE_32BIT_ADDRESS = "0" *) (* C_EN_DEEPSLEEP_PIN = "0" *) (* C_EN_ECC_PIPE = "0" *) 
(* C_EN_RDADDRA_CHG = "0" *) (* C_EN_RDADDRB_CHG = "0" *) (* C_EN_SAFETY_CKT = "0" *) 
(* C_EN_SHUTDOWN_PIN = "0" *) (* C_EN_SLEEP_PIN = "0" *) (* C_EST_POWER_SUMMARY = "Estimated Power for IP     :     2.326399 mW" *) 
(* C_FAMILY = "artix7" *) (* C_HAS_AXI_ID = "0" *) (* C_HAS_ENA = "1" *) 
(* C_HAS_ENB = "0" *) (* C_HAS_INJECTERR = "0" *) (* C_HAS_MEM_OUTPUT_REGS_A = "1" *) 
(* C_HAS_MEM_OUTPUT_REGS_B = "0" *) (* C_HAS_MUX_OUTPUT_REGS_A = "0" *) (* C_HAS_MUX_OUTPUT_REGS_B = "0" *) 
(* C_HAS_REGCEA = "0" *) (* C_HAS_REGCEB = "0" *) (* C_HAS_RSTA = "0" *) 
(* C_HAS_RSTB = "0" *) (* C_HAS_SOFTECC_INPUT_REGS_A = "0" *) (* C_HAS_SOFTECC_OUTPUT_REGS_B = "0" *) 
(* C_INITA_VAL = "0" *) (* C_INITB_VAL = "0" *) (* C_INIT_FILE = "blk_mem_gen_log2_12bit.mem" *) 
(* C_INIT_FILE_NAME = "blk_mem_gen_log2_12bit.mif" *) (* C_INTERFACE_TYPE = "0" *) (* C_LOAD_INIT_FILE = "1" *) 
(* C_MEM_TYPE = "3" *) (* C_MUX_PIPELINE_STAGES = "0" *) (* C_PRIM_TYPE = "1" *) 
(* C_READ_DEPTH_A = "4096" *) (* C_READ_DEPTH_B = "4096" *) (* C_READ_WIDTH_A = "8" *) 
(* C_READ_WIDTH_B = "8" *) (* C_RSTRAM_A = "0" *) (* C_RSTRAM_B = "0" *) 
(* C_RST_PRIORITY_A = "CE" *) (* C_RST_PRIORITY_B = "CE" *) (* C_SIM_COLLISION_CHECK = "ALL" *) 
(* C_USE_BRAM_BLOCK = "0" *) (* C_USE_BYTE_WEA = "0" *) (* C_USE_BYTE_WEB = "0" *) 
(* C_USE_DEFAULT_DATA = "0" *) (* C_USE_ECC = "0" *) (* C_USE_SOFTECC = "0" *) 
(* C_USE_URAM = "0" *) (* C_WEA_WIDTH = "1" *) (* C_WEB_WIDTH = "1" *) 
(* C_WRITE_DEPTH_A = "4096" *) (* C_WRITE_DEPTH_B = "4096" *) (* C_WRITE_MODE_A = "WRITE_FIRST" *) 
(* C_WRITE_MODE_B = "WRITE_FIRST" *) (* C_WRITE_WIDTH_A = "8" *) (* C_WRITE_WIDTH_B = "8" *) 
(* C_XDEVICEFAMILY = "artix7" *) (* ORIG_REF_NAME = "blk_mem_gen_v8_4_1" *) (* downgradeipidentifiedwarnings = "yes" *) 
module blk_mem_gen_log2_12bit_blk_mem_gen_v8_4_1
   (clka,
    rsta,
    ena,
    regcea,
    wea,
    addra,
    dina,
    douta,
    clkb,
    rstb,
    enb,
    regceb,
    web,
    addrb,
    dinb,
    doutb,
    injectsbiterr,
    injectdbiterr,
    eccpipece,
    sbiterr,
    dbiterr,
    rdaddrecc,
    sleep,
    deepsleep,
    shutdown,
    rsta_busy,
    rstb_busy,
    s_aclk,
    s_aresetn,
    s_axi_awid,
    s_axi_awaddr,
    s_axi_awlen,
    s_axi_awsize,
    s_axi_awburst,
    s_axi_awvalid,
    s_axi_awready,
    s_axi_wdata,
    s_axi_wstrb,
    s_axi_wlast,
    s_axi_wvalid,
    s_axi_wready,
    s_axi_bid,
    s_axi_bresp,
    s_axi_bvalid,
    s_axi_bready,
    s_axi_arid,
    s_axi_araddr,
    s_axi_arlen,
    s_axi_arsize,
    s_axi_arburst,
    s_axi_arvalid,
    s_axi_arready,
    s_axi_rid,
    s_axi_rdata,
    s_axi_rresp,
    s_axi_rlast,
    s_axi_rvalid,
    s_axi_rready,
    s_axi_injectsbiterr,
    s_axi_injectdbiterr,
    s_axi_sbiterr,
    s_axi_dbiterr,
    s_axi_rdaddrecc);
  input clka;
  input rsta;
  input ena;
  input regcea;
  input [0:0]wea;
  input [11:0]addra;
  input [7:0]dina;
  output [7:0]douta;
  input clkb;
  input rstb;
  input enb;
  input regceb;
  input [0:0]web;
  input [11:0]addrb;
  input [7:0]dinb;
  output [7:0]doutb;
  input injectsbiterr;
  input injectdbiterr;
  input eccpipece;
  output sbiterr;
  output dbiterr;
  output [11:0]rdaddrecc;
  input sleep;
  input deepsleep;
  input shutdown;
  output rsta_busy;
  output rstb_busy;
  input s_aclk;
  input s_aresetn;
  input [3:0]s_axi_awid;
  input [31:0]s_axi_awaddr;
  input [7:0]s_axi_awlen;
  input [2:0]s_axi_awsize;
  input [1:0]s_axi_awburst;
  input s_axi_awvalid;
  output s_axi_awready;
  input [7:0]s_axi_wdata;
  input [0:0]s_axi_wstrb;
  input s_axi_wlast;
  input s_axi_wvalid;
  output s_axi_wready;
  output [3:0]s_axi_bid;
  output [1:0]s_axi_bresp;
  output s_axi_bvalid;
  input s_axi_bready;
  input [3:0]s_axi_arid;
  input [31:0]s_axi_araddr;
  input [7:0]s_axi_arlen;
  input [2:0]s_axi_arsize;
  input [1:0]s_axi_arburst;
  input s_axi_arvalid;
  output s_axi_arready;
  output [3:0]s_axi_rid;
  output [7:0]s_axi_rdata;
  output [1:0]s_axi_rresp;
  output s_axi_rlast;
  output s_axi_rvalid;
  input s_axi_rready;
  input s_axi_injectsbiterr;
  input s_axi_injectdbiterr;
  output s_axi_sbiterr;
  output s_axi_dbiterr;
  output [11:0]s_axi_rdaddrecc;

  wire \<const0> ;
  wire [11:0]addra;
  wire clka;
  wire [7:0]douta;
  wire ena;

  assign dbiterr = \<const0> ;
  assign doutb[7] = \<const0> ;
  assign doutb[6] = \<const0> ;
  assign doutb[5] = \<const0> ;
  assign doutb[4] = \<const0> ;
  assign doutb[3] = \<const0> ;
  assign doutb[2] = \<const0> ;
  assign doutb[1] = \<const0> ;
  assign doutb[0] = \<const0> ;
  assign rdaddrecc[11] = \<const0> ;
  assign rdaddrecc[10] = \<const0> ;
  assign rdaddrecc[9] = \<const0> ;
  assign rdaddrecc[8] = \<const0> ;
  assign rdaddrecc[7] = \<const0> ;
  assign rdaddrecc[6] = \<const0> ;
  assign rdaddrecc[5] = \<const0> ;
  assign rdaddrecc[4] = \<const0> ;
  assign rdaddrecc[3] = \<const0> ;
  assign rdaddrecc[2] = \<const0> ;
  assign rdaddrecc[1] = \<const0> ;
  assign rdaddrecc[0] = \<const0> ;
  assign rsta_busy = \<const0> ;
  assign rstb_busy = \<const0> ;
  assign s_axi_arready = \<const0> ;
  assign s_axi_awready = \<const0> ;
  assign s_axi_bid[3] = \<const0> ;
  assign s_axi_bid[2] = \<const0> ;
  assign s_axi_bid[1] = \<const0> ;
  assign s_axi_bid[0] = \<const0> ;
  assign s_axi_bresp[1] = \<const0> ;
  assign s_axi_bresp[0] = \<const0> ;
  assign s_axi_bvalid = \<const0> ;
  assign s_axi_dbiterr = \<const0> ;
  assign s_axi_rdaddrecc[11] = \<const0> ;
  assign s_axi_rdaddrecc[10] = \<const0> ;
  assign s_axi_rdaddrecc[9] = \<const0> ;
  assign s_axi_rdaddrecc[8] = \<const0> ;
  assign s_axi_rdaddrecc[7] = \<const0> ;
  assign s_axi_rdaddrecc[6] = \<const0> ;
  assign s_axi_rdaddrecc[5] = \<const0> ;
  assign s_axi_rdaddrecc[4] = \<const0> ;
  assign s_axi_rdaddrecc[3] = \<const0> ;
  assign s_axi_rdaddrecc[2] = \<const0> ;
  assign s_axi_rdaddrecc[1] = \<const0> ;
  assign s_axi_rdaddrecc[0] = \<const0> ;
  assign s_axi_rdata[7] = \<const0> ;
  assign s_axi_rdata[6] = \<const0> ;
  assign s_axi_rdata[5] = \<const0> ;
  assign s_axi_rdata[4] = \<const0> ;
  assign s_axi_rdata[3] = \<const0> ;
  assign s_axi_rdata[2] = \<const0> ;
  assign s_axi_rdata[1] = \<const0> ;
  assign s_axi_rdata[0] = \<const0> ;
  assign s_axi_rid[3] = \<const0> ;
  assign s_axi_rid[2] = \<const0> ;
  assign s_axi_rid[1] = \<const0> ;
  assign s_axi_rid[0] = \<const0> ;
  assign s_axi_rlast = \<const0> ;
  assign s_axi_rresp[1] = \<const0> ;
  assign s_axi_rresp[0] = \<const0> ;
  assign s_axi_rvalid = \<const0> ;
  assign s_axi_sbiterr = \<const0> ;
  assign s_axi_wready = \<const0> ;
  assign sbiterr = \<const0> ;
  GND GND
       (.G(\<const0> ));
  blk_mem_gen_log2_12bit_blk_mem_gen_v8_4_1_synth inst_blk_mem_gen
       (.addra(addra),
        .clka(clka),
        .douta(douta),
        .ena(ena));
endmodule

(* ORIG_REF_NAME = "blk_mem_gen_v8_4_1_synth" *) 
module blk_mem_gen_log2_12bit_blk_mem_gen_v8_4_1_synth
   (douta,
    clka,
    ena,
    addra);
  output [7:0]douta;
  input clka;
  input ena;
  input [11:0]addra;

  wire [11:0]addra;
  wire clka;
  wire [7:0]douta;
  wire ena;

  blk_mem_gen_log2_12bit_blk_mem_gen_top \gnbram.gnativebmg.native_blk_mem_gen 
       (.addra(addra),
        .clka(clka),
        .douta(douta),
        .ena(ena));
endmodule
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

endmodule
`endif
