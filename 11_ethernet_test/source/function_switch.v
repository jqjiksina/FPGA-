//ʵ�ְ�ť�Բɼ������źŵ�fifo�Ĺ���
//�ܹ�����fifo��д����ʹ��
//�ܹ�����ǰ�ɼ��źŶ��������λ��32bit���뻺�浽ethernet���Ͷ˵�fifo
//�������첽fifo�ķ���������

module function_switch #(
        parameter OUTPUT_VALID_DELAY = 3'd5
    ) (
    input wire clk,                        // ϵͳʱ��
    input wire rst_n,                        // �����ź�

    // �����л��źţ���ť��
    input wire btn_hdmi,                   // HDMIģʽ��ť
    input wire btn_ethernet,               // ��̫��ģʽ��ť
    input wire btn_ad,                     // ADģʽ��ť

    // HDMI FIFO�ӿ�
    input wire pix_clk,
    input wire [31:0] hdmi_fifo_data,      // HDMI FIFO�������, 24λRGB����
    //input wire hdmi_fifo_empty,            // HDMI FIFO�ձ�־
    input wire hdmi_fifo_almost_empty,     //
    input wire hdmi_fifo_full,
    output hdmi_fifo_rd_en,            // HDMI FIFO��ȡʹ��
    output reg hdmi_fifo_wr_en,

    //��̫��
    input wire  rgmii_clk,
//    input wire  udp_rec_data_valid,
//    input wire  udp_rec_rdata     , 
//    input wire  udp_rec_data_length,

    // AD FIFO�ӿ�
    input wire ad_clk,
    input wire [7:0] ad_fifo_data,         // AD FIFO�������
    input wire ad_fifo_almost_empty,
    input wire ad_fifo_full,
    output ad_fifo_rd_en,              // AD FIFO��ȡʹ��
    output reg ad_fifo_wr_en,

    // SIG-ETHERNET FIFO�ӿ�
    output wire         sig_eth_fifo_wr_en,    
    output wire [31:0]  sig_eth_fifo_wr_data,      
    input wire         sig_eth_fifo_wr_full,
    input wire            sig_eth_fifo_almost_full,
    output wire         fifo_rst,            //״̬ת��ʱ���
      
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

//���ݰ�ť���������ź�
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

assign fifo_rst = ad_valid_pulse | hdmi_valid_pulse | ad_valid_pulse;    //��������أ����sig_eth_fifo

//valid�����л�
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

//wr_en��дʹ��Ӧ�ø�����������Դ��ʱ�Ӿ���
always @(posedge ad_clk or negedge rst_n) begin
    if (!rst_n)
        ad_fifo_wr_en <= 1'b0;
    else if (!hdmi_valid && !ethernet_valid)    //Ĭ��ad_valid
        ad_fifo_wr_en <= !ad_fifo_full;
    else
        ad_fifo_wr_en <= 1'b0;
end
always @(posedge pix_clk or negedge rst_n) begin
    if (!rst_n)
        hdmi_fifo_wr_en <= 1'b0;
    else if (hdmi_valid)    //Ĭ��ad_valid
        hdmi_fifo_wr_en <= !hdmi_fifo_full;
    else
        hdmi_fifo_wr_en <= 1'b0;
end

//������
always @(posedge rgmii_clk or negedge rst_n) begin
    if (!rst_n)
        count <= 0;
    else begin
        case({ad_valid,hdmi_valid,ethernet_valid})
            3'b100: //ad���Σ�8λ���룬λ��ת������4�ε�32λ
                if (count >= 3 && ad_fifo_rd_en_ld)
                    count <= 'd0;
                else if (ad_fifo_rd_en_ld)
                    count <= count + 'd1;
            3'b010: //hdmi������,32λ����ֱ�ӽ���sig_eth_fifo������Ҫ����
                count <= 'd0;
            default:
                if (count >= 3 && ad_fifo_rd_en_ld)
                    count <= 'd0;
                else if (ad_fifo_rd_en_ld)
                    count <= count + 'd1;
        endcase
    end
end

//rd_en��Ӧ�ø���ͳһ���͵���̫����ʱ��rgmii_clk����
//to do: ��fifo���ʱ���д���ͬ������
//always @(posedge rgmii_clk or negedge rst_n) begin
//    if (!rst_n) begin
//        hdmi_fifo_rd_en <= 'd0;
//        ad_fifo_rd_en <= 'd0;
//    end else if (hdmi_valid == 1) begin
//        if (hdmi_fifo_almost_empty == 1) begin
//            hdmi_fifo_rd_en <= 'd0;       // ���ź�����ʱ����ʹ��Ϊ0
//        end else begin
//            hdmi_fifo_rd_en <= 'd1;
//        end
//    end else if (ad_valid == 1) begin    //default: �ɼ�ad�ź�
//        if (ad_fifo_almost_empty == 1)
//            ad_fifo_rd_en <= 'd0;         // ���ź�����ʱ����ʹ��Ϊ0
//        else
//            ad_fifo_rd_en <= 'd1;
//    end else begin    //default: �ɼ�ad�ź�
//        if (ad_fifo_almost_empty == 1)
//            ad_fifo_rd_en <= 'd0;         // ���ź�����ʱ����ʹ��Ϊ0
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
//sig_eth_valid ��λ�����ת����ʱ������������
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
//д�뻺����-λ��ת��-data_buffer,to-do:
always @(posedge rgmii_clk or negedge rst_n) begin
    if (!rst_n) begin
        data_buffer <= 32'd0;
    end else begin
        case({ad_valid,hdmi_valid,ethernet_valid})
            3'b100:    //�չ�32λ���ݲ����
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
//������������д��SIG_ETHERNET_FIFO����̫������Ҫfifo...
//always @(posedge rgmii_clk or negedge rst_n) begin
//    if (!rst_n) begin
//        sig_eth_fifo_wr_en <= 1'b0;
//    end else if (sig_eth_valid && !sig_eth_fifo_wr_full)
//        sig_eth_fifo_wr_en <= 1'b1;
//    else
//        sig_eth_fifo_wr_en <= 1'b0;
//end



endmodule
