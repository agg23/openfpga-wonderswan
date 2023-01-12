//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top (

    //
    // physical connections
    //

    ///////////////////////////////////////////////////
    // clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

    input wire clk_74a,  // mainclk1
    input wire clk_74b,  // mainclk1 

    ///////////////////////////////////////////////////
    // cartridge interface
    // switches between 3.3v and 5v mechanically
    // output enable for multibit translators controlled by pic32

    // GBA AD[15:8]
    inout  wire [7:0] cart_tran_bank2,
    output wire       cart_tran_bank2_dir,

    // GBA AD[7:0]
    inout  wire [7:0] cart_tran_bank3,
    output wire       cart_tran_bank3_dir,

    // GBA A[23:16]
    inout  wire [7:0] cart_tran_bank1,
    output wire       cart_tran_bank1_dir,

    // GBA [7] PHI#
    // GBA [6] WR#
    // GBA [5] RD#
    // GBA [4] CS1#/CS#
    //     [3:0] unwired
    inout  wire [7:4] cart_tran_bank0,
    output wire       cart_tran_bank0_dir,

    // GBA CS2#/RES#
    inout  wire cart_tran_pin30,
    output wire cart_tran_pin30_dir,
    // when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
    // the goal is that when unconfigured, the FPGA weak pullups won't interfere.
    // thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
    // and general IO drive this pin.
    output wire cart_pin30_pwroff_reset,

    // GBA IRQ/DRQ
    inout  wire cart_tran_pin31,
    output wire cart_tran_pin31_dir,

    // infrared
    input  wire port_ir_rx,
    output wire port_ir_tx,
    output wire port_ir_rx_disable,

    // GBA link port
    inout  wire port_tran_si,
    output wire port_tran_si_dir,
    inout  wire port_tran_so,
    output wire port_tran_so_dir,
    inout  wire port_tran_sck,
    output wire port_tran_sck_dir,
    inout  wire port_tran_sd,
    output wire port_tran_sd_dir,

    ///////////////////////////////////////////////////
    // cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

    output wire [21:16] cram0_a,
    inout  wire [ 15:0] cram0_dq,
    input  wire         cram0_wait,
    output wire         cram0_clk,
    output wire         cram0_adv_n,
    output wire         cram0_cre,
    output wire         cram0_ce0_n,
    output wire         cram0_ce1_n,
    output wire         cram0_oe_n,
    output wire         cram0_we_n,
    output wire         cram0_ub_n,
    output wire         cram0_lb_n,

    output wire [21:16] cram1_a,
    inout  wire [ 15:0] cram1_dq,
    input  wire         cram1_wait,
    output wire         cram1_clk,
    output wire         cram1_adv_n,
    output wire         cram1_cre,
    output wire         cram1_ce0_n,
    output wire         cram1_ce1_n,
    output wire         cram1_oe_n,
    output wire         cram1_we_n,
    output wire         cram1_ub_n,
    output wire         cram1_lb_n,

    ///////////////////////////////////////////////////
    // sdram, 512mbit 16bit

    output wire [12:0] dram_a,
    output wire [ 1:0] dram_ba,
    inout  wire [15:0] dram_dq,
    output wire [ 1:0] dram_dqm,
    output wire        dram_clk,
    output wire        dram_cke,
    output wire        dram_ras_n,
    output wire        dram_cas_n,
    output wire        dram_we_n,

    ///////////////////////////////////////////////////
    // sram, 1mbit 16bit

    output wire [16:0] sram_a,
    inout  wire [15:0] sram_dq,
    output wire        sram_oe_n,
    output wire        sram_we_n,
    output wire        sram_ub_n,
    output wire        sram_lb_n,

    ///////////////////////////////////////////////////
    // vblank driven by dock for sync in a certain mode

    input wire vblank,

    ///////////////////////////////////////////////////
    // i/o to 6515D breakout usb uart

    output wire dbg_tx,
    input  wire dbg_rx,

    ///////////////////////////////////////////////////
    // i/o pads near jtag connector user can solder to

    output wire user1,
    input  wire user2,

    ///////////////////////////////////////////////////
    // RFU internal i2c bus 

    inout  wire aux_sda,
    output wire aux_scl,

    ///////////////////////////////////////////////////
    // RFU, do not use
    output wire vpll_feed,


    //
    // logical connections
    //

    ///////////////////////////////////////////////////
    // video, audio output to scaler
    output wire [23:0] video_rgb,
    output wire        video_rgb_clock,
    output wire        video_rgb_clock_90,
    output wire        video_de,
    output wire        video_skip,
    output wire        video_vs,
    output wire        video_hs,

    output wire audio_mclk,
    input  wire audio_adc,
    output wire audio_dac,
    output wire audio_lrck,

    ///////////////////////////////////////////////////
    // bridge bus connection
    // synchronous to clk_74a
    output wire        bridge_endian_little,
    input  wire [31:0] bridge_addr,
    input  wire        bridge_rd,
    output reg  [31:0] bridge_rd_data,
    input  wire        bridge_wr,
    input  wire [31:0] bridge_wr_data,

    ///////////////////////////////////////////////////
    // controller data
    // 
    // key bitmap:
    //   [0]    dpad_up
    //   [1]    dpad_down
    //   [2]    dpad_left
    //   [3]    dpad_right
    //   [4]    face_a
    //   [5]    face_b
    //   [6]    face_x
    //   [7]    face_y
    //   [8]    trig_l1
    //   [9]    trig_r1
    //   [10]   trig_l2
    //   [11]   trig_r2
    //   [12]   trig_l3
    //   [13]   trig_r3
    //   [14]   face_select
    //   [15]   face_start
    // joy values - unsigned
    //   [ 7: 0] lstick_x
    //   [15: 8] lstick_y
    //   [23:16] rstick_x
    //   [31:24] rstick_y
    // trigger values - unsigned
    //   [ 7: 0] ltrig
    //   [15: 8] rtrig
    //
    input wire [15:0] cont1_key,
    input wire [15:0] cont2_key,
    input wire [15:0] cont3_key,
    input wire [15:0] cont4_key,
    input wire [31:0] cont1_joy,
    input wire [31:0] cont2_joy,
    input wire [31:0] cont3_joy,
    input wire [31:0] cont4_joy,
    input wire [15:0] cont1_trig,
    input wire [15:0] cont2_trig,
    input wire [15:0] cont3_trig,
    input wire [15:0] cont4_trig

);

  // not using the IR port, so turn off both the LED, and
  // disable the receive circuit to save power
  assign port_ir_tx              = 0;
  assign port_ir_rx_disable      = 1;

  // bridge endianness
  assign bridge_endian_little    = 0;

  // cart is unused, so set all level translators accordingly
  // directions are 0:IN, 1:OUT
  assign cart_tran_bank3         = 8'hzz;
  assign cart_tran_bank3_dir     = 1'b0;
  assign cart_tran_bank2         = 8'hzz;
  assign cart_tran_bank2_dir     = 1'b0;
  assign cart_tran_bank1         = 8'hzz;
  assign cart_tran_bank1_dir     = 1'b0;
  assign cart_tran_bank0         = 4'hf;
  assign cart_tran_bank0_dir     = 1'b1;
  assign cart_tran_pin30         = 1'b0;  // reset or cs2, we let the hw control it by itself
  assign cart_tran_pin30_dir     = 1'bz;
  assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
  assign cart_tran_pin31         = 1'bz;  // input
  assign cart_tran_pin31_dir     = 1'b0;  // input

  // link port is input only
  assign port_tran_so            = 1'bz;
  assign port_tran_so_dir        = 1'b0;  // SO is output only
  assign port_tran_si            = 1'bz;
  assign port_tran_si_dir        = 1'b0;  // SI is input only
  assign port_tran_sck           = 1'bz;
  assign port_tran_sck_dir       = 1'b0;  // clock direction can change
  assign port_tran_sd            = 1'bz;
  assign port_tran_sd_dir        = 1'b0;  // SD is input and not used

  // tie off the rest of the pins we are not using
  assign cram0_a                 = 'h0;
  assign cram0_dq                = {16{1'bZ}};
  assign cram0_clk               = 0;
  assign cram0_adv_n             = 1;
  assign cram0_cre               = 0;
  assign cram0_ce0_n             = 1;
  assign cram0_ce1_n             = 1;
  assign cram0_oe_n              = 1;
  assign cram0_we_n              = 1;
  assign cram0_ub_n              = 1;
  assign cram0_lb_n              = 1;

  assign cram1_a                 = 'h0;
  assign cram1_dq                = {16{1'bZ}};
  assign cram1_clk               = 0;
  assign cram1_adv_n             = 1;
  assign cram1_cre               = 0;
  assign cram1_ce0_n             = 1;
  assign cram1_ce1_n             = 1;
  assign cram1_oe_n              = 1;
  assign cram1_we_n              = 1;
  assign cram1_ub_n              = 1;
  assign cram1_lb_n              = 1;

  // assign dram_a                  = 'h0;
  // assign dram_ba                 = 'h0;
  // assign dram_dq                 = {16{1'bZ}};
  // assign dram_dqm                = 'h0;
  // assign dram_clk                = 'h0;
  // assign dram_cke                = 'h0;
  // assign dram_ras_n              = 'h1;
  // assign dram_cas_n              = 'h1;
  // assign dram_we_n               = 'h1;

  assign sram_a                  = 'h0;
  assign sram_dq                 = {16{1'bZ}};
  assign sram_oe_n               = 1;
  assign sram_we_n               = 1;
  assign sram_ub_n               = 1;
  assign sram_lb_n               = 1;

  assign dbg_tx                  = 1'bZ;
  assign user1                   = 1'bZ;
  assign aux_scl                 = 1'bZ;
  assign vpll_feed               = 1'bZ;


  // for bridge write data, we just broadcast it to all bus devices
  // for bridge read data, we have to mux it
  // add your own devices here
  always @(*) begin
    casex (bridge_addr)
      default: begin
        bridge_rd_data <= 0;
      end
      // Bridge
      32'hF8xxxxxx: begin
        bridge_rd_data <= cmd_bridge_rd_data;
      end
      32'h2xxxxxxx: begin
        bridge_rd_data <= sd_read_data;
      end
      32'h4xxxxxxx: begin
        bridge_rd_data <= save_state_bridge_read_data;
      end
    endcase
  end

  always @(posedge clk_74a) begin
    if (reset_delay > 0) begin
      reset_delay <= reset_delay - 1;
    end

    if (bridge_wr) begin
      casex (bridge_addr)
        32'h0: begin
          cart_download <= bridge_wr_data[0];
        end
        32'h4: begin
          is_color_cart <= bridge_wr_data[0];
        end
        32'h8: begin
          bw_bios_download <= bridge_wr_data[0];
        end
        32'hC: begin
          color_bios_download <= bridge_wr_data[0];
        end
        32'h10: begin
          save_download <= bridge_wr_data[0];
        end

        32'h050: begin
          reset_delay <= 32'h100000;
        end

        32'h100: begin
          configured_system <= bridge_wr_data[1:0];
        end
        32'h110: begin
          use_cpu_turbo <= bridge_wr_data[0];
        end
        // 32'h114: begin
        //   use_rewind_capture <= bridge_wr_data[0];
        // end

        32'h200: begin
          use_triple_buffer <= bridge_wr_data[0];
        end
        32'h204: begin
          configured_flickerblend <= bridge_wr_data[1:0];
        end
        32'h208: begin
          configured_orientation <= bridge_wr_data[1:0];
        end
        32'h20C: begin
          use_flip_horizontal <= bridge_wr_data[0];
        end

        32'h300: begin
          use_fastforward_sound <= bridge_wr_data[0];
        end
      endcase
    end
  end


  //
  // host/target command handler
  //
  wire reset_n;  // driven by host commands, can be used as core-wide reset
  wire [31:0] cmd_bridge_rd_data;

  // bridge host commands
  // synchronous to clk_74a
  wire status_boot_done = pll_core_locked;
  wire status_setup_done = pll_core_locked;  // rising edge triggers a target command
  wire status_running = reset_n;  // we are running as soon as reset_n goes high

  wire dataslot_requestread;
  wire [15:0] dataslot_requestread_id;
  wire dataslot_requestread_ack = 1;
  wire dataslot_requestread_ok = 1;

  wire dataslot_requestwrite;
  wire [15:0] dataslot_requestwrite_id;
  wire dataslot_requestwrite_ack = 1;
  wire dataslot_requestwrite_ok = 1;

  wire dataslot_allcomplete;

  wire [31:0] rtc_epoch_seconds;

  wire savestate_supported = 1;
  wire [31:0] savestate_addr = 32'h40000000;
  // TODO: Change size of save state based on memory size
  wire [31:0] savestate_size = 32'h90_200;
  // Add buffer of 0x1000 for extra data that we'll just discard on loading
  wire [31:0] savestate_maxloadsize = savestate_size + 32'h1_000;

  wire savestate_start;
  wire savestate_start_ack;
  wire savestate_start_busy;
  wire savestate_start_ok;
  wire savestate_start_err;

  wire savestate_load;
  wire savestate_load_ack;
  wire savestate_load_busy;
  wire savestate_load_ok;
  wire savestate_load_err;

  wire osnotify_inmenu;

  // bridge target commands
  // synchronous to clk_74a


  // bridge data slot access

  reg [9:0] datatable_addr;
  reg datatable_wren;
  reg [31:0] datatable_data;
  wire [31:0] datatable_q;

  core_bridge_cmd icb (

      .clk    (clk_74a),
      .reset_n(reset_n),

      .bridge_endian_little(bridge_endian_little),
      .bridge_addr         (bridge_addr),
      .bridge_rd           (bridge_rd),
      .bridge_rd_data      (cmd_bridge_rd_data),
      .bridge_wr           (bridge_wr),
      .bridge_wr_data      (bridge_wr_data),

      .status_boot_done (status_boot_done),
      .status_setup_done(status_setup_done),
      .status_running   (status_running),

      .dataslot_requestread    (dataslot_requestread),
      .dataslot_requestread_id (dataslot_requestread_id),
      .dataslot_requestread_ack(dataslot_requestread_ack),
      .dataslot_requestread_ok (dataslot_requestread_ok),

      .dataslot_requestwrite    (dataslot_requestwrite),
      .dataslot_requestwrite_id (dataslot_requestwrite_id),
      .dataslot_requestwrite_ack(dataslot_requestwrite_ack),
      .dataslot_requestwrite_ok (dataslot_requestwrite_ok),

      .dataslot_allcomplete(dataslot_allcomplete),

      .rtc_epoch_seconds(rtc_epoch_seconds),

      .savestate_supported  (savestate_supported),
      .savestate_addr       (savestate_addr),
      .savestate_size       (savestate_size),
      .savestate_maxloadsize(savestate_maxloadsize),

      .savestate_start     (savestate_start),
      .savestate_start_ack (savestate_start_ack),
      .savestate_start_busy(savestate_start_busy),
      .savestate_start_ok  (savestate_start_ok),
      .savestate_start_err (savestate_start_err),

      .savestate_load     (savestate_load),
      .savestate_load_ack (savestate_load_ack),
      .savestate_load_busy(savestate_load_busy),
      .savestate_load_ok  (savestate_load_ok),
      .savestate_load_err (savestate_load_err),

      .osnotify_inmenu(osnotify_inmenu),

      .datatable_addr(datatable_addr),
      .datatable_wren(datatable_wren),
      .datatable_data(datatable_data),
      .datatable_q   (datatable_q)
  );

  // Save states
  // Save state unloader
  wire ss_busy;
  wire [63:0] ss_din;
  wire [63:0] ss_dout;
  wire [25:0] ss_addr;
  wire ss_rnw;
  wire ss_req;
  wire [7:0] ss_be;
  wire ss_ack;

  wire ss_save;
  wire ss_load;

  wire [31:0] save_state_bridge_read_data;

  save_state_controller save_state_controller (
      .clk_74a(clk_74a),
      .clk_sys(clk_sys_36_864),

      // APF
      .bridge_wr(bridge_wr),
      .bridge_rd(bridge_rd),
      .bridge_endian_little(bridge_endian_little),
      .bridge_addr(bridge_addr),
      .bridge_wr_data(bridge_wr_data),
      .save_state_bridge_read_data(save_state_bridge_read_data),

      // APF Save States
      .savestate_load(savestate_load),
      .savestate_load_ack_s(savestate_load_ack),
      .savestate_load_busy_s(savestate_load_busy),
      .savestate_load_ok_s(savestate_load_ok),
      .savestate_load_err_s(savestate_load_err),

      .savestate_start(savestate_start),
      .savestate_start_ack_s(savestate_start_ack),
      .savestate_start_busy_s(savestate_start_busy),
      .savestate_start_ok_s(savestate_start_ok),
      .savestate_start_err_s(savestate_start_err),

      // Save States Manager
      .ss_save(ss_save),
      .ss_load(ss_load),

      .ss_din (ss_din),
      .ss_dout(ss_dout),
      .ss_addr(ss_addr),
      .ss_rnw (ss_rnw),
      .ss_req (ss_req),
      .ss_be  (ss_be),
      .ss_ack (ss_ack),

      .ss_busy(ss_busy)
  );

  reg ioctl_download = 0;
  wire ioctl_wr;
  wire [24:0] ioctl_addr;
  wire [15:0] ioctl_dout;

  wire rom_write_complete;

  always @(posedge clk_74a) begin
    if (dataslot_requestwrite) ioctl_download <= 1;
    else if (dataslot_allcomplete) ioctl_download <= 0;
  end

  data_loader #(
      .ADDRESS_MASK_UPPER_4(4'h1),
      .ADDRESS_SIZE(25),
      .OUTPUT_WORD_SIZE(2),
      .USE_WRITE_COMPLETE(1)
  ) data_loader (
      .clk_74a(clk_74a),
      .clk_memory(clk_mem_110_592),

      .bridge_wr(bridge_wr),
      .bridge_endian_little(bridge_endian_little),
      .bridge_addr(bridge_addr),
      .bridge_wr_data(bridge_wr_data),

      .write_complete(rom_write_complete),

      .write_en  (ioctl_wr),
      .write_addr(ioctl_addr),
      .write_data(ioctl_dout)
  );

  wire bios_wr;
  wire [12:0] bios_addr;
  wire [15:0] bios_dout;

  data_loader #(
      .ADDRESS_MASK_UPPER_4(4'h3),
      .ADDRESS_SIZE(13),
      .OUTPUT_WORD_SIZE(2),
      .WRITE_MEM_CLOCK_DELAY(4),
      .WRITE_MEM_EN_CYCLE_LENGTH(1)
  ) bios_data_loader (
      .clk_74a(clk_74a),
      .clk_memory(clk_sys_36_864),

      .bridge_wr(bridge_wr),
      .bridge_endian_little(bridge_endian_little),
      .bridge_addr(bridge_addr),
      .bridge_wr_data(bridge_wr_data),

      .write_en  (bios_wr),
      .write_addr(bios_addr),
      .write_data(bios_dout)
  );

  wire [31:0] sd_read_data;

  wire sd_buff_wr;
  wire sd_buff_rd;

  wire [20:0] sd_buff_addr_in;
  wire [20:0] sd_buff_addr_out;

  wire [20:0] sd_buff_addr = sd_buff_wr ? sd_buff_addr_in : sd_buff_addr_out;

  wire [15:0] sd_buff_din;
  wire [15:0] sd_buff_dout;

  wire save_ram_write_complete;

  data_loader #(
      .ADDRESS_MASK_UPPER_4(4'h2),
      .ADDRESS_SIZE(21),
      .OUTPUT_WORD_SIZE(2),
      .USE_WRITE_COMPLETE(1)
  ) save_data_loader (
      .clk_74a(clk_74a),
      .clk_memory(clk_mem_110_592),

      .bridge_wr(bridge_wr),
      .bridge_endian_little(bridge_endian_little),
      .bridge_addr(bridge_addr),
      .bridge_wr_data(bridge_wr_data),

      .write_complete(save_ram_write_complete),

      .write_en  (sd_buff_wr),
      .write_addr(sd_buff_addr_in),
      .write_data(sd_buff_dout)
  );

  data_unloader #(
      .ADDRESS_MASK_UPPER_4(4'h2),
      .ADDRESS_SIZE(21),
      .INPUT_WORD_SIZE(2),
      .READ_MEM_CLOCK_DELAY(20)
  ) save_data_unloader (
      .clk_74a(clk_74a),
      .clk_memory(clk_sys_36_864),

      .bridge_rd(bridge_rd),
      .bridge_endian_little(bridge_endian_little),
      .bridge_addr(bridge_addr),
      .bridge_rd_data(sd_read_data),

      .read_en  (sd_buff_rd),
      .read_addr(sd_buff_addr_out),
      .read_data(sd_buff_din)
  );

  wire [15:0] audio_l;
  wire [15:0] audio_r;

  reg cart_download = 0;
  reg is_color_cart = 0;

  reg bw_bios_download = 0;
  reg color_bios_download = 0;

  reg save_download = 0;

  // wire bw_cart = ioctl_download && dataslot_requestwrite_id == 0;
  // wire color_cart = ioctl_download && dataslot_requestwrite_id == 1;
  // wire [1:0] cart_download = {color_cart, bw_cart};

  // wire bw_bios = ioctl_download && dataslot_requestwrite_id == 9;
  // wire color_bios = ioctl_download && dataslot_requestwrite_id == 10;
  wire [1:0] bios_download = {color_bios_download, bw_bios_download};

  wire [11:0] save_size;
  wire has_rtc;

  always @(posedge clk_74a or negedge pll_core_locked) begin
    if (~pll_core_locked) begin
      datatable_addr <= 0;
      datatable_data <= 0;
      datatable_wren <= 0;
    end else begin
      // Write sram size
      datatable_wren <= 1;
      // save_size is the number of 512 byte blocks
      // has_rtc indicates an additional 6 words (always enabled)
      datatable_data <= save_size * 512 + (has_rtc ? 6 * 2 : 0);
      // Data slot index 3, not id 3
      datatable_addr <= 2 * 3 + 1;
    end
  end

  // Settings
  reg [31:0] reset_delay = 0;
  wire external_reset = reset_delay > 0;

  reg [1:0] configured_system;

  reg use_cpu_turbo;
  // reg use_rewind_capture;

  reg use_triple_buffer;
  reg [1:0] configured_flickerblend;
  reg [1:0] configured_orientation;
  reg use_flip_horizontal;

  reg use_fastforward_sound;

  // Synced settings
  wire external_reset_s;

  wire [1:0] configured_system_s;

  wire use_cpu_turbo_s;
  // wire use_rewind_capture_s;

  wire use_triple_buffer_s;
  wire [1:0] configured_flickerblend_s;
  wire [1:0] configured_orientation_s;
  wire use_flip_horizontal_s;

  wire use_fastforward_sound_s;

  synch_3 #(
      .WIDTH(11)
  ) settings_s (
      {
        external_reset,
        configured_system,
        use_cpu_turbo,
        // use_rewind_capture,
        use_triple_buffer,
        configured_flickerblend,
        configured_orientation,
        use_flip_horizontal,
        use_fastforward_sound
      },
      {
        external_reset_s,
        configured_system_s,
        use_cpu_turbo_s,
        // use_rewind_capture_s,
        use_triple_buffer_s,
        configured_flickerblend_s,
        configured_orientation_s,
        use_flip_horizontal_s,
        use_fastforward_sound_s
      },
      clk_sys_36_864
  );

  wire [15:0] cont1_key_s;

  synch_3 #(
      .WIDTH(16)
  ) cont1_s (
      cont1_key,
      cont1_key_s,
      clk_sys_36_864
  );

  wonderswan wonderswan (
      .clk_sys_36_864 (clk_sys_36_864),
      .clk_mem_110_592(clk_mem_110_592),

      .reset_n(reset_n),
      .pll_core_locked(pll_core_locked),
      .external_reset(external_reset_s),

      .ioctl_wr  (ioctl_wr),
      .ioctl_addr(ioctl_addr),
      .ioctl_dout(ioctl_dout),

      .ext_cart_download(is_color_cart ? {cart_download, 1'b0} : {1'b0, cart_download}),

      .bios_wr(bios_wr),
      .bios_addr(bios_addr),
      .bios_dout(bios_dout),
      .bios_download(bios_download),

      .rom_write_complete(rom_write_complete),

      .rtc_epoch_seconds(rtc_epoch_seconds),

      // Inputs
      .button_a(cont1_key_s[4]),
      .button_b(cont1_key_s[5]),
      .button_x(cont1_key_s[6]),
      .button_y(cont1_key_s[7]),
      .button_trig_l(cont1_key_s[8]),
      .button_trig_r(cont1_key_s[9]),
      .button_start(cont1_key_s[15]),
      .button_select(cont1_key_s[14]),
      .dpad_up(cont1_key_s[0]),
      .dpad_down(cont1_key_s[1]),
      .dpad_left(cont1_key_s[2]),
      .dpad_right(cont1_key_s[3]),

      // Settings
      .configured_system(configured_system_s),
      .use_cpu_turbo(use_cpu_turbo_s),
      // .use_rewind_capture(use_rewind_capture_s),

      .use_triple_buffer(use_triple_buffer_s),
      .configured_flickerblend(configured_flickerblend_s),
      .use_flip_horizontal(use_flip_horizontal_s),

      .use_fastforward_sound(use_fastforward_sound_s),

      // Saves
      .save_size(save_size),
      .has_rtc(has_rtc),
      .sd_buff_wr(sd_buff_wr),
      .sd_buff_rd(sd_buff_rd),
      .sd_buff_addr(sd_buff_addr),
      .sd_buff_din(sd_buff_din),
      .sd_buff_dout(sd_buff_dout),

      .save_ram_write_complete(save_ram_write_complete),

      // Save states
      .ss_save(ss_save),
      .ss_load(ss_load),

      .ss_busy(ss_busy),

      .ss_din (ss_din),
      .ss_dout(ss_dout),
      .ss_addr(ss_addr),
      .ss_rnw (ss_rnw),
      .ss_req (ss_req),
      .ss_be  (ss_be),
      .ss_ack (ss_ack),

      // SDRAM
      .dram_a(dram_a),
      .dram_ba(dram_ba),
      .dram_dq(dram_dq),
      .dram_dqm(dram_dqm),
      .dram_clk(dram_clk),
      .dram_cke(dram_cke),
      .dram_ras_n(dram_ras_n),
      .dram_cas_n(dram_cas_n),
      .dram_we_n(dram_we_n),

      .hblank(h_blank),
      .vblank(v_blank),
      .hsync(video_hs_core),
      .vsync(video_vs_core),
      .video_r(vid_rgb_core[23:16]),
      .video_g(vid_rgb_core[15:8]),
      .video_b(vid_rgb_core[7:0]),
      .is_vertical(is_vertical),

      .audio_l(audio_l),
      .audio_r(audio_r)
  );

  ////////////////////////////////////////////////////////////////////////////////////////

  // Video
  wire h_blank;
  wire v_blank;
  wire video_hs_core;
  wire video_vs_core;
  wire [23:0] vid_rgb_core;
  wire is_vertical;

  reg video_de_reg;
  reg video_hs_reg;
  reg video_vs_reg;
  reg [23:0] video_rgb_reg;

  assign video_rgb_clock = clk_vid_3_75;
  assign video_rgb_clock_90 = clk_vid_3_75_90deg;
  assign video_rgb = video_rgb_reg;
  assign video_de = video_de_reg;
  assign video_skip = 0;
  assign video_vs = video_vs_reg;
  assign video_hs = video_hs_reg;

  reg [2:0] hs_delay;
  reg hs_prev;
  reg vs_prev;
  reg de_prev;

  wire de = ~(h_blank || v_blank);
  // If any vertical orientation, use second slot
  wire video_orientation = configured_orientation_s == 0 ?  // Auto
  is_vertical : configured_orientation_s == 2;  // Vertical
  wire [23:0] video_slot_rgb = {10'b0, video_orientation, 10'b0, 3'b0};

  always @(posedge clk_vid_3_75) begin
    video_hs_reg  <= 0;
    video_de_reg  <= 0;
    video_rgb_reg <= 24'h0;

    if (de) begin
      video_de_reg  <= 1;

      video_rgb_reg <= vid_rgb_core;
    end else if (de_prev && ~de) begin
      video_rgb_reg <= video_slot_rgb;
    end

    if (hs_delay > 0) begin
      hs_delay <= hs_delay - 1;
    end

    if (hs_delay == 1) begin
      video_hs_reg <= 1;
    end

    if (~hs_prev && video_hs_core) begin
      // HSync went high. Delay by 3 cycles to prevent overlapping with VSync
      hs_delay <= 7;
    end

    // Set VSync to be high for a single cycle on the rising edge of the VSync coming out of the core
    video_vs_reg <= ~vs_prev && video_vs_core;
    hs_prev <= video_hs_core;
    vs_prev <= video_vs_core;
    de_prev <= de;
  end

  ///////////////////////////////////////////////

  sound_i2s #(
      .CHANNEL_WIDTH(16),
      .SIGNED_INPUT (1)
  ) sound_i2s (
      .clk_74a  (clk_74a),
      .clk_audio(clk_sys_36_864),

      .audio_l(audio_l),
      .audio_r(audio_r),

      .audio_mclk(audio_mclk),
      .audio_lrck(audio_lrck),
      .audio_dac (audio_dac)
  );

  ///////////////////////////////////////////////

  wire clk_mem_110_592;
  wire clk_sys_36_864;
  wire clk_vid_3_75;
  wire clk_vid_3_75_90deg;

  wire pll_core_locked;

  mf_pllbase mp1 (
      .refclk(clk_74a),
      .rst   (0),

      .outclk_0(clk_mem_110_592),
      .outclk_1(clk_sys_36_864),
      .outclk_2(clk_vid_3_75),
      .outclk_3(clk_vid_3_75_90deg),

      .locked(pll_core_locked)
  );

endmodule
