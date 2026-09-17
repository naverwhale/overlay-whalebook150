CONFIG_VENDOR_GOOGLE=y
CONFIG_BOARD_GOOGLE_RUBY=y
CONFIG_VBOOT_FWID_MODEL="Google_Ruby"

# Enable OEM screen logo (center)
CONFIG_CHROMEOS_LOGO_PATH="bootsplash_assets/oem_main_logo/137b7852/logo_200_percent.bmp"
CONFIG_CHROMEBOOK_PLUS_LOGO_PATH="bootsplash_assets/oem_main_logo/137b7852/logo_100_percent.bmp"

# Low-battery indicator
CONFIG_PLATFORM_LOW_BATTERY_INDICATOR_LOGO_PATH="bootsplash_assets/battery_low_200_percent.bmp"

# SPI Descriptor
CONFIG_IFD_BIN_PATH="3rdparty/blobs/mainboard/google/fatcat/descriptor-ruby.bin"

# CSE data
# CONFIG_CSE_DATA_FILE="cse_data/cse_data-ruby.bin"
CONFIG_ME_BIN_PATH="3rdparty/blobs/mainboard/google/fatcat/csme-ruby.bin"
CONFIG_SOC_INTEL_CSE_RW_FILE="3rdparty/blobs/mainboard/google/fatcat/me_rw-ruby.bin"

# Video Blob
CONFIG_INTEL_GMA_VBT_FILE="3rdparty/blobs/mainboard/google/fatcat/vbt/vbt-ruby.bin"

# Microcode
CONFIG_CPU_INTEL_UCODE_SPLIT_BINARIES="3rdparty/blobs/mainboard/google/fatcat/microcode_inputs/ruby"
