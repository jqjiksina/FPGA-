//`define DDR3
`undef DDR3
module top#(
    //ethernet
    parameter       SEND_DATA_WIDTH = 16'd1024    ,
    parameter       LOCAL_MAC = 48'ha0_b1_c2_d3_e1_e1,
    parameter       LOCAL_IP  = 32'hC0_A8_01_0B,//192.168.1.11
    parameter       LOCL_PORT = 16'h1F90,
    parameter       DEST_IP   = 32'hC0_A8_01_69,//192.168.1.105
    parameter       DEST_PORT = 16'h1F90,
    `ifdef DDR3
    //ddr
    parameter DFI_CLK_PERIOD       = 10000         ,
    parameter MEM_ROW_WIDTH   = 15         ,
    parameter MEM_COLUMN_WIDTH   = 10         ,
    parameter MEM_BANK_WIDTH      = 3          ,
    parameter MEM_DQ_WIDTH         =  32         ,
    parameter MEM_DM_WIDTH         =  4         ,
    parameter MEM_DQS_WIDTH        =  4         ,
    parameter REGION_NUM           =  3         ,
    parameter CTRL_ADDR_WIDTH      = MEM_ROW_WIDTH + MEM_COLUMN_WIDTH + MEM_BANK_WIDTH,
    parameter MEM_SPACE_AW        =    18,
    `endif
    //hdmi
    parameter   X_WIDTH = 4'd12,
    parameter   Y_WIDTH = 4'd12,   
    //--MODE_1080p
    parameter V_TOTAL = 12'd1125,
    parameter V_FP = 12'd4,
    parameter V_BP = 12'd36,
    parameter V_SYNC = 12'd5,
    parameter V_ACT = 12'd1080,
    parameter H_TOTAL = 12'd2200,
    parameter H_FP = 12'd88,
    parameter H_BP = 12'd148,
    parameter H_SYNC = 12'd44,
    parameter H_ACT = 12'd1920,
    parameter HV_OFFSET = 12'd0,
    parameter RSTN_TIME = 16'h2710
)(
    //common
    input                              clk_50m,
    input                              rst_n ,

    //key ctrl
    input                              btn_hdmi           ,
    input                              btn_ethernet       ,
    input                              btn_ad             ,
                                       
    //ethernet                         
    output reg                         led,
    output                             phy_rstn,
                                       
    input                              rgmii_rxc,
    input                              rgmii_rx_ctl,
    input [3:0]                        rgmii_rxd,
                                       
    output                             rgmii_txc,
    output                             rgmii_tx_ctl,
    output [3:0]                       rgmii_txd ,

    //adda
    output                             ad_clk /* synthesis PAP_MARK_DEBUG="true" */,
    input  [7:0]                       ad_data /* synthesis PAP_MARK_DEBUG="true" */,
    output [7:0]                       da_data /* synthesis PAP_MARK_DEBUG="true" */,
    output                             da_clk/* synthesis PAP_MARK_DEBUG="true" */,

    //hdmi in
    output                             rstn_out,
    output                             iic_scl,
    inout                              iic_sda, 
    output                             iic_tx_scl,
    inout                              iic_tx_sda, 
    input wire                         pix_clk_in      ,//HDMI输入时钟 1080p @148.5Mhz
    input wire                         vs_in           /* synthesis PAP_MARK_DEBUG="1" */,//帧同步
    input wire                         hs_in           ,//行同步
    input wire                         de_in           /* synthesis PAP_MARK_DEBUG="1" */,//数据有效信号
    input wire [7 : 0]                 r_in            /* synthesis PAP_MARK_DEBUG="1" */,
    input wire [7 : 0]                 g_in            /* synthesis PAP_MARK_DEBUG="1" */,
    input wire [7 : 0]                 b_in            /* synthesis PAP_MARK_DEBUG="1" */

    `ifdef DDR3
    ,
    //ddr
    output                             mem_rst_n            ,                       
    output                             mem_ck               ,
    output                             mem_ck_n             ,
    output                             mem_cke              ,
    output                             mem_cs_n             ,
    output                             mem_ras_n            ,
    output                             mem_cas_n            ,
    output                             mem_we_n             , 
    output                             mem_odt              ,
    output [MEM_ROW_WIDTH-1:0]         mem_a                ,   
    output [MEM_BANK_WIDTH-1:0]        mem_ba               ,   
    inout [MEM_DQS_WIDTH-1:0]          mem_dqs              ,
    inout [MEM_DQS_WIDTH-1:0]          mem_dqs_n            ,
    inout [MEM_DQ_WIDTH-1:0]           mem_dq               ,
    output [MEM_DM_WIDTH-1:0]          mem_dm               ,
    //ddr-debug
    output                             ddr_init_done        ,
    output                             heart_beat_led       
    `endif
   );
//======================ddr-axi BEGIN======================
wire                             core_clk_rst_n       ;
wire                             core_clk             ;

`ifdef DDR3
wire [CTRL_ADDR_WIDTH-1:0]       axi_awaddr           /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]                       axi_awlen           /* synthesis PAP_MARK_DEBUG="true" */ ;
wire                             axi_awready          /* synthesis PAP_MARK_DEBUG="true" */;
wire                             axi_awvalid         /* synthesis PAP_MARK_DEBUG="true" */ ;

wire [MEM_DQ_WIDTH*8-1:0]        axi_wdata           /* synthesis PAP_MARK_DEBUG="true" */ ;
wire                             axi_wready           /* synthesis PAP_MARK_DEBUG="true" */;
wire                             axi_wusero_last    /* synthesis PAP_MARK_DEBUG="true" */;

wire [CTRL_ADDR_WIDTH-1:0]       axi_araddr           /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]                       axi_arlen            /* synthesis PAP_MARK_DEBUG="true" */;
wire                             axi_arready          /* synthesis PAP_MARK_DEBUG="true" */;
wire                             axi_arvalid         /* synthesis PAP_MARK_DEBUG="true" */ ;

wire [MEM_DQ_WIDTH*8-1:0]        axi_rdata           /* synthesis PAP_MARK_DEBUG="true" */ ;
wire                             axi_rvalid          /* synthesis PAP_MARK_DEBUG="true" */ ;
wire                             axi_rlast        /* synthesis PAP_MARK_DEBUG="true" */;
`endif

//======================ddr-axi END======================

wire                             rgmii_clk;

//======================fifo BEGIN=========================
wire fifo_rst                    /* synthesis PAP_MARK_DEBUG="true" */;
// ad_fifo
wire  ad_fifo_wr_en            /* synthesis PAP_MARK_DEBUG="true" */;
wire ad_fifo_full            /* synthesis PAP_MARK_DEBUG="true" */;            
wire ad_fifo_empty            /* synthesis PAP_MARK_DEBUG="true" */;
wire ad_fifo_almost_empty    /* synthesis PAP_MARK_DEBUG="true" */;
//wire ad_fifo_almost_full    /* synthesis PAP_MARK_DEBUG="true" */;
wire[7:0] ad_fifo_rd_data    /* synthesis PAP_MARK_DEBUG="true" */;
wire[7:0] ad_fifo_wr_data    /* synthesis PAP_MARK_DEBUG="true" */;

assign ad_fifo_wr_data = ad_data;

// hdmi_fifo
wire  hdmi_fifo_wr_en        /* synthesis PAP_MARK_DEBUG="true" */;
wire hdmi_fifo_wr_full        /* synthesis PAP_MARK_DEBUG="true" */;
wire hdmi_fifo_almost_full    /* synthesis PAP_MARK_DEBUG="true" */;
wire hdmi_fifo_rd_empty            /* synthesis PAP_MARK_DEBUG="true" */;
wire hdmi_fifo_almost_empty    /* synthesis PAP_MARK_DEBUG="true" */;
wire[31:0] hdmi_fifo_rd_data    /* synthesis PAP_MARK_DEBUG="true" */;
wire[31:0] video_data_out        /* synthesis PAP_MARK_DEBUG="true" */;

// sig_ethernet_fifo
wire sig_eth_fifo_wr_en        /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] sig_eth_fifo_wr_data/* synthesis PAP_MARK_DEBUG="true" */;
wire sig_eth_fifo_wr_full        /* synthesis PAP_MARK_DEBUG="true" */;
wire sig_eth_fifo_almost_full    /* synthesis PAP_MARK_DEBUG="true" */;
wire sig_eth_fifo_rd_en        /* synthesis PAP_MARK_DEBUG="true" */;
wire [7:0] sig_eth_fifo_rd_data/* synthesis PAP_MARK_DEBUG="true" */;
wire sig_eth_fifo_rd_empty    /* synthesis PAP_MARK_DEBUG="true" */;
wire sig_eth_fifo_almost_empty/* synthesis PAP_MARK_DEBUG="true" */;

//assign output_valid = sig_eth_fifo_almost_full;
//======================fifo END==================================
//======================Ethernet BEGIN===========================
wire         mac_rx_data_valid;
wire [7:0]   mac_rx_data;    
wire         mac_data_valid;  
wire [7:0]   mac_tx_data;  
wire         udp_rec_data_valid;
wire [7:0]   udp_rec_rdata;      
wire [15:0]  udp_rec_data_length;

reg[31:0] cnt_timer;

assign phy_rstn = rstn;
assign led_test =  (udp_rec_data_valid== 1'b1 ? (|udp_rec_rdata) : (&udp_rec_data_length));
//======================Ethernet END===========================

function_switch key_switch(
    .clk(clk_50m),                         // 系统时钟                             input wire 
    .rst_n(rst_n),                         // 重置信号                             input wire 
                                                                                
    //功能切换信号（按钮）
    .btn_hdmi            (btn_hdmi            ), // HDMI模式按钮                         input wire 
    .btn_ethernet        (btn_ethernet        ), // 以太网模式按钮                          input wire 
    .btn_ad              (btn_ad              ), // AD模式按钮                           input wire 
                                                                             
    //HDMI FIFO接口
    .pix_clk                (pix_clk_in    ),
    .hdmi_fifo_data      (hdmi_fifo_rd_data      ), // HDMI FIFO数据输出,24位rgb数据           input wire 
    .hdmi_fifo_almost_empty(hdmi_fifo_almost_empty),
    .hdmi_fifo_rd_en     (hdmi_fifo_rd_en     ), // HDMI FIFO读取使能                    output reg 
    .hdmi_fifo_wr_en    (hdmi_fifo_wr_en    ),
    .hdmi_fifo_full        (hdmi_fifo_wr_full),
    
    //以太网接口                                                                        
    .rgmii_clk            (rgmii_clk    ),                                         
                                                                     
    //AD FIFO接口 
    .ad_clk              (ad_clk            ),
    .ad_fifo_data        (ad_fifo_rd_data        ), // AD FIFO数据输出                      input wire 
    .ad_fifo_full        (ad_fifo_full),
    .ad_fifo_almost_empty(ad_fifo_almost_empty    ),
    .ad_fifo_rd_en       (ad_fifo_rd_en       ),   // AD FIFO读取使能                      output reg 
    .ad_fifo_wr_en        (ad_fifo_wr_en    ),

    //sig_eth
    .sig_eth_fifo_wr_en    (sig_eth_fifo_wr_en),
    .sig_eth_fifo_wr_data    (sig_eth_fifo_wr_data),
    .sig_eth_fifo_wr_full    (sig_eth_fifo_wr_full),
    .sig_eth_fifo_almost_full(sig_eth_fifo_almost_full),
    .fifo_rst                (fifo_rst),
    .ad_valid                (ad_valid),
    .hdmi_valid                (hdmi_valid),
    .ethernet_valid            (ethernet_valid)
    );

adda adda(
   .clk_50M(clk_50m),
   .rst_n  (rst_n  ),
   .ad_clk (ad_clk ), 
   .da_data(da_data), 
   .da_clk (da_clk )
);

//通过fifo进行异步读写和位宽转换
fifo_buffer ad_fifo(
    .wr_clk(ad_clk),
    .wr_rst(!rst_n | !ad_valid),
    .wr_en(ad_fifo_wr_en),
    .wr_data(ad_fifo_wr_data),
    .wr_full(ad_fifo_full),

    .rd_clk(rgmii_clk),           //读位宽>=写位宽，同步fifo时钟
    .rd_rst(!rst_n | !ad_valid),
    .rd_en(ad_fifo_rd_en),
    .rd_data(ad_fifo_rd_data),
    .rd_empty(ad_fifo_empty),
    .almost_empty(ad_fifo_almost_empty)
);
hdmi_fifo hdmi_fifo (
  .wr_clk(pix_clk),                // input
  .wr_rst(!rst_n | !hdmi_valid),                // input
  .wr_en(de_out & hdmi_fifo_wr_en),                  // input
  .wr_data(video_data_out),       // input [31:0]
  .wr_full(hdmi_fifo_wr_full),              // output
  .almost_full(hdmi_fifo_almost_full),      // output

  .rd_clk(rgmii_clk),                // input
  .rd_rst(!rst_n | !hdmi_valid),      // input
  .rd_en(hdmi_fifo_rd_en),                  // input
  .rd_data(hdmi_fifo_rd_data),              // output [31:0]
  .rd_empty(hdmi_fifo_rd_empty),            // output
  .almost_empty(hdmi_fifo_almost_empty)     // output
);

sig_ethernet_fifo sig_eth_fifo (
  .rd_clk(rgmii_clk),                // input
  .wr_clk(rgmii_clk),
  .wr_rst(!rst_n | fifo_rst),                   // input
  .rd_rst(!rst_n | fifo_rst),
  .wr_en(sig_eth_fifo_wr_en),     // input
  .wr_data(sig_eth_fifo_wr_data),              // input [23:0]
  .wr_full(sig_eth_fifo_wr_full),              // output
  .almost_full(sig_eth_fifo_almost_full),     // output
  .rd_en(sig_eth_fifo_rd_en),                  // input
  .rd_data(sig_eth_fifo_rd_data),              // output [23:0]
  .rd_empty(sig_eth_fifo_rd_empty),            // output
  .almost_empty(sig_eth_fifo_almost_empty)     // output
);

`ifdef DDR3
//ddr
test_ddr ddr3(
    .clk_50m       (clk_50m       )  ,
    .rst_n         (rst_n         )  ,
    .pll_lock      (pll_lock      )  ,
    .ddr_init_done (ddr_init_done )  ,
                     
    .mem_rst_n (mem_rst_n)     ,
    .mem_ck    (mem_ck   )     ,
    .mem_ck_n  (mem_ck_n )     ,
    .mem_cke   (mem_cke  )     ,              
    .mem_cs_n  (mem_cs_n )     ,
                     
    .mem_ras_n      (mem_ras_n      ) ,
    .mem_cas_n      (mem_cas_n      ) ,
    .mem_we_n       (mem_we_n       ) ,
    .mem_odt        (mem_odt        ) ,
    .mem_a          (mem_a          ) ,
    .mem_ba         (mem_ba         ) ,
    .mem_dqs        (mem_dqs        ) ,
    .mem_dqs_n      (mem_dqs_n      ) ,
    .mem_dq         (mem_dq         ) ,
    .mem_dm         (mem_dm         ) ,

    .heart_beat_led (heart_beat_led ) ,
    .err_flag_led   (err_flag_led   ) ,

    // for ddr control
    .core_clk               (core_clk               ),
    .core_clk_rst_n         (core_clk_rst_n         ),
    .ddr_init_done          (ddr_init_done          ),
                                                      
    .axi_awaddr             (axi_awaddr             ),
    .axi_awlen              (axi_awlen              ),
    .axi_awready            (axi_awready            ),
    .axi_awvalid            (axi_awvalid            ),
                                                      
    .axi_wdata              (axi_wdata              ),
    .axi_wready             (axi_wready             ),
    .axi_wusero_last        (axi_wusero_last        ),
                                                      
    .axi_araddr             (axi_araddr             ),
    .axi_arlen              (axi_arlen              ),
    .axi_arready            (axi_arready            ),
    .axi_arvalid            (axi_arvalid            ),
                                                      
    .axi_rdata              (axi_rdata              ),
    .axi_rlast              (axi_rlast              ),
    .axi_rvalid             (axi_rvalid             ) 
);

//ddr control
ddr_ctrl #(
    .CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH),
    .MEM_DQ_WIDTH(MEM_DQ_WIDTH),
    .MEM_SPACE_AW(MEM_SPACE_AW)
)ddr_ctrl(
   .core_clk               (core_clk               ),
   .core_clk_rst_n         (core_clk_rst_n         ),
   .ddr_init_done          (ddr_init_done          ),

   .axi_awaddr             (axi_awaddr             ),
   .axi_awlen              (axi_awlen              ),
   .axi_awready            (axi_awready            ),
   .axi_awvalid            (axi_awvalid            ),

   .axi_wdata              (axi_wdata              ),
   .axi_wready             (axi_wready             ),
   .axi_wusero_last        (axi_wusero_last        ),

   .axi_araddr             (axi_araddr             ),
   .axi_arlen              (axi_arlen              ),
   .axi_arready            (axi_arready            ),
   .axi_arvalid            (axi_arvalid            ),

   .axi_rdata              (axi_rdata              ),
   .axi_rlast              (axi_rlast              ),
   .axi_rvalid             (axi_rvalid             )
);
`endif
//For Ethernet           
wire clk_125m;

ref_clock ref_clock(
    .clkout1 ( clk_125m  ), // output clk_out2
    .pll_lock( rstn      ), // output locked
    .clkin1  ( clk_50m   )  // input clk_in1
);
    
eth_udp_test #(
    .LOCAL_MAC                (LOCAL_MAC               ),// 48'h11_11_11_11_11_11,
    .LOCAL_IP                 (LOCAL_IP                ),// 32'hC0_A8_01_6E,//192.168.1.110
    .LOCL_PORT                (LOCL_PORT               ),// 16'h8080,
                                                       
    .DEST_IP                  (DEST_IP                 ),// 32'hC0_A8_01_69,//192.168.1.105
    .DEST_PORT                (DEST_PORT               ) // 16'h8080 
)eth_udp_test(
    .rgmii_clk              (  rgmii_clk            ),//input                rgmii_clk,
    .rstn                   (  rstn                 ),//input                rstn,
    .gmii_rx_dv             (  mac_rx_data_valid    ),//input                gmii_rx_dv,
    .gmii_rxd               (  mac_rx_data          ),//input  [7:0]         gmii_rxd,
    .gmii_tx_en             (  mac_data_valid       ),//output reg           gmii_tx_en,
    .gmii_txd               (  mac_tx_data          ),//output reg [7:0]     gmii_txd,
                                                  
    .udp_rec_data_valid     (  udp_rec_data_valid   ),//output               udp_rec_data_valid,
    .udp_rec_rdata          (  udp_rec_rdata        ),//output [7:0]         udp_rec_rdata ,             
    .udp_rec_data_length    (  udp_rec_data_length  ),//output [15:0]        udp_rec_data_length     
    .sig_eth_fifo_rd_data     (sig_eth_fifo_rd_data),
    .sig_eth_fifo_rd_en       (sig_eth_fifo_rd_en),
    .sig_eth_fifo_almost_full (sig_eth_fifo_almost_full),
    .ethernet_loop            (ethernet_valid        )
    //.output_valid             (output_valid         )
);

rgmii_interface rgmii_interface(
    .rst                       (  ~rstn              ),//input        rst,
    .rgmii_clk                 (  rgmii_clk          ),//output       rgmii_clk,
    .rgmii_clk_90p             (  rgmii_clk_90p      ),//input        rgmii_clk_90p,

    .mac_tx_data_valid         (  mac_data_valid     ),//input        mac_tx_data_valid,
    .mac_tx_data               (  mac_tx_data        ),//input [7:0]  mac_tx_data,

    .mac_rx_error              (                     ),//output       mac_rx_error,
    .mac_rx_data_valid         (  mac_rx_data_valid  ),//output       mac_rx_data_valid,
    .mac_rx_data               (  mac_rx_data        ),//output [7:0] mac_rx_data,
                                                     
    .rgmii_rxc                 (  rgmii_rxc          ),//input        rgmii_rxc,
    .rgmii_rx_ctl              (  rgmii_rx_ctl       ),//input        rgmii_rx_ctl,
    .rgmii_rxd                 (  rgmii_rxd          ),//input [3:0]  rgmii_rxd,
                                                     
    .rgmii_txc                 (  rgmii_txc          ),//output       rgmii_txc,
    .rgmii_tx_ctl              (  rgmii_tx_ctl       ),//output       rgmii_tx_ctl,
    .rgmii_txd                 (  rgmii_txd          ) //output [3:0] rgmii_txd 
);

//test led
always @(posedge rgmii_rxc)begin
    cnt_timer<=cnt_timer+1'b1;
    if( cnt_timer==32'h1_fff_fff) begin
       led=~led;
       cnt_timer<=32'h0;
    end
end

//ms72xx-pll
ms72xx_pll hdmi_pll (
  .clkin1(clk_50m),        // input
  .pll_lock(ms72xx_pll_lock),    // output
  .clkout0(ms72xx_cfg_clk)       // output
);
//ms72xx初始化
ms72xx_ctl ms72xx_ctl(
        .clk         (  ms72xx_cfg_clk    ), //input       clk,
        .rst_n       (  rstn_out   ), //input       rstn,
                                
        .init_over   (           ), //output      init_over,
        .iic_tx_scl  (  iic_tx_scl ), //output      iic_scl,
        .iic_tx_sda  (  iic_tx_sda ), //inout       iic_sda
        .iic_scl     (  iic_scl    ), //output      iic_scl,
        .iic_sda     (  iic_sda    )  //inout       iic_sda
    );
reg [15:0]  rstn_1ms;
always @(posedge ms72xx_cfg_clk) begin
    if(!ms72xx_pll_lock)
        rstn_1ms <= 16'd0;
    else begin
    	if(rstn_1ms == RSTN_TIME)
    	    rstn_1ms <= rstn_1ms;
    	else
    	    rstn_1ms <= rstn_1ms + 1'b1;
    end
end 
assign rstn_out = (rstn_1ms == RSTN_TIME) & hdmi_valid;    //给ms72xx复位

//hdmi zoom
video_zoom hdmi_eth_zoom(
    .clk(pix_clk_in),                  // input
    .rstn(rst_n | hdmi_valid),                      // input
    .vs_in(vs_in),                    // input
    .hs_in(hs_in),                    // input
    .de_in(de_in),                    // input
    .video_data_in({r_in,2'b0,g_in,2'b0,b_in,4'b0}),    // input[31:0]
    .de_out(de_out),                  // output
    .video_data_out(video_data_out)   // output[31:0]
);

endmodule