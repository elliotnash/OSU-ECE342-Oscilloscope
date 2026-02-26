MEMORY {
    BOOT2   : ORIGIN = 0x10000000, LENGTH = 0x100
    FLASH   : ORIGIN = 0x10000100, LENGTH = 14336K - 0x100
    STORAGE : ORIGIN = ORIGIN(FLASH) + LENGTH(FLASH), LENGTH = 2048K
    RAM     : ORIGIN = 0x20000000, LENGTH = 264K
}

__logical_binary_start = ORIGIN(FLASH);
__flash_size = 16777216;
__storage_flash_size = 2097152;
__storage_flash_offset = ORIGIN(STORAGE) - ORIGIN(BOOT2);

SECTIONS {
    /* 1. Catch the orphaned boot_info so it doesn't spill into BOOT2 */
    .boot_info : ALIGN(4) {
        KEEP(*(.boot_info));
    } > FLASH

    /* 2. Place the picotool entries AFTER .text to avoid overlap */
    .bi_entries : ALIGN(4) {
        __bi_entries_start = .;
        KEEP(*(.bi_entries));
        . = ALIGN(4);
        __bi_entries_end = .;
    } > FLASH
} INSERT AFTER .text;