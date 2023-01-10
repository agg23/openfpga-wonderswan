architecture chip32.vm
output "chip32.bin", create

// we will put data into here that we're working on.  It's the last 1K of the 8K chip32 memory
constant rambuf = 0x1b00

constant rom_dataslot = 0
constant bw_bios_dataslot = 9
constant color_bios_dataslot = 10
constant save_dataslot = 11

constant cart_download_addr = 0x0
constant is_color_cart_addr = 0x4

constant bw_bios_download_addr = 0x8
constant color_bios_download_addr = 0xC

constant save_download_addr = 0x10

// Host init command
constant host_init = 0x4002

macro load_asset(variable ioctl_download_addr, variable dataslot_id, variable error_msg) {
  ld r1,#ioctl_download_addr // Set address for write
  ld r2,#1 // Downloading start
  pmpw r1,r2 // Write ioctl_download = 1

  ld r3,#dataslot_id
  ld r14,#error_msg
  loadf r3 // Load asset

  if error_msg != 0 {
    // Only throw error if an error msg provided
    jp nz,print_error_and_exit
  }

  // ld r1,#ioctl_download_addr // Set address for write
  ld r2,#0 // Downloading end
  pmpw r1,r2 // Write ioctl_download = 0
}

macro load_bios_asset(variable ioctl_download_addr, variable dataslot_id, variable error_msg) {
  ld r3,#dataslot_id
  ld r14,#error_msg
  queryslot r3 // Check if BIOS exists

  jp nz,print_error_and_exit

  load_asset(ioctl_download_addr, dataslot_id, error_msg)
}

// Error vector (0x0)
jp error_handler

// Init vector (0x2)
// Choose core
ld r0,#0
core r0

ld r1,#rom_dataslot // populate data slot
ld r2,#rambuf // get ram buf position
getext r1,r2
ld r1,#ext_wsc
test r1,r2
jp z,set_wsc // Set wsc

dont_set_wsc:
ld r3,#0
jp start_load

set_wsc:
ld r3,#1

start_load:
ld r1,#is_color_cart_addr
pmpw r1,r3 // Write is_color_cart = r3

// Load cart
load_asset(cart_download_addr, rom_dataslot, rom_err_msg)

// Load BIOS
load_bios_asset(bw_bios_download_addr, bw_bios_dataslot, bw_bios_err_msg)
load_bios_asset(color_bios_download_addr, color_bios_dataslot, color_bios_err_msg)

// Load save
load_asset(save_download_addr, save_dataslot, 0)

// Start core
ld r0,#host_init
host r0,r0

exit 0

// Error handling
error_handler:
ld r14,#test_err_msg

print_error_and_exit:
printf r14
exit 1

ext_wsc:
db "WSC",0

test_err_msg:
db "Error",0

rom_err_msg:
db "Could not load ROM",0

color_bios_err_msg:
db "No Color BIOS found",0

bw_bios_err_msg:
db "No B&W BIOS found",0