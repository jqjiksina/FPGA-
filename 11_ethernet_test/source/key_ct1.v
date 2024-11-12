`timescale 1ns / 1ps
`define UD #1

module key_ctl(
    input clk,
    input key,
    output key_valid
);

    wire btn_deb;

    // ��������
    btn_deb_fix #(
        .BTN_WIDTH(4'd1)  // parameter BTN_WIDTH = 4'd8
    ) U_btn_deb (
        .clk(clk),         // input clk
        .btn_in(key),      // input [BTN_WIDTH-1:0] btn_in
        .btn_deb(btn_deb)  // output reg [BTN_WIDTH-1:0] btn_deb
    );

    reg btn_deb_1d;

    always @(posedge clk) begin
        btn_deb_1d <= `UD btn_deb;  // �� btn_deb �ӳ�һ��ʱ������
    end

    // �½��ؼ���߼����� btn_deb �Ӹ߱�Ϊ��ʱ��key_valid ����
    // ________________________
    // btn_deb  |___________
    // __________________________
    // btn_deb_1d |_______
    // �½��أ�_______| |_______

    reg key_valid;

    always @(posedge clk) begin
        if (~btn_deb & btn_deb_1d) begin  // ��� btn_deb ���½���
            key_valid <= 1;
        end else 
            key_valid <= 0;
    end

endmodule
