# SRAM macros

proc sram_pdn_ns {pdnname macrolist} {
    define_pdn_grid \
        -macro \
        -instances $macrolist \
        -name $pdnname \
        -starts_with POWER \
        -halo "$::env(PDN_HORIZONTAL_HALO) $::env(PDN_VERTICAL_HALO)"

    add_pdn_connect \
        -grid $pdnname \
        -layers "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)"

    add_pdn_connect \
        -grid $pdnname \
        -layers "$::env(PDN_VERTICAL_LAYER) Metal3"

    # Add stripes on W/E edges of SRAM
    add_pdn_stripe \
        -grid $pdnname \
        -layer Metal4 \
        -width 1.36 \
        -offset 0.68 \
        -spacing 0.28 \
        -pitch 298.30 \
        -starts_with GROUND \
        -number_of_straps 2

    # Since the above stripes block the top level PDN at Metal4, add some more stripes
    # to improve the PDN's integrity and ensure a better connection for the macro.
    add_pdn_stripe \
        -grid $pdnname \
        -layer Metal4 \
        -width 4.00 \
        -offset 50.80 \
        -spacing 0.28 \
        -pitch 48.86 \
        -starts_with GROUND \
        -number_of_straps 5

}

sram_pdn_ns pdn_cpu_ram    i_chip_core.tt.i_tinyqv.cpu.i_scratch.i_sram
sram_pdn_ns pdn_text_ram0  i_chip_core.i_text.i_sram0
sram_pdn_ns pdn_text_ram1  i_chip_core.i_text.i_sram1
sram_pdn_ns pdn_text_ram2  i_chip_core.i_text.i_sram2

