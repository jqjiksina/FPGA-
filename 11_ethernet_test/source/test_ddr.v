// Created by IP Generator (Version 2022.1 build 99559)
/// test_ddr模块：负责将ddr的ip和ddr读写控制模块耦合


`timescale 1ns/1ps

`define DDR3

module test_ddr #(
  parameter MEM_ROW_ADDR_WIDTH   = 15         ,
  parameter MEM_COL_ADDR_WIDTH   = 10         ,
  parameter MEM_BADDR_WIDTH      = 3         ,
  parameter MEM_DQ_WIDTH         =  32         ,
  parameter MEM_DM_WIDTH         = MEM_DQ_WIDTH/8,
  parameter MEM_DQS_WIDTH        = MEM_DQ_WIDTH/8,
  parameter CTRL_ADDR_WIDTH      = MEM_ROW_ADDR_WIDTH + MEM_BADDR_WIDTH + MEM_COL_ADDR_WIDTH
)(
  input                                  clk_50m         ,
  input                                  rst_n       ,
  output                                 pll_lock        ,           
  output                                 ddr_init_done   ,

  output                                 mem_rst_n       ,                       
  output                                 mem_ck          ,
  output                                 mem_ck_n        ,
  output                                 mem_cke         ,

  output                                 mem_cs_n        ,

  output                                 mem_ras_n       ,
  output                                 mem_cas_n       ,
  output                                 mem_we_n        ,  
  output                                 mem_odt         ,
  output     [MEM_ROW_ADDR_WIDTH-1:0]    mem_a           ,   
  output     [MEM_BADDR_WIDTH-1:0]       mem_ba          ,   
  inout      [MEM_DQS_WIDTH-1:0]         mem_dqs         ,
  inout      [MEM_DQS_WIDTH-1:0]         mem_dqs_n       ,
  inout      [MEM_DQ_WIDTH-1:0]          mem_dq          ,
  output     [MEM_DM_WIDTH-1:0]          mem_dm          , 
  output reg                             heart_beat_led  ,
  output                                 err_flag_led    ,
  /* for ddr_ctrl module BEGIN*/
  //sys                                                   
  output                                 core_clk,                                         
  output                                 core_clk_rst_n,                                                                      
  //axi                                                   
  input  [CTRL_ADDR_WIDTH-1:0]           axi_awaddr,     
  input  [3:0]                           axi_awlen,      
  output                                 axi_awready,    
  input                                  axi_awvalid,    
                                                         
  input  [MEM_DQ_WIDTH*8-1:0]            axi_wdata,      
  output                                 axi_wready,     
  output                                 axi_wusero_last,
                                                         
  input  [CTRL_ADDR_WIDTH-1:0]           axi_araddr,     
  input  [3:0]                           axi_arlen,      
  output                                 axi_arready,    
  input                                  axi_arvalid,    
                                                         
  output [8*MEM_DQ_WIDTH-1:0]            axi_rdata,      
  output                                 axi_rlast,      
  output                                 axi_rvalid      
  /* for ddr_ctrl module END*/
);

parameter MEM_SPACE_AW = CTRL_ADDR_WIDTH;
parameter TH_1S         = 27'd50_000_000;
parameter TH_4MS        = 27'd200_000;

reg  [26:0]                      cnt                       ;

wire [7:0]                       ck_dly_set_bin            ;
wire                             force_ck_dly_en           ;
wire [7:0]                       force_ck_dly_set_bin      ;
wire [7:0]                       dll_step                  ;     
wire                             dll_lock                  ;      

wire [1:0]                       init_read_clk_ctrl        ;                                         
wire [3:0]                       init_slip_step            ;                                                
wire                             force_read_clk_ctrl       ;    
wire                             ddrphy_gate_update_en     ;

wire [34*MEM_DQS_WIDTH-1:0]      debug_data                ;
wire [13*MEM_DQS_WIDTH-1:0]      debug_slice_state         ;
wire [34*4-1:0]                  status_debug_data         ;
wire [13*4-1:0 ]                 status_debug_slice_state  ;

wire                             rd_fake_stop              ;
wire                             bist_run_led              ;

reg [2:0]   rst_board_dly;  
reg [26:0]  cnt_rst   ;
reg         rst_board_rg = 1'b1;

wire   resetn;
assign resetn = rst_n;

always @(posedge clk_50m)
begin
  rst_board_dly <= {rst_board_dly[1:0],rst_n};    
end

always @(posedge clk_50m)
begin
  if (!rst_board_dly[2] && rst_board_dly[1]) begin
    cnt_rst <= 0;
    rst_board_rg <= 1'b1;
  end 
  else begin
  	if(!rst_board_dly[2])begin  		
  		if(cnt_rst == TH_4MS) begin
  			rst_board_rg <= 1'b0;
  		end 
  		else begin
  			cnt_rst <= cnt_rst + 1'b1;
  		end 
  	end 
  end      
end

always@(posedge core_clk or negedge resetn)
begin
   if (!resetn)
      cnt <= 27'd0;
   else if ( cnt >= TH_1S )
      cnt <= 27'd0;
   else
      cnt <= cnt + 27'd1;
end

always @(posedge core_clk or negedge resetn)
begin
   if (!resetn)
      heart_beat_led <= 1'd1;
   else if ( cnt >= TH_1S )
      heart_beat_led <= ~heart_beat_led;
end

ipsxb_rst_sync_v1_1 u_core_clk_rst_sync(
    .clk                        (core_clk        ),
    .rst_n                      (resetn          ),
    .sig_async                  (1'b1),
    .sig_synced                 (core_clk_rst_n  )
);

    //ddr core
ddr_test  #
  (
   //***************************************************************************
   // The following parameters are Memory Feature
   //***************************************************************************
   .MEM_ROW_WIDTH          (MEM_ROW_ADDR_WIDTH),     
   .MEM_COLUMN_WIDTH       (MEM_COL_ADDR_WIDTH),     
   .MEM_BANK_WIDTH         (MEM_BADDR_WIDTH   ),     
   .MEM_DQ_WIDTH           (MEM_DQ_WIDTH      ),     
   .MEM_DM_WIDTH           (MEM_DM_WIDTH      ),     
   .MEM_DQS_WIDTH          (MEM_DQS_WIDTH     ),     
   .CTRL_ADDR_WIDTH        (CTRL_ADDR_WIDTH   )     
  ) I_ipsxb_ddr_top(
   .ref_clk                (clk_50m                ),
   .resetn                 (resetn                 ),
   .ddr_init_done          (ddr_init_done          ),
   .ddrphy_clkin           (core_clk               ),
   .pll_lock               (pll_lock               ), 

   .axi_awaddr             (axi_awaddr             ),
   .axi_awuser_ap          ('d0                    ),
   .axi_awuser_id          ('d0                    ),
   .axi_awlen              (axi_awlen              ),
   .axi_awready            (axi_awready            ),
   .axi_awvalid            (axi_awvalid            ),

   .axi_wdata              (axi_wdata              ),
   .axi_wstrb              (32'hffff_ffff          ),
   .axi_wready             (axi_wready             ),
   .axi_wusero_id          (                       ),
   .axi_wusero_last        (axi_wusero_last        ),

   .axi_araddr             (axi_araddr             ),
   .axi_aruser_ap          ('d0                    ),
   .axi_aruser_id          ('d0                    ),
   .axi_arlen              (axi_arlen              ),
   .axi_arready            (axi_arready            ),
   .axi_arvalid            (axi_arvalid            ),

   .axi_rdata              (axi_rdata              ),
   .axi_rid                (                       ),
   .axi_rlast              (axi_rlast              ),
   .axi_rvalid             (axi_rvalid             ),

   .apb_clk                (1'b0                   ),
   .apb_rst_n              (1'b0                   ),
   .apb_sel                (1'b0                   ),
   .apb_enable             (1'b0                   ),
   .apb_addr               (8'd0                   ),
   .apb_write              (1'b0                   ),
   .apb_ready              (                       ),
   .apb_wdata              (16'd0                  ),
   .apb_rdata              (                       ),
   .apb_int                (                       ),
   .debug_data             (debug_data             ),
   .debug_slice_state      (debug_slice_state      ),
   .debug_calib_ctrl       (debug_calib_ctrl       ),
   .ck_dly_set_bin         (ck_dly_set_bin         ),
   .force_ck_dly_en        (force_ck_dly_en        ),
   .force_ck_dly_set_bin   (force_ck_dly_set_bin   ),
   .dll_step               (dll_step               ),
   .dll_lock               (dll_lock               ),
   .init_read_clk_ctrl     (init_read_clk_ctrl     ),                                                       
   .init_slip_step         (init_slip_step         ), 
   .force_read_clk_ctrl    (force_read_clk_ctrl    ),  
   .ddrphy_gate_update_en  (ddrphy_gate_update_en  ),
   .update_com_val_err_flag (update_com_val_err_flag),
   .rd_fake_stop           (rd_fake_stop           ),

   .mem_rst_n              (mem_rst_n              ),
   .mem_ck                 (mem_ck                 ),
   .mem_ck_n               (mem_ck_n               ),
   .mem_cke                (mem_cke                ),

   .mem_cs_n               (mem_cs_n               ),

   .mem_ras_n              (mem_ras_n              ),
   .mem_cas_n              (mem_cas_n              ),
   .mem_we_n               (mem_we_n               ),
   .mem_odt                (mem_odt                ),
   .mem_a                  (mem_a                  ),
   .mem_ba                 (mem_ba                 ),
   .mem_dqs                (mem_dqs                ),
   .mem_dqs_n              (mem_dqs_n              ),
   .mem_dq                 (mem_dq                 ),
   .mem_dm                 (mem_dm                 )
  );

endmodule

