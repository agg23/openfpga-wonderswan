# WonderSwan Color for Analogue Pocket

Ported from the original core developed by [Robert Piep](https://github.com/RobertPeip) ([Patreon](https://www.patreon.com/FPGAzumSpass)). Core icon provided by [spiritualized1997](https://github.com/spiritualized1997). Latest upstream available at https://github.com/MiSTer-devel/WonderSwan_MiSTer

Please report any issues encountered to this repo. Most likely any problems are a result of my port, not the original core. Issues will be upstreamed as necessary.

## Installation

### Easy mode

I highly recommend the updater tools by [@mattpannella](https://github.com/mattpannella) and [@RetroDriven](https://github.com/RetroDriven). If you're running Windows, use [the RetroDriven GUI](https://github.com/RetroDriven/Pocket_Updater), or if you prefer the CLI, use [the mattpannella tool](https://github.com/mattpannella/pocket_core_autoupdate_net). Either of these will allow you to automatically download and install openFPGA cores onto your Analogue Pocket. Go donate to them if you can

### Manual mode
Download the core by clicking Releases on the right side of this page, then download the `agg23.*.zip` file from the latest release.

To install the core, copy the `Assets`, `Cores`, and `Platform` folders over to the root of your SD card. Please note that Finder on macOS automatically _replaces_ folders, rather than merging them like Windows does, so you have to manually merge the folders.

## Usage

ROMs should be placed in `/Assets/wonderswan/common/`

You must provide the BIOS files for both the original and WonderSwan Color. The BIOSes should be named `bw.rom` and `color.rom`, and should be placed in `/Assets/wonderswan/common/`.

WonderSwan
* `bw.rom`
* MD5: 54B915694731CC22E07D3FB8A00EE2DB

WonderSwan Color
* `color.rom`
* MD5: 880893BD5A7D53FFF826BD76A83D566E

## Features

### Save States/Sleep + Wake

Known as "Memories" on the Pocket, this core supports the creation and loading of save states, and by extension, the core also supports Sleep + Wake functionality. Tapping the power button while playing will suspend the game, ready to be resumed when powering the Pocket back on.

### Fast Forward

Hold the `-` button (default) to run the WonderSwan at 2.5x speed. Tapping the button will lock fast forward on, and it will continue fast forwarding until the button is pressed again.

### Controls

The WonderSwan has a lot of buttons for a handheld in an unusual layout. The default button mappings for the Pocket are as close as I can get to the original control layout.

<table>
<tr>
  <th>Horizontal</th>
  <th>Vertical</th>
</tr>
<tr><td>

| Pocket  | WonderSwan |
|---------|------------|
| D-pad   | X buttons  |
| A       | A          |
| B       | B          |
| X       | Y3         |
| Y       | Y4         |
| L. Trig | Y1         |
| R. Trig | Y2         |
| +       | Start      |
| -       |Fast Forward|

</td><td>

| Pocket  | WonderSwan |
|---------|------------|
| D-pad   | Y buttons  |
| A       | X3         |
| B       | X4         |
| X       | X2         |
| Y       | X1         |
| L. Trig | A          |
| R. Trig | B          |
| +       | Start      |
| -       |Fast Forward|

</td></tr></table>

### System Settings

* `System Type` - Choose what type of WonderSwan to boot. Changing this option requires resetting the core
* `CPU Turbo` - Allows the CPU to perform additional processing per frame, which can be used to eliminate some slowdowns.

### Video Settings

The WonderSwan has a native refresh rate of 75.4Hz, but the Analogue Pocket doesn't support higher than ~62Hz (and 60Hz on the Dock). This core provides the option to either run the display directly at 60Hz, introducing tearing, or to triple buffer frames at 60Hz, introducing latency and skipping some frames entirely.

* `Triple Buffer` - Triple buffer image to prevent tearing. Please note that this does increase latency and will cause frames to be dropped.
* `Flickerblend` - Use a combination of 2 or 3 frames of data to perform blending on flickering UI elements. This will decrease the flickering and resolve the flicker into a lighter grey color. Please note that this enables the frame buffer implicitly.
* `Orientation` - Lock the screen rotation to a particular direction. When set to `Auto`, the core will automatically rotate the display.
* `Flip Horizontal` - Flips the display whenever the WonderSwan would display in horizontal mode.

### Sound Settings

* `Fast Forward` - If enabled, play sound when fast forward is active.