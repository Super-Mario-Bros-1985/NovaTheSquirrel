; pd.. bbbb
; ||   ++++- bank, 0-15
; |+-------- 1 if palette should be uploaded without any buffering
; +--------- 1 if this is a palette

IS_GRAPHIC =        %00000000 ; compressed graphics
IS_PALETTE =        %10000000 ; palette colors
IS_DIRECT_PALETTE = %01000000
;banks available: GRAPHICS_BANK1, GRAPHICS_BANK2, GRAPHICS_BANK3

.include "../tools/graphicslist2.s"
  
; input: A (graphic number)
DoGraphicUpload:
  pha
  lda #0
  sta 0
  pla
; Uploads graphics from GraphicsList, but with an offset
; input: A (graphic number), 0 (offset)
.proc DoGraphicUpload_Off
Temp = 1
Pointer = 2
  sta Temp
  pushaxy

  ; multiply by 3 since every entry is 3 bytes long
  lda Temp
  asl      ; change if GraphicsList grows to over 85 entries
  add Temp
  tax

  ; now get the bank number and switch to the proper bank
  lda GraphicsList+0,x
  sta Temp ; save the flags+bank byte
  and #15
  jsr _SetPRG
  ; get the pointer too
  lda GraphicsList+1,x
  sta Pointer+0
  lda GraphicsList+2,x
  sta Pointer+1

  ; if the most significant bit is set, it's a palette, not graphics
  lda Temp
  cmp #%01000000
  bcc NotPalette
    cmp #%10000000
    bcs BufferedPalette
    ; set the PPU address
    ; the first byte of the palette data specifies the palette start and palette length
    ldy #0
    lda #$3f
    sta PPUADDR
    lda (Pointer),y
    pha
    lsr
    lsr
    and #%011100
    sta PPUADDR ; address is set
    pla
    and #15     ; get just the length, from the bottom half
    sta Temp
    ; write the palette colors in
  : lda LevelBackgroundColor
    sta PPUDATA
    .repeat 3
      iny
      lda (Pointer),y
      sta PPUDATA
    .endrep
    dec Temp
    bpl :-
    ; don't do the graphics decompression, these aren't graphics
    ; we still need to pullaxy though
    jmp NotCompressedGraphics
NotPalette:
  CompressedGraphics:
    lda Pointer+0
    ldy Pointer+1
    ldx 0
    jsr DecompressCHR_Off
NotCompressedGraphics:

  jsr SetPRG_Restore
  pullaxy
  rts

BufferedPalette:
  ; set the PPU address
  ; the first byte of the palette data specifies the palette start and palette length
  ldy #0
  lda (Pointer),y
  pha
  lsr
  lsr
  and #%011100
  tax ; address to write to
  pla
  and #15     ; get just the length, from the bottom half
  sta Temp
  ; write the palette colors in
: inx
  .repeat 3
    iny
    lda (Pointer),y
    sta Attributes,x
    inx
  .endrep
  dec Temp
  bpl :-
  jmp NotCompressedGraphics
.endproc

; Decompresses a graphics file
; input: YA (address of the graphics)
DecompressCHR: ; no offset used
  ldx #0

; Decompresses a graphics file with an offset
; input: YA (address of the graphics), X (offset in rows)
.proc DecompressCHR_Off
; offset used, destination row has X added to it
ChunksLeft = 3
  ; write pointer to info
  sta 0
  sty 1

  ldy #2
  lda (0),y
  sta ChunksLeft
  ; write high PPU address byte
  dey
  txa
  add (0),y   ; 16 tiles = 256 bytes, so we can just add to the high byte
  sta PPUADDR

  ; write low PPU address byte
  dey
  lda (0),y
  sta PPUADDR

  ; move pointer to the actual data
  lda 0
  add #3
  sta ciSrc+0
  lda 1
  adc #0       ; carry over to the next page if needed
  sta ciSrc+1

  lda #0
  sta ciBufStart
  lda #128
  sta ciBufEnd
ChunksLoop:
  jsr unpb53_some
  ldx #0
: lda PB53_outbuf,x
  sta PPUDATA
  inx
  cpx #128
  bne :-
  dec ChunksLeft
  bne ChunksLoop
  jmp ClearOAM
.endproc
