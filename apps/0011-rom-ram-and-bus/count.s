LEDS = $8000

.segment "CODE"
reset:
        lda #$00
loop:
        sta LEDS
        clc
        adc #$01
        jmp loop
