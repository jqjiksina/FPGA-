module ddr3_example(
    input wire clk,
    input wire resetn,
    output wire ddr_init_done,
    output reg [255:0] read_data,
    output reg read_valid
);

    // DDR3 控制器的接口信号声明
    wire pll_lock, ddrphy_clkin;
    wire axi_awready, axi_arready, axi_rvalid;
    wire apb_ready, apb_int;
    wire [15:0] apb_rdata;
    
    // 写地址控制信号
    reg [27:0] axi_awaddr;
    reg axi_awvalid;
    reg [3:0]axi_awlen;
    reg axi_awuser_ap;
    reg [3:0]axi_awuser_id;

    // 写数据（因为 `axi_wvalid` 不存在，直接用 `axi_awvalid` 控制写请求）
    reg [255:0] axi_wdata;
    reg [31:0] axi_wstrb;
    reg axi_wusero_last;
    reg [3:0]axi_wusero_id;
    
    // 读地址和控制信号
    reg [27:0] axi_araddr;
    reg axi_arvalid;
    reg [3:0] axi_arlen;
    reg axi_aruser_ap;
    reg [3:0]axi_aruser_id;

    // 读数据
    reg axi_rlast;
    reg [3:0]axi_rid;

    // DDR3初始化完成信号
    assign ddr_init_done = ddr_init_done;

    wire rstn;
    assign rstn = resetn & pll_lock;
    // DDR3 模块例化
    ddr_test ddr (
        .resetn(rstn),
        .ddr_init_done(ddr_init_done),
        .ddrphy_clkin(ddrphy_clkin),
        .pll_lock(pll_lock),
        //写地址
        .axi_awaddr(axi_awaddr),
        .axi_awvalid(axi_awvalid),
        .axi_awready(axi_awready),
        .axi_awlen(axi_awlen),
        .axi_awuser_ap(axi_awuser_ap),
        .axi_awuser_id(axi_awuser_id),
        //写数据
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb),
        .axi_wusero_last(axi_wusero_last),
        .axi_wusero_id(axi_wusero_id),
        //读地址
        .axi_araddr(axi_araddr),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),
        .axi_aruser_ap(axi_aruser_ap),
        .axi_arlen(axi_arlen),
        .axi_aruser_id(axi_aruser_id),
        //读数据
        .axi_rdata(read_data),
        .axi_rvalid(axi_rvalid),
        .axi_rlast(axi_rlast),
        .axi_rid(axi_rid),
        //apb控制
        .apb_clk(clk),
        .apb_rst_n(resetn),
        .apb_sel(1'b1),
        .apb_enable(1'b1),
        .apb_addr(8'h00),
        .apb_write(1'b0),
        .apb_ready(apb_ready),
        .apb_rdata(apb_rdata),
        .apb_int(apb_int),

        //debug
//        .debug_data(debug_data),                              // output [135:0]
//        .debug_slice_state(debug_slice_state),                // output [51:0]
//        .debug_calib_ctrl(debug_calib_ctrl),                  // output [21:0]
//        .ck_dly_set_bin(ck_dly_set_bin),                      // output [7:0]
//        .force_ck_dly_en(force_ck_dly_en),                    // input
//        .force_ck_dly_set_bin(force_ck_dly_set_bin),          // input [7:0]
//        .dll_step(dll_step),                                  // output [7:0]
//        .dll_lock(dll_lock),                                  // output
//        .init_read_clk_ctrl(init_read_clk_ctrl),              // input [1:0]
//        .init_slip_step(init_slip_step),                      // input [3:0]
//        .force_read_clk_ctrl(force_read_clk_ctrl),            // input
//        .ddrphy_gate_update_en(ddrphy_gate_update_en),        // input
//        .update_com_val_err_flag(update_com_val_err_flag),    // output [3:0]
//        .rd_fake_stop(rd_fake_stop),                          // input

        //direct memory access
        .mem_rst_n(mem_rst_n),                                // output
        .mem_ck(mem_ck),                                      // output
        .mem_ck_n(mem_ck_n),                                  // output
        .mem_cke(mem_cke),                                    // output
        .mem_cs_n(mem_cs_n),                                  // output
        .mem_ras_n(mem_ras_n),                                // output
        .mem_cas_n(mem_cas_n),                                // output
        .mem_we_n(mem_we_n),                                  // output
        .mem_odt(mem_odt),                                    // output
        .mem_a(mem_a),                                        // output [14:0]
        .mem_ba(mem_ba),                                      // output [2:0]
        .mem_dqs(mem_dqs),                                    // inout [3:0]
        .mem_dqs_n(mem_dqs_n),                                // inout [3:0]
        .mem_dq(mem_dq),                                      // inout [31:0]
        .mem_dm(mem_dm)                                       // output [3:0]
    );

//ddr_test the_instance_name (
//  .resetn(resetn),                                      // input
//  .ddr_init_done(ddr_init_done),                        // output
//  .ddrphy_clkin(ddrphy_clkin),                          // output
//  .pll_lock(pll_lock),                                  // output
//  .axi_awaddr(axi_awaddr),                              // input [27:0]
//  .axi_awuser_ap(axi_awuser_ap),                        // input
//  .axi_awuser_id(axi_awuser_id),                        // input [3:0]
//  .axi_awlen(axi_awlen),                                // input [3:0]
//  .axi_awready(axi_awready),                            // output
//  .axi_awvalid(axi_awvalid),                            // input
//  .axi_wstrb(axi_wstrb),                                // input [31:0]
//  .axi_wready(axi_wready),                              // output
//  .axi_wusero_id(axi_wusero_id),                        // output [3:0]
//  .axi_wusero_last(axi_wusero_last),                    // output
//  .axi_araddr(axi_araddr),                              // input [27:0]
//  .axi_aruser_ap(axi_aruser_ap),                        // input
//  .axi_aruser_id(axi_aruser_id),                        // input [3:0]
//  .axi_arlen(axi_arlen),                                // input [3:0]
//  .axi_arready(axi_arready),                            // output
//  .axi_arvalid(axi_arvalid),                            // input
//  .axi_rdata(axi_rdata),                                // output [255:0]
//  .axi_rid(axi_rid),                                    // output [3:0]
//  .axi_rlast(axi_rlast),                                // output
//  .axi_rvalid(axi_rvalid),                              // output
//  .apb_clk(apb_clk),                                    // input
//  .apb_rst_n(apb_rst_n),                                // input
//  .apb_sel(apb_sel),                                    // input
//  .apb_enable(apb_enable),                              // input
//  .apb_addr(apb_addr),                                  // input [7:0]
//  .apb_write(apb_write),                                // input
//  .apb_ready(apb_ready),                                // output
//  .apb_wdata(apb_wdata),                                // input [15:0]
//  .apb_rdata(apb_rdata),                                // output [15:0]
//  .apb_int(apb_int),                                    // output
//  .debug_data(debug_data),                              // output [135:0]
//  .debug_slice_state(debug_slice_state),                // output [51:0]
//  .debug_calib_ctrl(debug_calib_ctrl),                  // output [21:0]
//  .ck_dly_set_bin(ck_dly_set_bin),                      // output [7:0]
//  .force_ck_dly_en(force_ck_dly_en),                    // input
//  .force_ck_dly_set_bin(force_ck_dly_set_bin),          // input [7:0]
//  .dll_step(dll_step),                                  // output [7:0]
//  .dll_lock(dll_lock),                                  // output
//  .init_read_clk_ctrl(init_read_clk_ctrl),              // input [1:0]
//  .init_slip_step(init_slip_step),                      // input [3:0]
//  .force_read_clk_ctrl(force_read_clk_ctrl),            // input
//  .ddrphy_gate_update_en(ddrphy_gate_update_en),        // input
//  .update_com_val_err_flag(update_com_val_err_flag),    // output [3:0]
//  .rd_fake_stop(rd_fake_stop),                          // input
//  .mem_rst_n(mem_rst_n),                                // output
//  .mem_ck(mem_ck),                                      // output
//  .mem_ck_n(mem_ck_n),                                  // output
//  .mem_cke(mem_cke),                                    // output
//  .mem_cs_n(mem_cs_n),                                  // output
//  .mem_ras_n(mem_ras_n),                                // output
//  .mem_cas_n(mem_cas_n),                                // output
//  .mem_we_n(mem_we_n),                                  // output
//  .mem_odt(mem_odt),                                    // output
//  .mem_a(mem_a),                                        // output [14:0]
//  .mem_ba(mem_ba),                                      // output [2:0]
//  .mem_dqs(mem_dqs),                                    // inout [3:0]
//  .mem_dqs_n(mem_dqs_n),                                // inout [3:0]
//  .mem_dq(mem_dq),                                      // inout [31:0]
//  .mem_dm(mem_dm)                                       // output [3:0]
//);

    // 状态机控制
    reg [1:0] state;
    localparam IDLE = 2'd0;
    localparam WRITE = 2'd1;
    localparam READ = 2'd2;

    // 状态机逻辑
    always @(posedge clk) begin
        if (!rstn) begin
            state <= IDLE;
            axi_awaddr <= 28'h0;
            axi_awvalid <= 1'b0;
            axi_wdata <= 256'hA5A5A5A5;  // 测试数据
            axi_wstrb <= 32'hFFFFFFFF;
            axi_araddr <= 28'h0;
            axi_arvalid <= 1'b0;
            read_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    read_valid <= 1'b0;
                    if (ddr_init_done) begin
                        state <= WRITE;
                        axi_awaddr <= 28'h0001000;  // 写入地址
                        axi_awvalid <= 1'b1;
                        axi_awlen <= 4'd0;
                        axi_awuser_ap <= 1'b1;
                        axi_awuser_id <= 4'd0;
                    end
                end
                WRITE: begin
                    if (axi_awready && axi_awvalid) begin
                        axi_awvalid <= 1'b0;
                        state <= READ;
                        axi_araddr <= 28'h0001000;  // 读取相同地址
                        axi_arvalid <= 1'b1;
                        axi_arlen <= 4'd0;
                        axi_aruser_ap <= 1'b1;
                        axi_aruser_id <= 4'd1;
                    end
                end
                READ: begin
                    if (axi_arready && axi_arvalid) begin
                        axi_arvalid <= 1'b0;
                    end
                    if (axi_rvalid) begin
                        read_valid <= 1'b1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
