`timescale 1ns/1ps

module tb_ddr3_simu();

reg clk;
reg rstn;

wire pll_lock;
wire ddr_init_done;
wire heart_beat_led;
wire err_flag_led;

test_ddr test_ddr(
    .ref_clk       (clk        ),
    .rst_board     (rstn      ),
    .pll_lock      (pll_lock       ),
    .ddr_init_done (ddr_init_done  ),
                  
    .mem_rst_n     (mem_rst_n      ),
    .mem_ck        (mem_ck         ),
    .mem_ck_n      (mem_ck_n       ),
    .mem_cke       (mem_cke        ),
      
    .mem_cs_n      (mem_cs_n       ),
                  
    .mem_ras_n     (mem_ras_n      ),
    .mem_cas_n     (mem_cas_n      ),
    .mem_we_n      (mem_we_n       ),
    .mem_odt       (mem_odt        ),
    .mem_a         (mem_a          ),
    .mem_ba        (mem_ba         ),
    .mem_dqs       (mem_dqs        ),
    .mem_dqs_n     (mem_dqs_n      ),
    .mem_dq        (mem_dq         ),
    .mem_dm        (mem_dm         ),
    .heart_beat_led(heart_beat_led ),
    .err_flag_led  (err_flag_led   ) 
    );

GTP_GRS GRS_INST (
    .GRS_N(1'b1)
);

initial begin
    clk = 0;
    rstn = 0;
    #30 rstn = 1;
    #30 rstn = 0;
    #30 rstn = 1;
end

always begin
    #20 clk = ~clk;
end

endmodule