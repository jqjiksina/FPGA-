module ddr_ctrl#(
    parameter CTRL_ADDR_WIDTH     =    28,
    parameter MEM_DQ_WIDTH        =    32,
    parameter MEM_SPACE_AW        =    18
    )(
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
    input                                   axi_wusero_last,
    
    output reg [CTRL_ADDR_WIDTH-1:0]        axi_araddr,
    output reg [3:0]                        axi_arlen,
    input                                   axi_arready,
    output reg                              axi_arvalid,
    
    input [8*MEM_DQ_WIDTH-1:0]              axi_rdata,
    input                                   axi_rlast,
    input                                   axi_rvalid     
   );

//高复位信号
wire ddr_rst;
assign ddr_rst = ~core_clk_rst_n;

//状态机状态
reg [6:0] status;
reg [6:0] status_next;
parameter S_IDLE             = 7'b000_0001;
parameter S_WRITE_ADDR       = 7'b000_0010;
parameter S_WRITE_DATA       = 7'b000_0100;
parameter S_READ_ADDR        = 7'b000_1000;
parameter S_READ_DATA        = 7'b001_0000;
parameter S_WAIT_WA          = 7'b010_0000;
parameter S_WAIT_RA          = 7'b100_0000;

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
        S_WRITE_DATA:      status_next = (axi_wready && axi_wusero_last) ? S_WAIT_RA : S_WRITE_DATA;
        S_WAIT_RA:         status_next = (axi_arvalid && axi_arready) ? S_READ_ADDR : S_WAIT_RA;
        S_READ_ADDR:       status_next = S_READ_DATA;
        S_READ_DATA:       status_next = (axi_rvalid && axi_rlast) ? S_WAIT_WA : S_READ_DATA;
        default:           status_next = S_IDLE;
    endcase
end

//写地址
always @(posedge core_clk) begin
    if (ddr_rst) begin
        axi_awlen   <= 4'hf;
        axi_awaddr  <= 28'd0;
        axi_awvalid <= 1'b0;
    end else if (status == S_WAIT_WA) begin
        axi_awlen   <= 4'hf;
        axi_awaddr  <= 28'd0;
        axi_awvalid <= 1'b1;
    end else if (status == S_WRITE_ADDR)
        axi_awvalid <= 1'b0;
    else begin
        axi_awlen   <= 4'hf;
        axi_awaddr  <= 28'd0;
        axi_awvalid <= 1'b0;
    end
end

//reg [3:0] wr_cnt;
//always @(posedge core_clk) begin
//    if (ddr_rst)
//        wr_cnt <= 0;
//    else if (status == S_WRITE_DATA)
//        if (wr_cnt == 4'hf)
//            wr_cnt <= 0;
//        else
//            wr_cnt <= wr_cnt + 4'd1;
//    else
//        wr_cnt <= 0;
//end

//写数据，注意axi_wusero_last信号在时钟上升沿后才改变
always @(posedge core_clk) begin
    if (ddr_rst || axi_wusero_last)
        axi_wdata <= 'd0;
    else if (status == S_WRITE_DATA) begin
        if (axi_wready) 
            axi_wdata <= axi_wdata + 'd1;
    end else
        axi_wdata <= axi_wdata;
end

//读地址
always @(posedge core_clk) begin
    if (ddr_rst) begin
        axi_arlen   <= 4'hf;
        axi_araddr  <= 28'd0;
        axi_arvalid <= 1'b0;
    end else if (status == S_WAIT_RA) begin
        axi_arlen   <= 4'hf;
        axi_araddr  <= 28'd0;
        axi_arvalid <= 1'b1;
    end else if (status == S_READ_ADDR)
        axi_arvalid <= 1'b0;
    else begin
        axi_arlen   <= 4'hf;
        axi_araddr  <= 28'd0;
        axi_arvalid <= 1'b0;
    end
end

////读数据
//reg [MEM_DQ_WIDTH*8*16-1:0] rd_data_buffer;
//always @(posedge core_clk) begin
//    if (ddr_rst || axi_rlast) begin
//        rd_data_buffer <= 'd0;
//    end else if (status == S_READ_DATA && axi_rvalid) begin
//        rd_data_buffer <= {rd_data_buffer[MEM_DQ_WIDTH*8*15-1:0], axi_rdata};
//    end
//end

endmodule
