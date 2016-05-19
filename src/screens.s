; Princess Engine
; Copyright (C) 2016 NovaSquirrel
;
; This program is free software: you can redistribute it and/or
; modify it under the terms of the GNU General Public License as
; published by the Free Software Foundation; either version 3 of the
; License, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
.proc ShowTitle
; Turn on NMIs
  lda #VBLANK_NMI | NT_2000 | OBJ_8X8 | BG_0000 | OBJ_0000
  sta PPUCTRL

; Upload the palette, nametable and graphics
  lda #0
  sta PPUMASK
  lda #$30
  sta LevelBackgroundColor
  lda #GraphicsUpload::TITLE_CHR
  jsr DoGraphicUpload
  lda #GraphicsUpload::TITLE_NAM
  jsr DoGraphicUpload
  lda #GraphicsUpload::TITLE_PAL
  jsr DoGraphicUpload
  ; Clear sprites too
  jsr ClearOAM
  lda #2
  sta OAM_DMA

  ; See if we have extra RAM
  ; and display an error if it's missing
  ldx #7
  lda SaveTag
  cmp SaveTagString
  beq HaveExtraRAM
  lda #$0f
  sta PPUADDR
  lda #$00
  sta PPUADDR
  tax
  jsr WritePPURepeated

  lda #VWF_BANK
  jsr SetPRG
  lda #$23
  sta PPUADDR
  lda #$48
  sta PPUADDR
  ldy #$f0
  ldx #16
  jsr WriteIncreasing
  ldx #15
  lda #>NoRAMError
  ldy #<NoRAMError
  jsr vwfPutsAtRow
HaveExtraRAM:

; Turn on the display and get it ready
  jsr WaitVblank
  lda #BG_ON
  sta PPUMASK
  lda #VBLANK_NMI | NT_2000 | OBJ_8X8 | BG_0000 | OBJ_0000
  sta PPUCTRL
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL

DisplayLoop:
  jsr WaitVblank
  jsr ReadJoy
  lda keydown
  and #KEY_START
  bne Exit
  jmp DisplayLoop
Exit:
  jsr WaitVblank
  jsr ReadJoy
  lda keydown
  and #KEY_START
  bne Exit

  ; Disable rendering again
  jsr WaitVblank
  lda #0
  sta PPUMASK
  rts
.endproc

NoRAMError: .byt "No WRAM, so game won't work!",0

.proc ShowDie
  jsr WaitVblank
  lda #$3f
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ; Set the palette to black and red
  ldx #4
: lda #$0f
  sta PPUDATA
  lda #$06
  sta PPUDATA
  lda #$16
  sta PPUDATA
  lda #$26
  sta PPUDATA
  dex
  bne :-
  jsr UpdateScrollRegister

  ; Play the sample
  lda #SOUND_BANK
  jsr SetPRG
  jsr quadpcm_play_die

  ; Restore checkpoint
  ldy #GameStateLen-1
: lda CheckpointGameState,y
  sta CurrentGameState,y
  dey
  bpl :-

  lda CheckpointX
  sta PlayerPXH
  lda #0
  sta PlayerPXL
  sta PlayerAbility
  lda CheckpointY
  sta PlayerPYH
  inc IsNormalDoor ; skip setting X and Y

  lda CheckpointLevelNumber
  jmp StartLevel_FromCheckpoint
.endproc

.proc ShowCredits
  rts
.endproc
