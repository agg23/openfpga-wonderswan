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
    // 1 for B&W bios, 2 for color bios
    input wire [ 1:0] bios_download,

    // Inputs
    input wire button_a,
    input wire button_b,
    input wire button_x,
    input wire button_y,
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

  wire [63:0] status = 0;
  wire savepause = 0;

  wire [11:0] sd_lba = 0;
  wire  [7:0] sd_buff_addr;
  wire [15:0] sd_buff_dout;
  wire [15:0] sd_buff_din;
  wire        sd_buff_wr;

  wire [13:0] joystick_0 = 0;

  wire [15:0] cart_addr;
  wire cart_rd;
  wire cart_wr;
  reg cart_ready = 0;
  reg ioctl_wr_1 = 0;

  wire ioctl_download = cart_download || |bios_download;

  wire cart_download = |ext_cart_download;
  wire colorcart_download = ext_cart_download[1];
  // wire cart_download = ioctl_download && (filetype[5:0] == 6'h01 || filetype == 8'h80);
  // wire colorcart_download = ioctl_download && (filetype == 8'h01);
  // wire bios_download = ioctl_download && (filetype == 8'h00 || filetype == 8'h40);

  wire sdram_ack;

  wire EXTRAM_doRefresh;
  wire EXTRAM_read;
  wire EXTRAM_write;
  wire [24:0] EXTRAM_addr;
  wire [15:0] EXTRAM_datawrite;
  wire [15:0] EXTRAM_dataread;
  wire [1:0] EXTRAM_be;

  wire [15:0] sdr_bram_din;
  wire sdr_bram_ack;

  sdram sdram (
      .init(~pll_core_locked),
      .clk (clk_mem_110_592),

      .doRefresh(EXTRAM_doRefresh),

      .ch1_addr (ioctl_addr[24:1]),
      .ch1_din  (ioctl_dout),
      .ch1_req  (ioctl_wr),
      .ch1_rnw  (cart_download ? 1'b0 : 1'b1),
      .ch1_ready(sdram_ack),
      // .ch1_dout (),

      .ch2_addr ({4'b1000, sd_lba[11:0], bram_addr}),
      .ch2_din  (bram_dout),
      .ch2_dout (sdr_bram_din),
      .ch2_req  (bram_req && saveIsSRAM),
      .ch2_rnw  (~bk_loading || extra_data_addr),
      .ch2_ready(sdr_bram_ack),

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

  wire reset = ~reset_n | cart_download | external_reset;

  reg paused;
  always_ff @(posedge clk_sys_36_864) begin
    // paused <= savepause || ((syncpaused || (status[26] && OSD_STATUS)) && ~status[27]); // no pause when rewind capture is on
    paused <= savepause || syncpaused;
  end

  reg [12:0] bios_wraddr;
  reg [15:0] bios_wrdata;
  reg        bios_wr;
  reg        bios_wrcolor;
  always @(posedge clk_sys_36_864) begin
    bios_wr      <= 0;
    bios_wrcolor <= 0;
    if (|bios_download & ioctl_wr) begin
      bios_wrdata <= ioctl_dout;
      bios_wraddr <= ioctl_addr[12:0];
      if (bios_download[1] == 1'b1) bios_wrcolor <= 1'b1;
      else bios_wr <= 1'b1;
    end
  end

  wire isColor = (configured_system == 0) ? (lastdata[4][8] | colorcart_downloaded) : (configured_system == 2'b10);

  reg [79:0] time_dout = 41'd0;
  wire [79:0] time_din;
  assign time_din[42+32+:80-(42+32)] = '0;
  reg                                                         RTC_load = 0;

  wire                    [ 7:0] ramtype = lastdata[2][15:8];

  wire                    [15:0]                              eeprom_din;
  wire eeprom_ack = 1'b1;

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
      .romtype (lastdata[2][7:0]),
      .ramtype (ramtype),
      .hasRTC  (lastdata[1][8]),

      // eeprom
      .eepromWrite(eepromWrite),
      .eeprom_addr({sd_lba[1:0], bram_addr}),
      .eeprom_din (bram_dout),
      .eeprom_dout(eeprom_din),
      .eeprom_req (bram_req && ~saveIsSRAM),
      .eeprom_rnw (~bk_loading || extra_data_addr),

      // bios
      .bios_wraddr (bios_wraddr),
      .bios_wrdata (bios_wrdata),
      .bios_wr     (bios_wr),
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
      .KeyY1   (vertical && button_x), // Vert left
      .KeyY2   (vertical && button_a), // Vert up
      .KeyY3   (vertical && button_b), // Vert right
      .KeyY4   (vertical && button_y), // Vert down
      .KeyX1   (dpad_up ), // Horz up, vert left
      .KeyX2   (dpad_right), // Horz right, vert up
      .KeyX3   (dpad_down), // Horz down, vert right
      .KeyX4   (dpad_left), // Horz left, vert down
      .KeyStart(button_start),
      .KeyA    (~vertical && button_a),
      .KeyB    (~vertical && button_b),

      // RTC
      // .RTC_timestampNew(RTC_time[32]),
      // .RTC_timestampIn(RTC_time[31:0]),
      // .RTC_timestampSaved(time_dout[42+:32]),
      // .RTC_savedtimeIn(time_dout[0+:42]),
      // .RTC_saveLoaded(RTC_load),
      // .RTC_timestampOut(time_din[42+:32]),
      // .RTC_savedtimeOut(time_din[0+:42]),

      // savestates
      .increaseSSHeaderCount(!status[36]),
      .save_state           (ss_save),
      .load_state           (ss_load),
      .savestate_number     (ss_slot),

      .SAVE_out_Din(ss_din),  // data read from savestate
      .SAVE_out_Dout(ss_dout),  // data written to savestate
      .SAVE_out_Adr(ss_addr),  // all addresses are DWORD addresses!
      .SAVE_out_rnw(ss_rnw),  // read = 1, write = 0
      .SAVE_out_ena(ss_req),  // one cycle high for each action
      .SAVE_out_be(ss_be),
      .SAVE_out_done(ss_ack),  // should be one cycle high when write is done or read value is valid

      .rewind_on    (use_rewind_capture),
      .rewind_active(use_rewind_capture & joystick_0[13])
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
          HShift <= 0;
          VShift <= 0;
        end
      end
    end
  end

  assign is_vertical = vertical;

  assign video_r = r;
  assign video_g = g;
  assign video_b = b;

  assign hsync   = hs;
  assign hblank  = hbl;

  assign vsync   = vs;
  assign vblank  = vbl;

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

    if (fastforward)
      ff_count <= ff_count + 1;

    if (~last_ffw & fastforward) begin
      ff_latch <= 0;
      ff_count <= 0;
    end

    if ((last_ffw & ~fastforward)) begin // 32mhz clock, 0.2 seconds
      ff_was_held <= 0;

      if (ff_count < 6400000 && ~ff_was_held) begin
        ff_was_held <= 1;
        ff_latch <= 1;
      end
    end

    fast_forward <= (fastforward | ff_latch);
  end

  ///////////////////////////// savestates /////////////////////////////////

  wire [63:0] SaveStateBus_Din;
  wire [ 9:0] SaveStateBus_Adr;
  wire        SaveStateBus_wren;
  wire        SaveStateBus_rst;
  wire [63:0] SaveStateBus_Dout;
  wire        savestate_load;

  wire [63:0] ss_dout, ss_din;
  wire [27:2] ss_addr;
  wire [ 7:0] ss_be;
  wire ss_rnw, ss_req, ss_ack;

  // assign DDRAM_CLK = clk_sys;
  // ddram ddram (
  //     .*,

  //     .ch1_addr({ss_addr, 1'b0}),
  //     .ch1_din(ss_din),
  //     .ch1_dout(ss_dout),
  //     .ch1_req(ss_req),
  //     .ch1_rnw(ss_rnw),
  //     .ch1_be(ss_be),
  //     .ch1_ready(ss_ack)
  // );

  // // saving with keyboard/OSD/gamepad
  // wire [1:0] ss_slot;
  // wire [7:0] ss_info;
  // wire ss_save, ss_load, ss_info_req;
  // wire statusUpdate;

  // savestate_ui savestate_ui (
  //     .clk          (clk_sys),
  //     .ps2_key      (ps2_key[10:0]),
  //     .allow_ss     (cart_ready),
  //     .joySS        (joy0_unmod[12]),
  //     .joyRight     (joy0_unmod[0]),
  //     .joyLeft      (joy0_unmod[1]),
  //     .joyDown      (joy0_unmod[2]),
  //     .joyUp        (joy0_unmod[3]),
  //     .joyStart     (joy0_unmod[6]),
  //     .joyRewind    (joy0_unmod[13]),
  //     .rewindEnable (status[27]),
  //     .status_slot  (status[38:37]),
  //     .OSD_saveload (status[29:28]),
  //     .ss_save      (ss_save),
  //     .ss_load      (ss_load),
  //     .ss_info_req  (ss_info_req),
  //     .ss_info      (ss_info),
  //     .statusUpdate (statusUpdate),
  //     .selected_slot(ss_slot)
  // );
  // defparam savestate_ui.INFO_TIMEOUT_BITS = 27;

  /////////////////////////  SRAM/EEPROM SAVE/LOAD  /////////////////////////////
  wire bk_load = status[41];
  wire bk_save = status[42];
  wire bk_autosave = status[43];
  wire bk_write = (EXTRAM_addr[24] && EXTRAM_write) || eepromWrite;

  wire eepromWrite;

  reg bk_ena = 0;
  reg bk_pending = 0;
  reg bk_loading = 0;

  reg bk_record_rtc = 0;

  wire extra_data_addr = 0;
  // wire extra_data_addr = sd_lba[11:0] > save_sz;

  // wire savepause = bk_state;

  wire has_rtc = 1'b1;

  wire saveIsSRAM = (ramtype == 8'h01) || (ramtype == 8'h02) || (ramtype == 8'h03) || (ramtype == 8'h04) || (ramtype == 8'h05);

  // always @(posedge clk_sys_36_864) begin
  // 	if (bk_write)      bk_pending <= 1;
  // 	else if (bk_state) bk_pending <= 0;
  // end
  // reg use_img;
  // reg [11:0] save_sz;

  // always @(posedge clk_sys_36_864) begin : size_block
  // 	reg old_downloading;

  // 	old_downloading <= cart_download;
  // 	if(~old_downloading & cart_download) {use_img, save_sz} <= 0;

  // 	if((~use_img && EXTRAM_write) || eepromWrite) begin
  // 		if(ramtype == 8'h01) save_sz <= save_sz | 12'hF;
  // 		if(ramtype == 8'h02) save_sz <= save_sz | 12'h3F;
  // 		if(ramtype == 8'h03) save_sz <= save_sz | 12'hFF;
  // 		if(ramtype == 8'h04) save_sz <= save_sz | 12'h1FF;
  // 		if(ramtype == 8'h05) save_sz <= save_sz | 12'h3FF;
  // 		if(ramtype == 8'h10) save_sz <= save_sz | 12'h003;
  // 		if(ramtype == 8'h20) save_sz <= save_sz | 12'h003;
  // 		if(ramtype == 8'h50) save_sz <= save_sz | 12'h003;
  // 	end

  // 	if(img_mounted && img_size && !img_readonly) begin
  // 		use_img <= 1;
  // 		if (!(img_size[20:9] & (img_size[20:9] - 12'd1))) // Power of two
  // 			save_sz <= img_size[20:9] - 1'd1;
  // 		else                                             // Assume one extra sector of RTC data
  // 			save_sz <= img_size[20:9] - 2'd2;
  // 	end

  // 	bk_ena <= |save_sz;
  // end

  // reg  bk_state  = 0;
  // wire bk_save_a = OSD_STATUS & bk_autosave;

  // reg [1:0] bk_state_int;
  // reg [3:0] bk_wait; 

  // always @(posedge clk_sys) begin
  // 	reg old_load = 0, old_save = 0, old_save_a = 0, old_ack;

  // 	old_load   <= bk_load;
  // 	old_save   <= bk_save;
  // 	old_save_a <= bk_save_a;
  // 	old_ack    <= sd_ack;

  // 	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;

  // 	if(!bk_state) begin
  // 		bram_tx_start <= 0;
  // 		bk_state_int  <= 0;
  // 		sd_lba        <= 0;
  //       bk_wait       <= 15;
  // 		time_dout     <= {5'd0, RTC_time, 42'd0};
  // 		bk_loading    <= 0;
  // 		if(bk_ena & ((~old_load & bk_load) | (~old_save & bk_save) | (~old_save_a & bk_save_a & bk_pending) | (cart_download & img_mounted))) begin
  // 			bk_state <= 1;
  // 			bk_loading <= bk_load | img_mounted;
  // 		end
  // 	end 
  //    else if (bk_wait > 0) begin 
  //       bk_wait <= bk_wait - 1'd1;
  //    end 
  //    else if(bk_loading) begin
  // 		case(bk_state_int)
  // 			0: begin
  // 					sd_rd <= 1;
  // 					bk_state_int <= 1;
  // 				end
  // 			1: if(old_ack & ~sd_ack) begin
  // 					bram_tx_start <= 1;
  // 					bk_state_int <= 2;
  // 				end
  // 			2: if(bram_tx_finish) begin
  // 					bram_tx_start <= 0;
  // 					bk_state_int <= 0;
  // 					sd_lba <= sd_lba + 1'd1;

  // 					// always read max possible size
  // 					if(sd_lba[11:0] == 12'h400) begin
  // 						bk_record_rtc <= 0;
  // 						bk_state <= 0;
  // 						RTC_load <= 0;
  // 					end
  // 				end
  // 		endcase

  // 		if (extra_data_addr) begin
  // 			if (~|sd_buff_addr && sd_buff_wr && sd_buff_dout == "RT") begin
  // 				bk_record_rtc <= 1;
  // 				RTC_load <= 0;
  // 			end
  // 		end

  // 		if (bk_record_rtc) begin
  // 			if (sd_buff_addr < 6 && sd_buff_addr >= 1)
  // 				time_dout[{sd_buff_addr[2:0] - 3'd1, 4'b0000} +: 16] <= sd_buff_dout;

  // 			if (sd_buff_addr > 5)
  // 				RTC_load <= 1;

  // 			if (&sd_buff_addr)
  // 				bk_record_rtc <= 0;
  // 		end
  // 	end
  // 	else begin
  // 		case(bk_state_int)
  // 			0: begin
  // 					bram_tx_start <= 1;
  // 					bk_state_int <= 1;
  // 				end
  // 			1: if(bram_tx_finish) begin
  // 					bram_tx_start <= 0;
  // 					sd_wr <= 1;
  // 					bk_state_int <= 2;
  // 				end
  // 			2: if(old_ack & ~sd_ack) begin
  // 					bk_state_int <= 0;
  // 					sd_lba <= sd_lba + 1'd1;

  // 					if (sd_lba[11:0] == {1'b0, save_sz} + (has_rtc ? 12'd1 : 12'd0))
  // 						bk_state <= 0;
  // 				end
  // 		endcase
  // 	end
  // end

  // transfer bram

  wire [127:0] time_din_h = {32'd0, time_din, "RT"};
  wire [15:0] bram_dout;
  wire [15:0] bram_din = saveIsSRAM ? sdr_bram_din : eeprom_din;
  wire bram_ack = saveIsSRAM ? sdr_bram_ack : eeprom_ack;
  assign sd_buff_din = extra_data_addr ? (time_din_h[{sd_buff_addr[2:0], 4'b0000} +: 16]) : bram_buff_out;
  wire [15:0] bram_buff_out;

  altsyncram altsyncram_component (
      .address_a(bram_addr),
      .address_b(sd_buff_addr),
      .clock0(clk_mem_110_592),
      .clock1(clk_sys_36_864),
      .data_a(bram_din),
      .data_b(sd_buff_dout),
      .wren_a(~bk_loading & bram_ack),
      .wren_b(sd_buff_wr && ~extra_data_addr),
      .q_a(bram_dout),
      .q_b(bram_buff_out),
      .byteena_a(1'b1),
      .byteena_b(1'b1),
      .clocken0(1'b1),
      .clocken1(1'b1),
      .rden_a(1'b1),
      .rden_b(1'b1)
  );
  defparam
  	altsyncram_component.address_reg_b = "CLOCK1",
  	altsyncram_component.clock_enable_input_a = "BYPASS",
  	altsyncram_component.clock_enable_input_b = "BYPASS",
  	altsyncram_component.clock_enable_output_a = "BYPASS",
  	altsyncram_component.clock_enable_output_b = "BYPASS",
  	altsyncram_component.indata_reg_b = "CLOCK1",
  	altsyncram_component.intended_device_family = "Cyclone V",
  	altsyncram_component.lpm_type = "altsyncram",
  	altsyncram_component.numwords_a = 256,
  	altsyncram_component.numwords_b = 256,
  	altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
  	altsyncram_component.outdata_aclr_a = "NONE",
  	altsyncram_component.outdata_aclr_b = "NONE",
  	altsyncram_component.outdata_reg_a = "UNREGISTERED",
  	altsyncram_component.outdata_reg_b = "UNREGISTERED",
  	altsyncram_component.power_up_uninitialized = "FALSE",
  	altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
  	altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
  	altsyncram_component.widthad_a = 8,
  	altsyncram_component.widthad_b = 8,
  	altsyncram_component.width_a = 16,
  	altsyncram_component.width_b = 16,
  	altsyncram_component.width_byteena_a = 1,
  	altsyncram_component.width_byteena_b = 1,
  	altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK1";

  reg [7:0] bram_addr;
  reg bram_tx_start;
  reg bram_tx_finish;
  reg bram_req;
  reg bram_state;

  always @(posedge clk_mem_110_592) begin

    bram_req <= 0;

    if (extra_data_addr && bram_tx_start) begin
      if (~&bram_addr) bram_tx_finish <= 1;
    end else if (~bram_tx_start) {bram_addr, bram_state, bram_tx_finish} <= 0;
    else if (~bram_tx_finish) begin
      if (!bram_state) begin
        bram_req   <= 1;
        bram_state <= 1;
      end else if (bram_ack) begin
        bram_state <= 0;
        if (~&bram_addr) bram_addr <= bram_addr + 1'd1;
        else bram_tx_finish <= 1;
      end
    end
  end

endmodule
