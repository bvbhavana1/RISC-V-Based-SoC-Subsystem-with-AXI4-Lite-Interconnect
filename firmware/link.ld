
/* =============================================================================
 * link.ld – Linker Script for PicoRV32 SoC
 *
 * Memory map:
 *   ROM  (rx)  : 0x00000000 – 0x00001FFF  (8 KB – program + read-only data)
 *   SRAM (rwx) : 0x00010000 – 0x00011FFF  (8 KB – data + stack)
 * ============================================================================= */

MEMORY {
    ROM  (rx)  : ORIGIN = 0x00000000, LENGTH = 8K
    SRAM (rwx) : ORIGIN = 0x00010000, LENGTH = 256
}

ENTRY(_start)

SECTIONS {
    /* ── Program code ─────────────────────────────────────────────────── */
    .text : {
        *(.text.start)      /* crt0 entry point first */
        *(.text*)
    } > ROM

    /* ── Read-only data (string literals, etc.) ────────────────────────── */
    .rodata : {
        *(.rodata*)
    } > ROM

    /* ── Initialized data – stored in ROM, copied to SRAM at boot ─────── */
    .data : {
        *(.data*)
    } > SRAM AT> ROM

    /* ── BSS – zero-filled by crt0 ─────────────────────────────────────── */
    .bss : {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > SRAM

    /* Provide symbols for crt0 */
    _stack_top = ORIGIN(SRAM) + LENGTH(SRAM);
}
