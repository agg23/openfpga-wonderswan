module wonderswan (
    input wire clk_sys_36_864,
    input wire clk_mem_110_592,

    input wire reset_n,
    input wire pll_core_locked,
    input wire external_reset,

    // Data in
    input wire        ioctl_wr,
    input wire [24:0] ioctl_addr,
    input wire [15:0] ioctl_dout,
    // 1 for B&W cart, 2 for color cart
    input wire [ 1:0] ext_cart_download,

    output wire rom_write_complete,

    // BIOS in
    // 1 for B&W bios, 2 for color bios
    input wire [1:0] bios_download,

    input wire bios_wr,
    input wire [12:0] bios_addr,
    input wire [15:0] bios_dout,

    input wire [31:0] rtc_epoch_seconds,

    // Inputs
    input wire button_a,
    input wire button_b,
    input wire button_x,
    input wire button_y,
    input wire button_trig_l,
    input wire button_trig_r,
    input wire button_start,
    input wire button_select,
    input wire dpad_up,
    input wire dpad_down,
    input wire dpad_left,
    input wire dpad_right,

    // Settings
    input wire [1:0] configured_system,
    input wire use_cpu_turbo,
    input wire use_rewind_capture,

    input wire use_triple_buffer,
    input wire [1:0] configured_flickerblend,
    input wire use_flip_horizontal,

    input wire use_fastforward_sound,

    // Saves
    output wire [11:0] save_size,
    output wire has_rtc,
    input wire sd_buff_wr,
    input wire sd_buff_rd,
    input wire [20:0] sd_buff_addr,
    output wire [15:0] sd_buff_din,
    input wire [15:0] sd_buff_dout,

    output wire save_ram_write_complete,

    // Save states
    input wire ss_save,
    input wire ss_load,

    output wire [63:0] ss_din,
    input wire [63:0] ss_dout,
    output wire [25:0] ss_addr,
    output wire ss_rnw,
    output wire ss_req,
    output wire [7:0] ss_be,
    input wire ss_ack,

    output wire ss_busy,

    // SDRAM
    output wire [12:0] dram_a,
    output wire [ 1:0] dram_ba,
    inout  wire [15:0] dram_dq,
    output wire [ 1:0] dram_dqm,
    output wire        dram_clk,
    output wire        dram_cke,
    output wire        dram_ras_n,
    output wire        dram_cas_n,
    output wire        dram_we_n,

    // Video
    output wire hsync,
    output wire vsync,
    output wire hblank,
    output wire vblank,
    output wire [7:0] video_r,
    output wire [7:0] video_g,
    output wire [7:0] video_b,

    output wire is_vertical,

    // Audio
    output wire [15:0] audio_l,
    output wire [15:0] audio_r
);

  wire                                                   [63:0] status = 0;
  wire savepause = 0;

  wire                                                   [13:0] joystick_0 = 0;

  wire                                                   [15:0]                 cart_addr;
  wire                                                                          cart_rd;
  wire                                                                          cart_wr;
  reg                                                                           cart_ready = 0;
  reg                                                                           ioctl_wr_1 = 0;

  wire ioctl_download = cart_download || |bios_download;

  wire cart_download = |ext_cart_download;
  wire colorcart_download = ext_cart_download[1];
  // wire cart_download = ioctl_download && (filetype[5:0] == 6'h01 || filetype == 8'h80);
  // wire colorcart_download = ioctl_download && (filetype == 8'h01);
  // wire bios_download = ioctl_download && (filetype == 8'h00 || filetype == 8'h40);

  wire                                                                          EXTRAM_doRefresh;
  wire                                                                          EXTRAM_read;
  wire                                                                          EXTRAM_write;
  wire                                                   [24:0]                 EXTRAM_addr;
  wire                                                   [15:0]                 EXTRAM_datawrite;
  wire                                                   [15:0]                 EXTRAM_dataread;
  wire                                                   [ 1:0]                 EXTRAM_be;

  wire                                                   [15:0]                 sdram_din;

  assign sd_buff_din = extra_data_addr ? sd_buff_din_time : saveIsSRAM ? sdram_din : eeprom_din;

  reg prev_reset_n = 0;
  reg prev_save_ram_ack = 0;
  reg did_download_save = 0;

  localparam CLEARING_INIT = 0;
  localparam CLEARING_WRITE = 1;
  localparam CLEARING_WAIT_ACK = 2;

  reg [1:0] clearing_ram_state = CLEARING_INIT;
  reg clearing_ram_write = 0;
  reg [19:0] clearing_ram_addr = 0;

  wire clearing_ram = clearing_ram_state != CLEARING_INIT;

  always @(posedge clk_mem_110_592) begin
    prev_reset_n <= reset_n;
    prev_save_ram_ack <= save_ram_ack;

    if (sd_buff_wr) begin
      did_download_save <= 1;
    end

    case (clearing_ram_state)
      CLEARING_INIT: begin
        if (reset_n && ~prev_reset_n) begin
          // Loading complete
          if (~did_download_save && saveIsSRAM) begin
            // No save was loaded, make sure to clear mem
            clearing_ram_state <= CLEARING_WRITE;
          end
        end
      end
      CLEARING_WRITE: begin
        clearing_ram_state <= CLEARING_WAIT_ACK;

        clearing_ram_write <= 1;
      end
      CLEARING_WAIT_ACK: begin
        if (save_ram_ack && ~prev_save_ram_ack) begin
          // Write complete
          clearing_ram_write <= 0;
          clearing_ram_state <= CLEARING_WRITE;

          clearing_ram_addr  <= clearing_ram_addr + 1;

          if (&clearing_ram_addr) begin
            // Finished writing
            clearing_ram_state <= CLEARING_INIT;
          end
        end
      end
    endcase
  end

  wire save_ram_ack;

  assign save_ram_write_complete = save_ram_ack;

  sdram sdram (
      .init(~pll_core_locked),
      .clk (clk_mem_110_592),

      .doRefresh(EXTRAM_doRefresh),

      .ch1_addr (ioctl_addr[24:1]),
      .ch1_din  (ioctl_dout),
      .ch1_req  (ioctl_wr),
      .ch1_rnw  (cart_download ? 1'b0 : 1'b1),
      .ch1_ready(rom_write_complete),
      // .ch1_dout (),

      .ch2_addr (clearing_ram ? {4'b1000, clearing_ram_addr} : {4'b1000, sd_buff_addr[20:1]}),
      .ch2_din  (clearing_ram ? 16'b0 : sd_buff_dout),
      .ch2_dout (sdram_din),
      .ch2_req  ((saveIsSRAM && (sd_buff_rd || sd_buff_wr)) || clearing_ram_write),
      .ch2_rnw  (~clearing_ram_write && ~sd_buff_wr),
      .ch2_ready(save_ram_ack),

      .ch3_addr(EXTRAM_addr[24:1]),
      .ch3_din (EXTRAM_datawrite),
      .ch3_dout(EXTRAM_dataread),
      .ch3_be  (EXTRAM_be),
      .ch3_req (~cart_download & (EXTRAM_read | EXTRAM_write)),
      .ch3_rnw (EXTRAM_read),
      // .ch3_ready(),

      // Actual SDRAM interface
      .SDRAM_DQ(dram_dq),
      .SDRAM_A(dram_a),
      .SDRAM_DQML(dram_dqm[0]),
      .SDRAM_DQMH(dram_dqm[1]),
      .SDRAM_BA(dram_ba),
      //   .SDRAM_nCS(),
      .SDRAM_nWE(dram_we_n),
      .SDRAM_nRAS(dram_ras_n),
      .SDRAM_nCAS(dram_cas_n),
      .SDRAM_CLK(dram_clk),
      .SDRAM_CKE(dram_cke)
  );

  reg [15:0] lastdata[0:4];

  reg colorcart_downloaded;

  always @(posedge clk_mem_110_592) begin
    ioctl_wr_1 <= ioctl_wr;
    if (cart_download) begin
      colorcart_downloaded <= colorcart_download;
      if (ioctl_wr & ~ioctl_wr_1) begin
        // ioctl_wait  <= 1;
        lastdata[0] <= ioctl_dout;
        lastdata[1] <= lastdata[0];
        lastdata[2] <= lastdata[1];
        lastdata[3] <= lastdata[2];
        lastdata[4] <= lastdata[3];
      end
      // if (sdram_ack) ioctl_wait <= 0;
    end
    // else ioctl_wait <= 0;
  end

  reg old_download;
  reg [24:0] mask_addr;

  always @(posedge clk_sys_36_864) begin
    old_download <= cart_download;
    if (old_download & ~cart_download) begin
      mask_addr  <= ioctl_addr[24:0] + 1'd1;
      cart_ready <= 1;
    end
  end

  wire [15:0] Swan_AUDIO_L;
  wire [15:0] Swan_AUDIO_R;

  wire reset = ~reset_n | cart_download | clearing_ram | external_reset;

  reg paused;
  always_ff @(posedge clk_sys_36_864) begin
    paused <= savepause || syncpaused;
  end

  reg bios_wrbw;
  reg bios_wrcolor;
  always @(posedge clk_sys_36_864) begin
    bios_wrbw    <= 0;
    bios_wrcolor <= 0;
    if (|bios_download && bios_wr) begin
      if (bios_download[1] == 1'b1) bios_wrcolor <= 1'b1;
      else bios_wrbw <= 1'b1;
    end
  end

  wire isColor = (configured_system == 0) ? (lastdata[4][8] | colorcart_downloaded) : (configured_system == 2'b10);

  reg [79:0] time_dout = 80'd0;
  wire [79:0] time_din;
  assign time_din[42+32+:80-(42+32)] = '0;
  reg                                                         RTC_load = 0;

  wire                    [ 7:0] ramtype = lastdata[2][15:8];

  wire                    [15:0]                              eeprom_din;
  wire eeprom_ack = 1'b1;

  reg                     [31:0]                              prev_rtc_epoch_seconds = 0;

  always @(posedge clk_sys_36_864) begin
    prev_rtc_epoch_seconds <= rtc_epoch_seconds;
  end

  SwanTop SwanTop (
      .clk     (clk_sys_36_864),
      .clk_ram (clk_mem_110_592),
      .reset_in(reset),
      .pause_in(paused),

      // rom
      .EXTRAM_doRefresh(EXTRAM_doRefresh),
      .EXTRAM_read     (EXTRAM_read),
      .EXTRAM_write    (EXTRAM_write),
      .EXTRAM_be       (EXTRAM_be),
      .EXTRAM_addr     (EXTRAM_addr),
      .EXTRAM_datawrite(EXTRAM_datawrite),
      .EXTRAM_dataread (EXTRAM_dataread),

      .maskAddr(mask_addr[23:0]),
      .romtype(lastdata[2][7:0]),
      .ramtype(ramtype),
      .hasRTC(has_rtc),  // Unused

      // eeprom
      .eepromWrite(eepromWrite),
      .eeprom_addr(sd_buff_addr[20:1]),
      .eeprom_din (sd_buff_dout),
      .eeprom_dout(eeprom_din),
      .eeprom_req (~saveIsSRAM && (sd_buff_rd || sd_buff_wr)),
      // .eeprom_rnw (~save_download || extra_data_addr),
      .eeprom_rnw (~sd_buff_wr),

      // bios
      .bios_wraddr (bios_addr),
      .bios_wrdata (bios_dout),
      .bios_wr     (bios_wrbw),
      .bios_wrcolor(bios_wrcolor),

      // Video 
      .vertical      (vertical),
      .pixel_out_addr(pixel_addr),  // integer range 0 to 16319; -- address for framebuffer
      .pixel_out_data(pixel_data),  // RGB data for framebuffer
      .pixel_out_we  (pixel_we),    // new pixel for framebuffer

      // audio 
      .audio_l(Swan_AUDIO_L),
      .audio_r(Swan_AUDIO_R),

      //settings
      .isColor    (isColor),
      .fastforward(fast_forward),
      .turbo      (use_cpu_turbo),

      // joystick
      .KeyY1   (vertical ? button_x : button_trig_l),   // Vert left
      .KeyY2   (vertical ? button_a : button_trig_r),   // Vert up
      .KeyY3   (vertical ? button_b : button_x),        // Vert right
      .KeyY4   (vertical ? button_y : button_y),        // Vert down
      .KeyX1   (dpad_up),                               // Horz up, vert left
      .KeyX2   (dpad_right),                            // Horz right, vert up
      .KeyX3   (dpad_down),                             // Horz down, vert right
      .KeyX4   (dpad_left),                             // Horz left, vert down
      .KeyStart(button_start),
      .KeyA    (~vertical ? button_a : button_trig_l),
      .KeyB    (~vertical ? button_b : button_trig_r),

      // RTC
      .RTC_timestampNew(rtc_epoch_seconds != prev_rtc_epoch_seconds),
      .RTC_timestampIn(rtc_epoch_seconds),
      .RTC_timestampSaved(time_dout[42+:32]),
      .RTC_savedtimeIn(time_dout[0+:42]),
      .RTC_saveLoaded(RTC_load),
      .RTC_timestampOut(time_din[42+:32]),
      .RTC_savedtimeOut(time_din[0+:42]),

      // savestates
      .increaseSSHeaderCount(1),
      .save_state           (ss_save),
      .load_state           (ss_load),
      .savestate_number     (0),

      .SAVE_out_Din(ss_din),  // data read from savestate
      .SAVE_out_Dout(ss_dout),  // data written to savestate
      .SAVE_out_Adr(ss_addr),  // all addresses are DWORD addresses!
      .SAVE_out_rnw(ss_rnw),  // read = 1, write = 0
      .SAVE_out_ena(ss_req),  // one cycle high for each action
      .SAVE_out_be(ss_be),
      .SAVE_out_done(ss_ack),  // should be one cycle high when write is done or read value is valid
      .SAVE_out_busy(ss_busy)

      // .rewind_on    (use_rewind_capture),
      // .rewind_active(use_rewind_capture & trigger_left)
  );

  assign audio_l = (fast_forward && ~use_fastforward_sound) ? 16'd0 : Swan_AUDIO_L;
  assign audio_r = (fast_forward && ~use_fastforward_sound) ? 16'd0 : Swan_AUDIO_R;

  ////////////////////////////  VIDEO  ////////////////////////////////////

  wire [14:0] pixel_addr;
  wire [11:0] pixel_data;
  wire pixel_we;

  wire buffervideo = use_triple_buffer | configured_flickerblend[1]; // OSD option for buffer or flickerblend on;

  reg [11:0] vram1[32256];
  reg [11:0] vram2[32256];
  reg [11:0] vram3[32256];
  reg [1:0] buffercnt_write = 0;
  reg [1:0] buffercnt_readnext = 0;
  reg [1:0] buffercnt_read = 0;
  reg [1:0] buffercnt_last = 0;
  reg syncpaused = 0;


  always @(posedge clk_sys_36_864) begin
    if (buffervideo) begin
      if (pixel_we && pixel_addr == 32255) begin
        buffercnt_readnext <= buffercnt_write;
        if (buffercnt_write < 2) begin
          buffercnt_write <= buffercnt_write + 1'd1;
        end else begin
          buffercnt_write <= 0;
        end
      end
    end else begin
      buffercnt_write    <= 0;
      buffercnt_readnext <= 0;
    end

    if (pixel_we) begin
      if (buffercnt_write == 0) vram1[pixel_addr] <= pixel_data;
      if (buffercnt_write == 1) vram2[pixel_addr] <= pixel_data;
      if (buffercnt_write == 2) vram3[pixel_addr] <= pixel_data;
    end

    if (y > 150) begin
      syncpaused <= 0;
    end
    // We don't have "Sync core to Video" setting
    // end else if (~fast_forward && status[24] && pixel_we && pixel_addr == 32255) begin
    //   syncpaused <= 1;
    // end

  end

  reg [11:0] rgb0;
  reg [11:0] rgb1;
  reg [11:0] rgb2;

  always @(posedge clk_sys_36_864) begin
    rgb0 <= vram1[px_addr];
    rgb1 <= vram2[px_addr];
    rgb2 <= vram3[px_addr];
  end

  wire [14:0] px_addr;

  wire [11:0] rgb_last = (buffercnt_last == 0) ? rgb0 : (buffercnt_last == 1) ? rgb1 : rgb2;

  wire [11:0] rgb_now = (buffercnt_read == 0) ? rgb0 : (buffercnt_read == 1) ? rgb1 : rgb2;

  wire [4:0] r2_5 = rgb_now[11:8] + rgb_last[11:8];
  wire [4:0] g2_5 = rgb_now[7:4] + rgb_last[7:4];
  wire [4:0] b2_5 = rgb_now[3:0] + rgb_last[3:0];

  wire [5:0] r3_6 = rgb0[11:8] + rgb1[11:8] + rgb2[11:8];
  wire [5:0] g3_6 = rgb0[7:4] + rgb1[7:4] + rgb2[7:4];
  wire [5:0] b3_6 = rgb0[3:0] + rgb1[3:0] + rgb2[3:0];

  wire [7:0] r3_8 = {r3_6, r3_6[5:4]};
  wire [7:0] g3_8 = {g3_6, g3_6[5:4]};
  wire [7:0] b3_8 = {b3_6, b3_6[5:4]};

  wire [23:0] r3_mul24 = r3_8 * 16'D21845;
  wire [23:0] g3_mul24 = g3_8 * 16'D21845;
  wire [23:0] b3_mul24 = b3_8 * 16'D21845;

  wire [23:0] r3_div24 = r3_mul24 / 16'D16384;
  wire [23:0] g3_div24 = g3_mul24 / 16'D16384;
  wire [23:0] b3_div24 = b3_mul24 / 16'D16384;

  wire vertical;
  reg hs, vs, hbl, vbl, ce_pix;
  reg [7:0] r, g, b;
  reg [8:0] x, y;
  reg [2:0] div;
  reg signed [3:0] HShift;
  reg signed [3:0] VShift;

  // TODO: This setting is not exposed for Pocket
  wire use_refresh_rate_75hz = 0;

  always @(posedge clk_sys_36_864) begin

    if (use_refresh_rate_75hz) begin
      if (div < 4) div <= div + 1'd1;
      else div <= 0;  // 36.864 mhz / 5
    end else begin
      if (div < 5) div <= div + 1'd1;
      else div <= 0;  // 36.864 mhz / 6
    end

    ce_pix <= 0;
    if (!div) begin
      ce_pix <= 1;

      if (configured_flickerblend == 0) begin  // flickerblend off
        r <= {rgb_now[11:8], rgb_now[11:8]};
        g <= {rgb_now[7:4], rgb_now[7:4]};
        b <= {rgb_now[3:0], rgb_now[3:0]};
      end else if (configured_flickerblend == 1) begin  // flickerblend 2 frames
        r <= {r2_5, r2_5[4:2]};
        g <= {g2_5, g2_5[4:2]};
        b <= {b2_5, b2_5[4:2]};
      end else begin  // flickerblend 3 frames
        r <= r3_div24[7:0];
        g <= g3_div24[7:0];
        b <= b3_div24[7:0];
      end

      // Rotation is handled by the Pocket scaler
      if (x == 224 + 31) hbl <= 1;
      if (y == 66 + $signed(VShift)) vbl <= 0;
      if (y >= 66 + 144 + $signed(VShift)) vbl <= 1;

      if (x == 31) begin
        hbl <= 0;
      end

      if (x == 320 + $signed(HShift)) begin
        hs <= 1;
        if (y == 1) vs <= 1;
        if (y == 4) vs <= 0;
      end

      if (x == 320 + 32 + $signed(HShift)) hs <= 0;

    end

    if (ce_pix) begin

      if (vbl) begin
        if (use_flip_horizontal) px_addr <= 32255;
        else px_addr <= 0;
      end else begin
        if (!hbl) begin
          if (use_flip_horizontal) px_addr <= px_addr - 1'd1;
          else px_addr <= px_addr + 1'd1;
        end
      end

      x <= x + 1'd1;
      if ((x >= 400 && ~use_refresh_rate_75hz) || (x >= 378 && use_refresh_rate_75hz)) begin
        x <= 0;
        if (~&y) y <= y + 1'd1;
        if (y >= 257) begin
          y              <= 0;
          buffercnt_read <= buffercnt_readnext;
          buffercnt_last <= buffercnt_read;

          // HShift         <= status[19:16];
          // VShift         <= status[23:20];
          HShift         <= 0;
          VShift         <= 0;
        end
      end
    end
  end

  assign is_vertical = vertical;

  assign video_r = r;
  assign video_g = g;
  assign video_b = b;

  assign hsync = hs;
  assign hblank = hbl;

  assign vsync = vs;
  assign vblank = vbl;

  ///////////////////////////// Fast Forward Latch /////////////////////////////////

  reg fast_forward;
  reg ff_latch;

  wire fastforward = button_select && !ioctl_download;
  wire ff_on;

  always @(posedge clk_sys_36_864) begin : ffwd
    reg last_ffw;
    reg ff_was_held;
    longint ff_count;

    last_ffw <= fastforward;

    if (fastforward) ff_count <= ff_count + 1;

    if (~last_ffw & fastforward) begin
      ff_latch <= 0;
      ff_count <= 0;
    end

    if ((last_ffw & ~fastforward)) begin  // 32mhz clock, 0.2 seconds
      ff_was_held <= 0;

      if (ff_count < 6400000 && ~ff_was_held) begin
        ff_was_held <= 1;
        ff_latch <= 1;
      end
    end

    fast_forward <= (fastforward | ff_latch);
  end

  /////////////////////////  SRAM/EEPROM SAVE/LOAD  /////////////////////////////
  wire bk_load = status[41];
  wire bk_save = status[42];
  wire bk_autosave = status[43];
  wire bk_write = (EXTRAM_addr[24] && EXTRAM_write) || eepromWrite;

  wire eepromWrite;

  reg bk_record_rtc = 0;
  reg did_receive_sys_rtc = 0;
  reg is_save_rtc_ready = 0;

  wire extra_data_addr = sd_buff_addr >= (save_size * 512);

  // wire savepause = bk_state;

  // assign has_rtc = lastdata[1][8];
  assign has_rtc = 1'b1;

  wire saveIsSRAM = (ramtype == 8'h01) || (ramtype == 8'h02) || (ramtype == 8'h03) || (ramtype == 8'h04) || (ramtype == 8'h05);

  always_comb begin
    save_size <= 0;

    if (ramtype == 8'h01) save_size <= 12'h10;
    if (ramtype == 8'h02) save_size <= 12'h40;
    if (ramtype == 8'h03) save_size <= 12'h100;
    if (ramtype == 8'h04) save_size <= 12'h200;
    if (ramtype == 8'h05) save_size <= 12'h400;
    // These are EEPROM saves
    if (ramtype == 8'h10) save_size <= 12'h004;
    if (ramtype == 8'h20) save_size <= 12'h004;
    if (ramtype == 8'h50) save_size <= 12'h004;
  end

  always @(posedge clk_sys_36_864) begin
    if (rtc_epoch_seconds != 0) begin
      // RTC received
      did_receive_sys_rtc <= 1;
    end

    if (did_receive_sys_rtc && is_save_rtc_ready) begin
      // Loaded save RTC, but couldn't send it since sys RTC hadn't yet been received
      // We can mark the save RTC loaded now
      RTC_load <= 1;
    end

    if (extra_data_addr) begin
      // First byte of RTC
      if (sd_buff_addr[8:0] == 0 && sd_buff_wr && sd_buff_dout == "RT") begin
        bk_record_rtc <= 1;
        RTC_load <= 0;
      end
    end

    if (bk_record_rtc) begin
      if (sd_buff_addr[8:1] < 6 && sd_buff_addr[8:1] >= 1) begin
        // Word addressing (3:1)
        // Skip first word of row ("RT")
        time_dout[{sd_buff_addr[3:1]-3'd1, 4'b0000}+:16] <= sd_buff_dout;
      end

      if (sd_buff_addr[8:1] == 5) begin
        // RTC_load <= 1;
        is_save_rtc_ready <= 1;
        bk_record_rtc <= 0;
      end
    end
  end

  wire [127:0] time_din_h = {32'd0, time_din, "RT"};
  // Word addressing (3:1)
  wire [ 15:0] sd_buff_din_time = time_din_h[{sd_buff_addr[3:1], 4'b0000}+:16];

endmodule
