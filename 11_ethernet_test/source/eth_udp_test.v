`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/03/16 23:40:05
// Design Name: 
// Module Name: eth_udp_test
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module eth_udp_test#(
    parameter       LOCAL_MAC = 48'h11_11_11_11_11_11,
    parameter       LOCAL_IP  = 32'hC0_A8_01_6E,//192.168.1.110
    parameter       LOCL_PORT = 16'h8080,

    parameter       DEST_IP   = 32'hC0_A8_01_69,//192.168.1.105
    parameter       DEST_PORT = 16'h8080,

    parameter        SEND_DATA_WIDTH = 16'd1024,
    parameter        RCV_DATA_WIDTH = 16'd1024
)(
    input                rgmii_clk,
    input                rstn,
    input                gmii_rx_dv,
    input  [7:0]         gmii_rxd,
    output reg           gmii_tx_en,
    output reg [7:0]     gmii_txd,
                 
    output               udp_rec_data_valid,         
    output [7:0]         udp_rec_rdata ,             
    output [15:0]        udp_rec_data_length,

    input [7:0]           sig_eth_fifo_rd_data,
    output reg            sig_eth_fifo_rd_en,
    input                 sig_eth_fifo_almost_full,
    input                 sig_eth_fifo_almost_empty,
    input                 ethernet_loop    /* synthesis PAP_MARK_DEBUG="true" */
);
    
localparam UDP_WIDTH = 32 ;
localparam UDP_DEPTH = 5 ;

//ethernet fifo
wire eth_fifo_wr_en;
reg r_eth_fifo_wr_en        /* synthesis PAP_MARK_DEBUG="true" */;
wire eth_fifo_full            /* synthesis PAP_MARK_DEBUG="true" */;
wire eth_fifo_almost_full    /* synthesis PAP_MARK_DEBUG="true" */;
wire eth_fifo_empty        /* synthesis PAP_MARK_DEBUG="true" */;
wire eth_fifo_almost_empty    /* synthesis PAP_MARK_DEBUG="true" */;
reg  eth_fifo_rd_en        /* synthesis PAP_MARK_DEBUG="true" */;
wire[7:0]eth_fifo_rd_data    /* synthesis PAP_MARK_DEBUG="true" */;
wire[7:0]eth_fifo_wr_data    /* synthesis PAP_MARK_DEBUG="true" */;
wire eth_fifo_rst        /* synthesis PAP_MARK_DEBUG="true" */;

reg ethernet_loop_ld;

assign eth_fifo_wr_en = ethernet_loop & udp_rec_data_valid | r_eth_fifo_wr_en;    //现象：最后一个字符读取
//assign eth_fifo_wr_en = r_eth_fifo_wr_en;            //现象：第一个读入不了
//assign eth_fifo_wr_en = ethernet_loop & udp_rec_data_valid;
assign eth_fifo_rst = ~rstn | ~ethernet_loop | write_end;
//assign eth_fifo_rst = ~rstn | ~ethernet_loop;
assign eth_fifo_wr_data = udp_rec_rdata;


reg   [7:0]          ram_wr_data             /* synthesis PAP_MARK_DEBUG="true" */;
reg                  ram_wr_en ;
wire                 udp_ram_data_req ;
reg [15:0]           udp_send_data_length    /* synthesis PAP_MARK_DEBUG="true" */;
  
wire                 udp_tx_req ;
wire                 arp_request_req ;
wire                 mac_send_end ;
reg                  write_end ;
reg                  read_end;

reg  [31:0]          wait_cnt ;

wire                 mac_not_exist ;
wire                 arp_found ;

parameter IDLE          = 10'b0000_000_001 ;
parameter ARP_REQ       = 10'b0000_000_010 ;
parameter ARP_SEND      = 10'b0000_000_100 ;
parameter ARP_WAIT      = 10'b0000_001_000 ;
parameter GEN_REQ       = 10'b0000_010_000 ;
parameter WRITE_RAM     = 10'b0000_100_000 ;
parameter SEND          = 10'b0001_000_000 ;
parameter WAIT          = 10'b0010_000_000 ;
parameter CHECK_ARP     = 10'b0100_000_000 ;
parameter READ_RAM      = 10'b1000_000_000 ;


parameter ONE_SECOND_CNT= 32'd125_000_000;//32'd12500;//

reg [9:0]    state          /* synthesis PAP_MARK_DEBUG="true" */;
reg [9:0]    state_n ;

always @(posedge rgmii_clk)
    if(~rstn)
        ethernet_loop_ld <= 1'b0;
    else
        ethernet_loop_ld <= ethernet_loop;    

always @(posedge rgmii_clk)    //将eth_fifo的写使能变为同步触发进行尝试。
    if(~rstn)
        r_eth_fifo_wr_en <= 1'b0;
    else if (ethernet_loop & udp_rec_data_valid)
        r_eth_fifo_wr_en <= 1'b1;
    else
        r_eth_fifo_wr_en <= 1'b0;

always @(posedge rgmii_clk)
begin
    if (~rstn)
        state  <=  IDLE  ;
    else if (ethernet_loop ^ ethernet_loop_ld == 1)    //检测ethernet_loop下降沿和上升沿，变化则重新进行arp解析
        state <= ARP_REQ;                            
    else
        state  <= state_n ;
end
      
always @(*)
begin
    case(state)
        IDLE        :
        begin
          if (wait_cnt == ONE_SECOND_CNT)
                state_n = ARP_REQ ;
            else
                state_n = IDLE ;
        end
        ARP_REQ     :
            state_n = ARP_SEND ;
        ARP_SEND    :
        begin
            if (mac_send_end)
                state_n = ARP_WAIT ;
            else
                state_n = ARP_SEND ;
        end
        ARP_WAIT    :
        begin
            if (arp_found)
                state_n = WAIT ;    //change
            else if (wait_cnt == ONE_SECOND_CNT)
                state_n = ARP_REQ ;
            else
                state_n = ARP_WAIT ;
        end
        GEN_REQ     :
        begin
            if (udp_ram_data_req)    //从机准备接收数据
                state_n = WRITE_RAM ;
            else
                state_n = GEN_REQ ;
        end
        WRITE_RAM   :
        begin
            if (write_end) 
                state_n = WAIT     ;
            else
                state_n = WRITE_RAM ;
        end
        SEND        :
        begin
            if (mac_send_end)
                state_n = WAIT ;
            else
                state_n = SEND ;
        end
        WAIT        :
        begin
		    //if (wait_cnt == ONE_SECOND_CNT)    //1s
            //if (sig_eth_fifo_almost_full == 1'b1 || wait_cnt == ONE_SECOND_CNT)
            if (!ethernet_loop && sig_eth_fifo_almost_full == 1'b1)
                state_n = CHECK_ARP ;
            else if (ethernet_loop && udp_rec_data_valid)    //可能有问题
                state_n = READ_RAM;
            else if (send_flag)
                state_n = CHECK_ARP;
            else
                state_n = WAIT ;
        end
        CHECK_ARP   :
        begin
            if (mac_not_exist)
                state_n = ARP_REQ ;
            else
                state_n = GEN_REQ ;
        end
        READ_RAM    :
        begin
            if (ethernet_loop & (read_end | send_flag))
                state_n = CHECK_ARP    ;    //如果是以太网回环模式，读完直接发送数据
            else if (!ethernet_loop)
                state_n = WAIT;
            else
                state_n = READ_RAM;
        end
        default     : state_n = IDLE ;
    endcase
end

reg send_flag;        //控制回环状态机的跳转条件，为1则需要发送数据，为0则发送完毕。
always @(posedge rgmii_clk)
    if (!rstn)
        send_flag <= 1'b0;
    else if (read_end)
        send_flag <= 1'b1;
    else if (write_end)
        send_flag <= 1'b0;

reg          gmii_rx_dv_1d;
reg  [7:0]   gmii_rxd_1d;
wire         gmii_tx_en_tmp;
wire [7:0]   gmii_txd_tmp;
    
always@(posedge rgmii_clk)
begin
    if(rstn == 1'b0)
    begin
        gmii_rx_dv_1d <= 1'b0 ;
        gmii_rxd_1d   <= 8'd0 ;
    end
    else
    begin
        gmii_rx_dv_1d <= gmii_rx_dv ;
        gmii_rxd_1d   <= gmii_rxd ;
    end
end
  
always@(posedge rgmii_clk)
begin
    if(rstn == 1'b0)
    begin
        gmii_tx_en <= 1'b0 ;
        gmii_txd   <= 8'd0 ;
    end
    else
    begin
        gmii_tx_en <= gmii_tx_en_tmp ;
        gmii_txd   <= gmii_txd_tmp ;
    end
end
    
udp_ip_mac_top#(
        .LOCAL_MAC                (LOCAL_MAC               ),// 48'h11_11_11_11_11_11,
        .LOCAL_IP                 (LOCAL_IP                ),// 32'hC0_A8_01_6E,//192.168.1.110
        .LOCL_PORT                (LOCL_PORT               ),// 16'h8080,
                                                           
        .DEST_IP                  (DEST_IP                 ),// 32'hC0_A8_01_69,//192.168.1.105
        .DEST_PORT                (DEST_PORT               ) // 16'h8080 
)udp_ip_mac_top(
        .rgmii_clk                (  rgmii_clk             ),//input           rgmii_clk,
        .rstn                     (  rstn                  ),//input           rstn,
  
        .app_data_in_valid        (  ram_wr_en             ),//input           app_data_in_valid,
        .app_data_in              (  ram_wr_data           ),//input   [7:0]   app_data_in,      
        .app_data_length          (  udp_send_data_length  ),//input   [15:0]  app_data_length,   
        .app_data_request         (  udp_tx_req            ),//input           app_data_request, 
                                                           
        .udp_send_ack             (  udp_ram_data_req      ),//output          udp_send_ack,   
                                                           
        .arp_req                  (  arp_request_req       ),//input           arp_req,
        .arp_found                (  arp_found             ),//output          arp_found,
        .mac_not_exist            (  mac_not_exist         ),//output          mac_not_exist, 
        .mac_send_end             (  mac_send_end          ),//output          mac_send_end,
        
        .udp_rec_rdata            (  udp_rec_rdata         ),//output  [7:0]   udp_rec_rdata ,      //udp ram read data   
        .udp_rec_data_length      (  udp_rec_data_length   ),//output  [15:0]  udp_rec_data_length,     //udp data length     
        .udp_rec_data_valid       (  udp_rec_data_valid    ),//output          udp_rec_data_valid,       //udp data valid      
        
        .mac_data_valid           (  gmii_tx_en_tmp        ),//output          mac_data_valid,
        .mac_tx_data              (  gmii_txd_tmp          ),//output  [7:0]   mac_tx_data,   
                                      
        .rx_en                    (  gmii_rx_dv_1d         ),//input           rx_en,         
        .mac_rx_datain            (  gmii_rxd_1d           ) //input   [7:0]   mac_rx_datain
    );

//reg [159 : 0] test_data = {8'h77,8'h77,8'h77,8'h2E,   //{"w","w","w","."}; 
//                          8'h6D,8'h65,8'h79,8'h65,   //{"m","e","y","e"}; 
//                          8'h73,8'h65,8'h6D,8'h69,   //{"s","e","m","i"}; 
//                          8'h2E,8'h63,8'h6F,8'h6D,   //{".","c","o","m"}; 
//                               8'h20,8'h20,8'h20,8'h0A  };//{" "," "," ","\n"};
//reg [159:0] rec_data;

always@(posedge rgmii_clk)
begin
    if(rstn == 1'b0)
	    udp_send_data_length <= 16'd0 ;
	else if(!ethernet_loop)
        udp_send_data_length <= SEND_DATA_WIDTH;
    else
        udp_send_data_length <= udp_rec_data_length;
end
  
assign udp_tx_req    = (state == GEN_REQ) ;
assign arp_request_req  = (state == ARP_REQ) ;
    
always@(posedge rgmii_clk)
begin
    if(rstn == 1'b0)
        wait_cnt <= 0 ;
    else if ((state==IDLE||state == WAIT || state == ARP_WAIT) && state != state_n)
        wait_cnt <= 0 ;
    else if (state==IDLE||state == WAIT || state == ARP_WAIT)
        wait_cnt <= wait_cnt + 1'b1 ;
	else
	    wait_cnt <= 0 ;
end

//sig_eth_fifo_rd_en
always@(posedge rgmii_clk)begin
    if(rstn == 1'b0)
        sig_eth_fifo_rd_en <= 1'b0;
    if (!ethernet_loop)
        if(state_n == WRITE_RAM || state == WRITE_RAM && test_cnt <= udp_send_data_length - 2)    //提前一拍拉高sig_eth_fifo的读使能
            sig_eth_fifo_rd_en <= 1'b1;
        else
            sig_eth_fifo_rd_en <= 1'b0;
    else
        sig_eth_fifo_rd_en <= 1'b0;
end

//eth_fifo_rd_en
always@(posedge rgmii_clk)begin
    if(rstn == 1'b0)
        eth_fifo_rd_en <= 1'b0;
    else if(ethernet_loop)            `
        if(state_n == WRITE_RAM || state == WRITE_RAM && test_cnt <= udp_send_data_length - 2)    //提前一拍拉高eth_fifo的读使能
            eth_fifo_rd_en <= 1'b1;
        else
            eth_fifo_rd_en <= 1'b0;
    else
        eth_fifo_rd_en <= 1'b0;
end

//写逻辑
reg [10:0] test_cnt;
always@(posedge rgmii_clk) begin
    if(rstn == 1'b0) begin
        write_end  <= 1'b0;
        ram_wr_data <= 0;
        ram_wr_en  <= 0 ;
        test_cnt   <= 0;
    end else if (state == WRITE_RAM && (eth_fifo_rd_en | sig_eth_fifo_rd_en)) begin    //对齐时序：rd_en先于ram_write_en和ram_wr_data
        if (test_cnt == udp_send_data_length - 1) begin
            ram_wr_en <= 1'b1;
            write_end <= 1'b1;
            test_cnt <= test_cnt + 'd1;
            if (!ethernet_loop)        //采集其他信号转发模式，将sig_eth_fifo中的数据转发到以太网发送缓存区
                ram_wr_data <= sig_eth_fifo_rd_data;
            else                        //以太网回环模式，将eth_fifo中的数据转发到以太网发送缓存区
                ram_wr_data <= eth_fifo_rd_data;
        end else begin//if (delay_cnt == 2'b11) begin
            ram_wr_en <= 1'b1 ;
            write_end <= 1'b0 ;
            //直接将以太网接收数据到fifo内，然后传输的时候读出
            if (!ethernet_loop)        //采集其他信号转发模式，将sig_eth_fifo中的数据转发到以太网发送缓存区
                ram_wr_data <= sig_eth_fifo_rd_data;
            else                        //以太网回环模式，将eth_fifo中的数据转发到以太网发送缓存区
                ram_wr_data <= eth_fifo_rd_data;
            test_cnt <= test_cnt + 'd1;
        end
    end else begin
        write_end  <= 1'b0;
        ram_wr_data <= 0;
        ram_wr_en  <= 0;
        test_cnt   <= 0;
    end
end

//读逻辑
reg[15:0] test_cnt_read;
always @(posedge rgmii_clk)
begin
    if (rstn==1'b0) begin
        test_cnt_read <= 'd0;
        read_end <= 1'b0;
    end else if (state == READ_RAM || (state == WAIT && state_n == READ_RAM)) begin
        if (test_cnt_read == udp_rec_data_length)    //udp_rec_data_length's timing problem solved
            read_end <= 1'b1;
        else begin
            read_end <= 1'b0;
            test_cnt_read <= test_cnt_read + 'b1;
        end
    end else begin
        read_end <= 1'b0;
        test_cnt_read <= 'd0;
    end
end

//ethernet loop
wire[7:0] eth_fifo_rd_data/* synthesis PAP_MARK_DEBUG="true" */;
eth_fifo eth_fifo (
  .clk(rgmii_clk),                      // input
  .rst(eth_fifo_rst),                      // input
  .wr_en(eth_fifo_wr_en),                  // input
  .wr_data(eth_fifo_wr_data),              // input [7:0]
  .wr_full(    ),                      // output
  .almost_full(eth_fifo_almost_full),      // output
  .rd_en(eth_fifo_rd_en),       // input
  .rd_data(eth_fifo_rd_data),              // output [7:0]
  .rd_empty(    ),            // output
  .almost_empty(eth_fifo_almost_empty)     // output
);
      
endmodule
