; ============================================================
; ONI PONG — a simple SNES homebrew game (Oni Protocol spinoff)
;
; You control the left paddle (D-pad Up/Down). The CPU controls
; the right paddle. First to 5 points wins; the match then
; restarts. The screen flashes oni-red when a point is scored.
;
; Assembles with ca65/ld65 (cc65 suite) into a 32KB LoROM .sfc
; that runs on RetroPie (lr-snes9x) and real hardware.
; ============================================================

.p816
.i16
.a8

; ------------------------------------------------------------
; Variables
; ------------------------------------------------------------
.segment "ZEROPAGE"
pad1:      .res 1        ; joypad 1, high byte ($4219): BYsSUDLR
ballx:     .res 1
bally:     .res 1
balldx:    .res 1        ; signed
balldy:    .res 1        ; signed
lpad_y:    .res 1
rpad_y:    .res 1
lscore:    .res 1
rscore:    .res 1
flash:     .res 1        ; >0: score flash / serve freeze countdown
serve_dir: .res 1        ; alternates each serve
frame_cnt: .res 1
tmp:       .res 1
tmp2:      .res 1

.segment "BSS"
oam_lo:    .res 512      ; shadow OAM, DMA'd to the PPU each vblank
oam_hi:    .res 32

; ------------------------------------------------------------
; Constants
; ------------------------------------------------------------
LPADX     = 16
RPADX     = 232
PAD_MINY  = 16
PAD_MAXY  = 168          ; paddle is 32px tall; bottom wall at 200
BALL_MINY = 16
BALL_MAXY = 192          ; ball is 8px tall
WIN_SCORE = 5

; ------------------------------------------------------------
; Reset / init
; ------------------------------------------------------------
.segment "CODE"

reset:
    sei
    clc
    xce                  ; leave 6502 emulation mode
    rep #$10
    .i16
    sep #$20
    .a8
    ldx #$1FFF
    txs
    lda #$00
    pha
    plb                  ; data bank = 0
    rep #$20
    .a16
    lda #$0000
    tcd                  ; direct page = 0
    sep #$20
    .a8

    lda #$8F
    sta $2100            ; forced blank, full brightness

    ; zero PPU registers $2101-$2133
    ldx #$0000
@clrppu:
    stz $2101,x
    inx
    cpx #$0033
    bne @clrppu

    stz $4200            ; no NMI/IRQ/auto-joypad yet
    lda #$FF
    sta $4201
    stz $420B            ; no DMA
    stz $420C            ; no HDMA
    stz $420D            ; slow ROM

    ; ---- upload sprite tiles to VRAM $0000
    lda #$80
    sta $2115            ; increment after $2119 write
    ldx #$0000
    stx $2116
    lda #$01
    sta $4300            ; DMA0: CPU->PPU, write $2118/$2119
    lda #$18
    sta $4301
    ldx #.loword(tiles)
    stx $4302
    lda #^tiles
    sta $4304
    ldx #tiles_end - tiles
    stx $4305
    lda #$01
    sta $420B

    ; ---- palette
    stz $2121
    lda #$44
    sta $2122
    lda #$20
    sta $2122            ; backdrop = dark violet ($2044)
    lda #$80
    sta $2121            ; sprite palette 0 (CGRAM 128)
    stz $2122
    stz $2122            ; color 0: transparent
    lda #$FF
    sta $2122
    lda #$7F
    sta $2122            ; color 1: white (paddles / score pips)
    lda #$5F
    sta $2122
    lda #$01
    sta $2122            ; color 2: oni red-orange ($015F)

    ; ---- sprites
    stz $2101            ; OBSEL: 8x8 sprites, tiles at VRAM $0000
    lda #$10
    sta $212C            ; main screen: OBJ only
    stz $212D

    ; hide all 128 sprites, clear the OAM high table
    ldx #$0000
@hideoam:
    stz oam_lo,x
    lda #$F0
    sta oam_lo+1,x
    stz oam_lo+2,x
    stz oam_lo+3,x
    inx
    inx
    inx
    inx
    cpx #512
    bne @hideoam
    ldx #$0000
@clrhi:
    stz oam_hi,x
    inx
    cpx #32
    bne @clrhi

    ; ---- game state
    lda #96
    sta lpad_y
    sta rpad_y
    stz lscore
    stz rscore
    stz flash
    stz serve_dir
    stz frame_cnt
    stz pad1
    jsr serve_ball
    jsr build_oam

    ; ---- screen on, enable NMI + auto joypad read
    lda #$0F
    sta $2100
    lda #$81
    sta $4200

; ------------------------------------------------------------
; Main loop (one iteration per frame)
; ------------------------------------------------------------
main_loop:
    wai                  ; wait for vblank NMI
    jsr read_pad
    jsr move_player
    jsr move_ai
    lda flash
    beq @ball_go
    dec flash            ; ball frozen during score flash
    bra @ball_done
@ball_go:
    jsr move_ball
@ball_done:
    jsr build_oam
    bra main_loop

; ------------------------------------------------------------
; Input
; ------------------------------------------------------------
read_pad:
@wait:
    lda $4212            ; wait for auto joypad read to finish
    lsr a
    bcs @wait
    lda $4219
    sta pad1
    rts

move_player:
    lda pad1
    and #$08             ; Up
    beq @not_up
    lda lpad_y
    sec
    sbc #3
    cmp #PAD_MINY
    bcs @set_u
    lda #PAD_MINY
@set_u:
    sta lpad_y
@not_up:
    lda pad1
    and #$04             ; Down
    beq @not_down
    lda lpad_y
    clc
    adc #3
    cmp #PAD_MAXY
    bcc @set_d
    lda #PAD_MAXY
@set_d:
    sta lpad_y
@not_down:
    rts

; ------------------------------------------------------------
; CPU paddle: tracks the ball, but only once it crosses x=140
; and only while the ball is moving toward it — so sharp
; deflections can beat it.
; ------------------------------------------------------------
move_ai:
    lda balldx
    bmi @done            ; ball moving away
    lda ballx
    cmp #140
    bcc @done
    lda bally
    sec
    sbc #12              ; target: center paddle on ball
    sta tmp
    cmp rpad_y
    beq @done
    bcc @up
    lda tmp              ; move down (unsigned diff, no overflow)
    sec
    sbc rpad_y
    cmp #2
    bcs @move_d
    lda tmp              ; within 1px: snap, no jitter
    bra @clamp_d
@move_d:
    lda rpad_y
    clc
    adc #2
@clamp_d:
    cmp #PAD_MAXY
    bcc @ok_d
    lda #PAD_MAXY
@ok_d:
    sta rpad_y
    rts
@up:
    lda rpad_y
    sec
    sbc tmp
    cmp #2
    bcs @move_u
    lda tmp
    bra @clamp_u
@move_u:
    lda rpad_y
    sec
    sbc #2
@clamp_u:
    cmp #PAD_MINY
    bcs @ok_u
    lda #PAD_MINY
@ok_u:
    sta rpad_y
@done:
    rts

; ------------------------------------------------------------
; Ball physics
; ------------------------------------------------------------
move_ball:
    ; vertical: bounce off top/bottom walls
    lda bally
    clc
    adc balldy
    sta bally
    cmp #BALL_MINY
    bcs @not_top
    lda #BALL_MINY
    sta bally
    jsr negate_dy
@not_top:
    lda bally
    cmp #BALL_MAXY
    bcc @not_bottom
    lda #BALL_MAXY
    sta bally
    jsr negate_dy
@not_bottom:

    ; horizontal
    lda ballx
    clc
    adc balldx
    sta ballx
    lda balldx
    bmi @leftward

    ; --- moving right: right paddle front face is at x=224
    lda ballx
    cmp #RPADX-8
    bcc @done
    cmp #244
    bcs @left_point      ; sailed past: player scores
    lda rpad_y
    sta tmp2
    jsr ball_overlaps
    bcc @done
    lda #RPADX-9
    sta ballx
    lda #$FE             ; dx = -2
    sta balldx
    lda rpad_y
    sta tmp2
    jsr deflect
    bra @done

@leftward:
    ; --- moving left: left paddle front face is at x=24
    lda ballx
    cmp #244
    bcs @right_point     ; wrapped past x=0: CPU scores
    cmp #LPADX+8
    bcs @done
    cmp #8
    bcc @done            ; already behind the paddle
    lda lpad_y
    sta tmp2
    jsr ball_overlaps
    bcc @done
    lda #LPADX+8
    sta ballx
    lda #$02             ; dx = +2
    sta balldx
    lda lpad_y
    sta tmp2
    jsr deflect
@done:
    rts

@left_point:
    inc lscore
    jmp point_scored
@right_point:
    inc rscore
    jmp point_scored

negate_dy:
    lda balldy
    eor #$FF
    inc a
    sta balldy
    rts

; carry set on return if the ball overlaps the paddle at y=tmp2
ball_overlaps:
    lda bally
    clc
    adc #8
    cmp tmp2
    bcc @no              ; ball bottom above paddle top
    lda tmp2
    clc
    adc #32
    cmp bally
    bcc @no              ; paddle bottom above ball top
    sec
    rts
@no:
    clc
    rts

; set balldy from where the ball struck the paddle (y=tmp2):
; outer thirds deflect steeply (±2), the middle gently (±1)
deflect:
    lda bally
    clc
    adc #4               ; ball center
    sec
    sbc tmp2
    sec
    sbc #16              ; rel = ball center - paddle center (signed)
    bmi @above
    cmp #8
    bcc @gentle_down
    lda #$02
    bra @set
@gentle_down:
    lda #$01
    bra @set
@above:
    eor #$FF
    inc a                ; abs(rel)
    cmp #8
    bcc @gentle_up
    lda #$FE             ; -2
    bra @set
@gentle_up:
    lda #$FF             ; -1
@set:
    sta balldy
    rts

point_scored:
    lda #40
    sta flash
    lda lscore
    cmp #WIN_SCORE
    bcs @new_match
    lda rscore
    cmp #WIN_SCORE
    bcs @new_match
    bra @serve
@new_match:
    stz lscore
    stz rscore
    lda #90              ; longer pause between matches
    sta flash
@serve:
    ; fall through

serve_ball:
    lda #124
    sta ballx
    lda #108
    sta bally
    lda serve_dir
    eor #$01
    sta serve_dir
    beq @to_left
    lda #$02
    bra @set_dx
@to_left:
    lda #$FE
@set_dx:
    sta balldx
    lda frame_cnt
    and #$01
    beq @dy_up
    lda #$01
    bra @set_dy
@dy_up:
    lda #$FF
@set_dy:
    sta balldy
    rts

; ------------------------------------------------------------
; Rebuild the shadow OAM from game state
; sprites 0-3: left paddle   4-7: right paddle   8: ball
; sprites 9-13: player score pips   14-18: CPU score pips
; ------------------------------------------------------------
build_oam:
    ; left paddle (4 stacked 8x8 tiles)
    ldx #$0000
    lda lpad_y
    sta tmp
    lda #4
    sta tmp2
@lpad:
    lda #LPADX
    sta oam_lo,x
    lda tmp
    sta oam_lo+1,x
    stz oam_lo+2,x       ; tile 0: solid block
    lda #$30             ; priority 3, palette 0
    sta oam_lo+3,x
    lda tmp
    clc
    adc #8
    sta tmp
    inx
    inx
    inx
    inx
    dec tmp2
    bne @lpad

    ; right paddle
    lda rpad_y
    sta tmp
    lda #4
    sta tmp2
@rpad:
    lda #RPADX
    sta oam_lo,x
    lda tmp
    sta oam_lo+1,x
    stz oam_lo+2,x
    lda #$30
    sta oam_lo+3,x
    lda tmp
    clc
    adc #8
    sta tmp
    inx
    inx
    inx
    inx
    dec tmp2
    bne @rpad

    ; ball (sprite 8)
    lda ballx
    sta oam_lo+32
    lda bally
    sta oam_lo+33
    lda #$01             ; tile 1: ball
    sta oam_lo+34
    lda #$30
    sta oam_lo+35

    ; player score pips, left-to-right from x=16
    ldx #36
    lda #16
    sta tmp
    stz tmp2
@lpips:
    lda tmp
    sta oam_lo,x
    lda tmp2
    cmp lscore
    bcc @lvis
    lda #$F0             ; hidden
    bra @lset_y
@lvis:
    lda #6
@lset_y:
    sta oam_lo+1,x
    stz oam_lo+2,x
    lda #$30
    sta oam_lo+3,x
    lda tmp
    clc
    adc #10
    sta tmp
    inx
    inx
    inx
    inx
    inc tmp2
    lda tmp2
    cmp #5
    bne @lpips

    ; CPU score pips, right-to-left from x=232
    ldx #56
    lda #232
    sta tmp
    stz tmp2
@rpips:
    lda tmp
    sta oam_lo,x
    lda tmp2
    cmp rscore
    bcc @rvis
    lda #$F0
    bra @rset_y
@rvis:
    lda #6
@rset_y:
    sta oam_lo+1,x
    stz oam_lo+2,x
    lda #$30
    sta oam_lo+3,x
    lda tmp
    sec
    sbc #10
    sta tmp
    inx
    inx
    inx
    inx
    inc tmp2
    lda tmp2
    cmp #5
    bne @rpips
    rts

; ------------------------------------------------------------
; NMI: DMA shadow OAM to the PPU, update backdrop flash
; ------------------------------------------------------------
nmi_handler:
    rep #$30
    .a16
    .i16
    pha
    phx
    phy
    sep #$20
    .a8
    lda $4210            ; acknowledge NMI
    inc frame_cnt

    stz $2102
    stz $2103
    stz $4300            ; DMA0: CPU->PPU, single reg $2104 (OAM data)
    lda #$04
    sta $4301
    ldx #.loword(oam_lo)
    stx $4302
    stz $4304
    ldx #544
    stx $4305
    lda #$01
    sta $420B

    stz $2121            ; backdrop: oni red while flashing, else violet
    lda flash
    beq @normal
    lda #$1F
    sta $2122
    lda #$00
    sta $2122
    bra @color_done
@normal:
    lda #$44
    sta $2122
    lda #$20
    sta $2122
@color_done:
    rep #$30
    .a16
    ply
    plx
    pla
    rti
    .a8

dummy_int:
    rti

; ------------------------------------------------------------
; Graphics: two 4bpp 8x8 tiles
; ------------------------------------------------------------
.segment "RODATA"
tiles:
; tile 0: solid block, palette color 1 (plane 0 set)
.byte $FF,$00, $FF,$00, $FF,$00, $FF,$00
.byte $FF,$00, $FF,$00, $FF,$00, $FF,$00
.byte $00,$00, $00,$00, $00,$00, $00,$00
.byte $00,$00, $00,$00, $00,$00, $00,$00
; tile 1: round ball, palette color 2 (plane 1 set)
.byte $00,$3C, $00,$7E, $00,$FF, $00,$FF
.byte $00,$FF, $00,$FF, $00,$7E, $00,$3C
.byte $00,$00, $00,$00, $00,$00, $00,$00
.byte $00,$00, $00,$00, $00,$00, $00,$00
tiles_end:

; ------------------------------------------------------------
; SNES internal ROM header ($FFC0) — checksum fixed post-link
; ------------------------------------------------------------
.segment "HEADER"
.byte "ONI PONG             "   ; 21-byte title
.byte $20                       ; LoROM, slow
.byte $00                       ; no extra chips
.byte $05                       ; 32KB ROM
.byte $00                       ; no SRAM
.byte $01                       ; NTSC (USA)
.byte $00                       ; licensee
.byte $00                       ; version
.word $FFFF                     ; checksum complement (placeholder)
.word $0000                     ; checksum (placeholder)

.segment "VECTORS"
; native mode: -, -, COP, BRK, ABORT, NMI, -, IRQ
.word 0, 0, dummy_int, dummy_int, dummy_int, nmi_handler, 0, dummy_int
; emulation mode: -, -, COP, -, ABORT, NMI, RESET, IRQ/BRK
.word 0, 0, dummy_int, 0, dummy_int, dummy_int, reset, dummy_int
