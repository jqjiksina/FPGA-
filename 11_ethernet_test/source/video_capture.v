//负责将视频信号写入，试着直接写到fifo，而不用ddr3?

module video_capture#(
    parameter CTRL_ADDR_WIDTH     =    28,
    parameter MEM_DQ_WIDTH        =    32,
    parameter MEM_SPACE_AW        =    18,
    parameter AXI_WADDR_HDMI      =    28'd0
    )(
    input pixclk_in,
    input vs_in,
    input hs_in,
    input de_in,
    input [7:0] r_in,
    input [7:0] g_in,
    input [7:0] b_in,
    //sys                                                   
    input core_clk,                                         
    input core_clk_rst_n,                                   
    input ddr_init_done,                                    
    //axi                                                   
    output reg [CTRL_ADDR_WIDTH-1:0]        axi_awaddr,     
    output reg [3:0]                        axi_awlen,      
    input                                   axi_awready,    
    output reg                              axi_awvalid,    
                                                            
    output reg [MEM_DQ_WIDTH*8-1:0]         axi_wdata,      
    input                                   axi_wready,     
    input                                   axi_wusero_last
);

//高复位信号
wire ddr_rst;
assign ddr_rst = ~core_clk_rst_n;

//状态机状态
reg [6:0] status;
reg [6:0] status_next;
parameter S_IDLE             = 4'b0001;
parameter S_WRITE_ADDR       = 4'b0010;
parameter S_WRITE_DATA       = 4'b0100;
parameter S_WAIT_WA          = 4'b1000;

//状态转移-时序
always @(posedge core_clk or posedge ddr_rst) begin
    if (ddr_rst)
        status <= S_IDLE;
    else 
        status <= status_next;
end

//状态转移-组合
always @(*) begin
    case (status)
        S_IDLE:            status_next = ddr_init_done ? S_WAIT_WA : S_IDLE;
        S_WAIT_WA:         status_next = (axi_awready && axi_awvalid) ? S_WRITE_ADDR : S_WAIT_WA;
        S_WRITE_ADDR:      status_next = S_WRITE_DATA;
        S_WRITE_DATA:      status_next = (axi_wready && axi_wusero_last) ? S_WAIT_WA : S_WRITE_DATA;
    endcase
end

//写地址
always @(posedge core_clk) begin
    if (ddr_rst) begin
        axi_awlen   <= 4'h0;
        axi_awaddr  <= 28'd0;
        axi_awvalid <= 1'b0;
    end else if (status == S_WAIT_WA) begin
        axi_awlen   <= 4'hf;
        axi_awaddr  <= AXI_WADDR_HDMI;
        axi_awvalid <= 1'b1;
    end else if (status == S_WRITE_ADDR)
        axi_awvalid <= 1'b0;
    else begin
        axi_awlen   <= 4'h0;
        axi_awaddr  <= 28'd0;
        axi_awvalid <= 1'b0;
    end
end

//写数据，注意axi_wusero_last信号在时钟上升沿后才改变
always @(posedge core_clk) begin
    if (ddr_rst || axi_wusero_last)
        axi_wdata <= 'd0;
    else if (status == S_WRITE_DATA) begin
        if (axi_wready) 
            axi_wdata <= axi_wdata + 'd1;
    end else
        axi_wdata <= 'd0;
end




endmodule