//实现按钮对采集各个信号到fifo的功能
//能够控制fifo的写、读使能
//能够将当前采集信号对象的数据位宽32bit对齐缓存到ethernet发送端的fifo
//考虑了异步fifo的防满、防空

module function_switch #(
        parameter OUTPUT_VALID_DELAY = 3'd5
    ) (
    input wire clk,                        // 系统时钟
    input wire rst_n,                        // 重置信号

    // 功能切换信号（按钮）
    input wire btn_hdmi,                   // HDMI模式按钮
    input wire btn_ethernet,               // 以太网模式按钮
    input wire btn_ad,                     // AD模式按钮

    // HDMI FIFO接口
    input wire pix_clk,
    input wire [31:0] hdmi_fifo_data,      // HDMI FIFO数据输出, 24位RGB数据
    //input wire hdmi_fifo_empty,            // HDMI FIFO空标志
    input wire hdmi_fifo_almost_empty,     //
    input wire hdmi_fifo_full,
    output hdmi_fifo_rd_en,            // HDMI FIFO读取使能
    output reg hdmi_fifo_wr_en,

    //以太网
    input wire  rgmii_clk,
//    input wire  udp_rec_data_valid,
//    input wire  udp_rec_rdata     , 
//    input wire  udp_rec_data_length,

    // AD FIFO接口
    input wire ad_clk,
    input wire [7:0] ad_fifo_data,         // AD FIFO数据输出
    input wire ad_fifo_almost_empty,
    input wire ad_fifo_full,
    output ad_fifo_rd_en,              // AD FIFO读取使能
    output reg ad_fifo_wr_en,

    // SIG-ETHERNET FIFO接口
    output wire         sig_eth_fifo_wr_en,    
    output wire [31:0]  sig_eth_fifo_wr_data,      
    input wire         sig_eth_fifo_wr_full,
    input wire            sig_eth_fifo_almost_full,
    output wire         fifo_rst,            //状态转换时清空
      
    output wire        ad_valid            /* synthesis PAP_MARK_DEBUG="1" */,
    output wire        ethernet_valid        /* synthesis PAP_MARK_DEBUG="1" */,
    output wire        hdmi_valid        /* synthesis PAP_MARK_DEBUG="1" */
);

wire hdmi_valid_pulse;
wire ad_valid_pulse;
wire ethernet_valid_pulse;
reg hdmi_valid;
reg ad_valid;
reg ethernet_valid;
reg [5:0] count;
reg [31:0] data_buffer;
reg sig_eth_valid;
reg hdmi_fifo_rd_en_ld;
reg ad_fifo_rd_en_ld;

assign sig_eth_fifo_wr_data = data_buffer;
assign ethernet_loop = ethernet_valid;
assign ad_fifo_rd_en = ~ad_fifo_almost_empty & ad_valid;
assign hdmi_fifo_rd_en = hdmi_fifo_almost_empty & hdmi_valid;
assign sig_eth_fifo_wr_en =sig_eth_valid;

//根据按钮产生脉冲信号
key_ctl key_hdmi (
    .clk(clk),               // input clk
    .key(btn_hdmi),          // input key
    .key_valid(hdmi_valid_pulse)   // output valid
);

key_ctl key_ad (
    .clk(clk),               // input clk
    .key(btn_ad),            // input key
    .key_valid(ad_valid_pulse)     // output valid
);

key_ctl key_ethernet (
    .clk(clk),               // input clk
    .key(btn_ethernet),      // input key
    .key_valid(ethernet_valid_pulse) // output valid
);

assign fifo_rst = ad_valid_pulse | hdmi_valid_pulse | ad_valid_pulse;    //检测上升沿，清空sig_eth_fifo

//valid功能切换
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        {ad_valid,hdmi_valid,ethernet_valid} <= 3'b000;
    else if (ad_valid_pulse)
        {ad_valid,hdmi_valid,ethernet_valid} <= 3'b100;
    else if (hdmi_valid_pulse)
        {ad_valid,hdmi_valid,ethernet_valid} <= 3'b010;
    else if (ethernet_valid_pulse)
        {ad_valid,hdmi_valid,ethernet_valid} <= 3'b001;
    else
        {ad_valid,hdmi_valid,ethernet_valid} <= {ad_valid,hdmi_valid,ethernet_valid};
end

//wr_en，写使能应该根据输入数据源的时钟决定
always @(posedge ad_clk or negedge rst_n) begin
    if (!rst_n)
        ad_fifo_wr_en <= 1'b0;
    else if (!hdmi_valid && !ethernet_valid)    //默认ad_valid
        ad_fifo_wr_en <= !ad_fifo_full;
    else
        ad_fifo_wr_en <= 1'b0;
end
always @(posedge pix_clk or negedge rst_n) begin
    if (!rst_n)
        hdmi_fifo_wr_en <= 1'b0;
    else if (hdmi_valid)    //默认ad_valid
        hdmi_fifo_wr_en <= !hdmi_fifo_full;
    else
        hdmi_fifo_wr_en <= 1'b0;
end

//计数器
always @(posedge rgmii_clk or negedge rst_n) begin
    if (!rst_n)
        count <= 0;
    else begin
        case({ad_valid,hdmi_valid,ethernet_valid})
            3'b100: //ad情形，8位输入，位宽转换计数4次到32位
                if (count >= 3 && ad_fifo_rd_en_ld)
                    count <= 'd0;
                else if (ad_fifo_rd_en_ld)
                    count <= count + 'd1;
            3'b010: //hdmi情形下,32位数据直接进入sig_eth_fifo，不需要计数
                count <= 'd0;
            default:
                if (count >= 3 && ad_fifo_rd_en_ld)
                    count <= 'd0;
                else if (ad_fifo_rd_en_ld)
                    count <= count + 'd1;
        endcase
    end
end

//rd_en，应该根据统一发送到以太网的时钟rgmii_clk决定
//to do: 在fifo快空时进行打拍同步操作
//always @(posedge rgmii_clk or negedge rst_n) begin
//    if (!rst_n) begin
//        hdmi_fifo_rd_en <= 'd0;
//        ad_fifo_rd_en <= 'd0;
//    end else if (hdmi_valid == 1) begin
//        if (hdmi_fifo_almost_empty == 1) begin
//            hdmi_fifo_rd_en <= 'd0;       // 空信号拉高时，读使能为0
//        end else begin
//            hdmi_fifo_rd_en <= 'd1;
//        end
//    end else if (ad_valid == 1) begin    //default: 采集ad信号
//        if (ad_fifo_almost_empty == 1)
//            ad_fifo_rd_en <= 'd0;         // 空信号拉高时，读使能为0
//        else
//            ad_fifo_rd_en <= 'd1;
//    end else begin    //default: 采集ad信号
//        if (ad_fifo_almost_empty == 1)
//            ad_fifo_rd_en <= 'd0;         // 空信号拉高时，读使能为0
//        else
//            ad_fifo_rd_en <= 'd1;
//    end
//end

//rd_en_ld
always @(posedge rgmii_clk or negedge rst_n) begin
    if (!rst_n) begin
        hdmi_fifo_rd_en_ld <= 'd0;
        ad_fifo_rd_en_ld <= 'd0;
    end else begin
        hdmi_fifo_rd_en_ld <= hdmi_fifo_rd_en;
        ad_fifo_rd_en_ld <= ad_fifo_rd_en;
    end
end

        
//SIG_ETHERNET_FIFO
//sig_eth_valid 在位宽完成转换的时钟周期中拉高
always @(posedge rgmii_clk or negedge rst_n) begin
    if (!rst_n) begin
        sig_eth_valid <= 1'b0;
    end else begin
        case({ad_valid,hdmi_valid,ethernet_valid})
            3'b100:
                if (count == 3 && ad_fifo_rd_en_ld)
                    sig_eth_valid <= 1'b1;
                else
                    sig_eth_valid <= 1'b0;
            3'b010:
                if (hdmi_fifo_rd_en_ld)
                    sig_eth_valid <= 1'b1;
                else
                    sig_eth_valid <= 1'b0;
            3'b001:
                sig_eth_valid <= 1'b0;
            default:
                if (count == 3 && ad_fifo_rd_en_ld)
                    sig_eth_valid <= 1'b1;
                else
                    sig_eth_valid <= 1'b0;
        endcase
    end
end
//写入缓冲区-位宽转换-data_buffer,to-do:
always @(posedge rgmii_clk or negedge rst_n) begin
    if (!rst_n) begin
        data_buffer <= 32'd0;
    end else begin
        case({ad_valid,hdmi_valid,ethernet_valid})
            3'b100:    //凑够32位数据才输出
                if (ad_fifo_rd_en_ld)
                    data_buffer <= {data_buffer[23:0],ad_fifo_data};
            3'b010:
                if (hdmi_fifo_rd_en_ld)
                    data_buffer <= hdmi_fifo_data;
            3'b001:
                data_buffer <= 32'd0;
            default:
                if (ad_fifo_rd_en_ld)
                    data_buffer <= {data_buffer[23:0],ad_fifo_data};
        endcase
    end
end
//将缓冲区数据写入SIG_ETHERNET_FIFO，以太网不需要fifo...
//always @(posedge rgmii_clk or negedge rst_n) begin
//    if (!rst_n) begin
//        sig_eth_fifo_wr_en <= 1'b0;
//    end else if (sig_eth_valid && !sig_eth_fifo_wr_full)
//        sig_eth_fifo_wr_en <= 1'b1;
//    else
//        sig_eth_fifo_wr_en <= 1'b0;
//end



endmodule
