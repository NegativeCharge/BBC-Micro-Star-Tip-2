; Tim Follin's Star Tip 2 ported to the Commodore PET by David Given
; The music is Follin's, the code is mine. My bits are CC0. Enjoy.
; BBC Micro port by Negative Charge, June 2025.
; Assemble with beebasm.

SHEILABASE              = $FE00             ; System peripherals
SYSVIA_DDRA             = SHEILABASE + $43  ; Data direction register A
SYSVIA_ORAS             = SHEILABASE + $4F  ; Same as REGA but with no handshake I/O
SYSVIA_REGB             = SHEILABASE + $40  ; Port B I/O
SYSVIA_REGA             = SHEILABASE + $41  ; Port A I/O

MAX_PULSE_LEN           = 16
TICKS_PER_VOL_STEP      = 10

org 0
.ptr			equw 0
.note_duration	equw 0
.note_attack	equb 0
.note_volume	equb 0
.note_decay	    equb 0
.n1				equb 0
.n2				equb 0
.n3				equb 0
.pulse_length	equb 0
.attack			equb 0
.attack_flag	equb 0
.duration       equw 0
.etimer			equb 0
.decay			equb 0

org &1100
guard &7c00
.start
    
; Write data to sound chip then add processing delay
MACRO sound_write_slow
    sta     SYSVIA_ORAS        ;4 Write reg/data to SN76489

    lda     #%00000000         ;2
    sta     SYSVIA_REGB        ;4 
    nop                        ;2
    nop                        ;2
    nop                        ;2
    lda     #%00001000         ;2
    sta     SYSVIA_REGB        ;4
ENDMACRO

MACRO RESET_SOUND_CHIP
    ; Zero volumes on all SN76489 channels, just in case anything already playing
    lda     #%11111111
    sound_write_slow                                ; Channel 3 (Noise)
    lda     #%11011111
    sound_write_slow                                ; Channel 2
    lda     #%10111111
    sound_write_slow                                ; Channel 1
    lda     #%10011111
    sound_write_slow                                ; Channel 0
ENDMACRO

    ; Set up audio
    
    ; System VIA port A to all outputs
    lda     #%11111111
    sta     SYSVIA_DDRA

	sei

    RESET_SOUND_CHIP

    ; Period to 1 on all tone channel 0
    lda     #%10000001
    sound_write_slow                                
    lda     #%00000000
    sound_write_slow                                
    
    ; System VIA Port B, place accumulator on wires, no handshake
    lda     #%00000000         
    sta     SYSVIA_REGB

	lda #lo(music_data)
	sta ptr+0
	lda #hi(music_data)
	sta ptr+1

.mainloop
	ldy #0
	lda (ptr), y
	beq exit
	cmp #&ff
	bne not_envelope
.envelope
	iny
	lda (ptr), y
	sta note_duration+0
	iny
	lda (ptr), y
	sta note_duration+1
	iny
	lda (ptr), y
	sta note_attack
	iny
	lda (ptr), y
	sta note_decay
	iny
	lda (ptr), y
	sta note_volume

	clc
	lda ptr+0
	adc #6
	sta ptr+0
	lda ptr+1
	adc #0
	sta ptr+1
	jmp mainloop

.not_envelope
	lda note_attack
	sta attack
	lda #1
	sta pulse_length
	sta attack_flag

	ldy #0
	lda (ptr), y
	sta n1
	iny
	lda (ptr), y
	sta n2
	iny
	lda (ptr), y
	sta n3

	lda note_duration+0
	sta duration+0
	lda note_duration+1
	sta duration+1

	lda #1
	sta etimer

	jsr play_note

	clc
	lda ptr+0
	adc #3
	sta ptr+0
	bcc mainloop
	inc ptr+1
	jmp mainloop

.exit
	cli
	jmp *

macro process_note var, offset
{
	dec var				; 5
	bne exit			; 2

    lda  #%10010000     ; 2 Channel 0: volume only
    sta  SYSVIA_ORAS    ; 4 Write to SN76489 Channel 0

	ldx pulse_length	; 3
.loop1
	dex					; 2
	bne loop1			; 2

    lda  #%10011111     ; 2 Channel 0: volume only
    sta  SYSVIA_ORAS    ; 4 Write to SN76489 Channel 0
    
	sec					; 2
	lda #MAX_PULSE_LEN	; 2
	sbc pulse_length	; 3
	tax					; 2
.loop2
	dex					; 2
	bne loop2			; 2

	ldy #offset			; 2
	lda (ptr), y		; 5
	sta var				; 3
.exit
}
endmacro

.play_note
{
	process_note n1, 0
	process_note n2, 1
	process_note n3, 2

	dec etimer
	bne not_etimer
		lda #TICKS_PER_VOL_STEP
		sta etimer
		lda attack_flag
		bne attack_flag_is_set
			dec decay			; 5
			bne not_etimer		; 2

			lda note_decay		; 3
			sta decay			; 3

			ldx pulse_length	; 3
			dex					; 2
			cpx note_volume		; 3
			beq not_etimer		; 2

			stx pulse_length
			bne not_etimer      ; pulse_length is never 0
		.attack_flag_is_set
			dec attack			; 5
			bne not_etimer		; 2

			lda note_attack		; 3
			sta attack			; 3

			ldx pulse_length	; 3
			inx					; 2
			stx pulse_length
			cpx #MAX_PULSE_LEN-1
			bne not_etimer

			dec attack_flag
			dec pulse_length

.not_etimer
	sec
	lda duration+0
	sbc #1
	sta duration+0
	lda duration+1
	sbc #0
	sta duration+1
	ora duration+0
	beq exit
	jmp play_note
.exit
	rts
}

macro envelope len, attack, decay, volume
	equb &ff
	equw len * 3/2
	equb attack+1, decay+1, volume
endmacro

macro note a, b, c
	equb a/2
	equb b/2
	equb c/2
endmacro

.music_data
	envelope 2400, 1, 0, 10
	note &41, &52, &6d
	note &3d, &52, &6d
	note &41, &52, &6d
	note &49, &52, &6d
	envelope 38400, 0, -107, 1
	note &57, &62, &83
	envelope 38400, -7, -1, 15
	note &57, &62, &83
	envelope 2400, 3, 0, 10
	note &53, &5d, &7c
	note &46, &5d, &7c
	note &3e, &5d, &7c
	note &46, &5d, &7c
	note &5d, &5d, &7c
	note &63, &5d, &7c
	note &5d, &53, &7c
	note &63, &53, &7c
	note &6e, &53, &7c
	note &7c, &53, &7c
	note &8c, &53, &7c
	note &7c, &53, &7c
	note &6f, &53, &7c
	note &53, &53, &7c
	envelope 2400, 3, 0, 10
	note &64, &85, &c8
	note &59, &85, &c8
	note &54, &85, &c8
	note &42, &84, &c7
	note &54, &85, &c8
	note &59, &85, &c8
	note &64, &85, &c8
	note &70, &86, &c8
	note &4b, &96, &e1
	note &54, &96, &e1
	note &5f, &96, &e1
	note &64, &96, &e1
	note &71, &96, &e1
	note &7f, &97, &e1
	note &71, &96, &e1
	note &64, &96, &e1
	note &4e, &9d, &eb
	note &58, &9d, &eb
	note &4e, &9d, &eb
	note &42, &9c, &ea
	note &46, &9c, &eb
	note &58, &9c, &eb
	note &4e, &9d, &eb
	note &58, &9d, &eb
	note &4e, &9d, &eb
	note &63, &9d, &eb
	note &69, &9d, &eb
	note &84, &9d, &eb
	note &76, &9d, &eb
	note &76, &9d, &eb
	note &76, &9d, &eb
	note &76, &9d, &eb
	note &58, &63, &c7
	note &58, &53, &c6
	note &57, &41, &c5
	note &57, &37, &c3
	note &58, &63, &c7
	note &58, &53, &c6
	note &57, &41, &c5
	note &57, &37, &c3
	note &53, &63, &c7
	note &53, &53, &c6
	note &53, &41, &c5
	note &53, &37, &c3
	note &53, &63, &c7
	note &53, &53, &c6
	note &53, &41, &c5
	note &53, &37, &c3
	note &63, &63, &df
	note &63, &5e, &df
	note &63, &4a, &df
	note &63, &3e, &df
	note &63, &63, &df
	note &63, &5e, &df
	note &63, &4a, &df
	note &63, &3e, &df
	note &5d, &63, &df
	note &5d, &5e, &df
	note &5d, &4a, &df
	note &5d, &3e, &df
	note &5d, &63, &df
	note &5d, &5e, &df
	note &5d, &4a, &df
	note &5d, &3e, &df
	note &6f, &63, &c7
	note &6f, &53, &c6
	note &6f, &41, &c5
	note &6f, &37, &c3
	note &84, &63, &c7
	note &84, &53, &c6
	note &84, &41, &c5
	note &84, &37, &c3
	note &7d, &63, &df
	note &7d, &5e, &df
	note &7d, &4a, &df
	note &7d, &3e, &df
	note &94, &63, &df
	note &94, &5e, &df
	note &94, &4a, &df
	note &94, &3e, &df
	note &84, &63, &c7
	note &84, &53, &c6
	note &84, &41, &c5
	note &84, &37, &c3
	note &6f, &63, &c7
	note &6f, &53, &c6
	note &6f, &41, &c5
	note &6f, &37, &c3
	note &63, &63, &c7
	note &63, &53, &c6
	note &63, &41, &c5
	note &63, &37, &c3
	note &63, &63, &c7
	note &63, &53, &c6
	note &63, &41, &c5
	note &63, &37, &c3
	note &63, &63, &c7
	note &5e, &53, &c6
	note &63, &41, &c5
	note &5e, &37, &c3
	note &63, &63, &c7
	note &5e, &53, &c6
	note &63, &41, &c5
	note &5e, &37, &c3
	note &5d, &5d, &d2
	note &75, &58, &d2
	note &5c, &45, &cf
	note &58, &3a, &d0
	note &5d, &5d, &d2
	note &75, &58, &d2
	note &5c, &45, &cf
	note &58, &3a, &d0
	note &5d, &5d, &d2
	note &75, &58, &d2
	note &5c, &45, &cf
	note &58, &3a, &d0
	note &5c, &5c, &8b
	note &75, &58, &8b
	note &5c, &45, &8b
	note &58, &3a, &8b
	note &63, &63, &de
	note &63, &5e, &de
	note &63, &4a, &dd
	note &62, &3e, &dc
	note &63, &63, &de
	note &63, &5e, &de
	note &63, &4a, &6f
	note &62, &3e, &dc
	note &63, &63, &94
	note &63, &5e, &f8
	note &63, &4a, &94
	note &62, &3e, &f8
	note &63, &63, &f8
	note &63, &5e, &f8
	note &63, &4a, &f8
	note &62, &3e, &f8
	envelope 2400, 0, 0, 13
	note &63, &63, &f8
	note &63, &5e, &f8
	note &63, &4a, &f8
	note &62, &3e, &f8
	note &63, &63, &f8
	note &63, &5e, &f8
	note &63, &4a, &f8
	note &62, &3e, &f8
	note &6f, &63, &f8
	note &6f, &5e, &f8
	note &6f, &4a, &f8
	note &6f, &3e, &f8
	note &6f, &63, &f8
	note &6f, &5e, &f8
	note &6f, &4a, &f8
	note &6f, &3e, &f8
	envelope 4800, 0, 0, 13
	note &4a, &59, &de
	note &53, &63, &dc
	note &59, &6f, &de
	note &53, &63, &dc
	note &63, &7c, &f9
	note &58, &6f, &f9
	note &4a, &58, &f9
	note &58, &6f, &f9
	envelope 2400, 0, 0, 13
	note &57, &68, &83
	note &68, &68, &83
	note &83, &68, &83
	note &62, &68, &83
	note &68, &68, &83
	note &83, &68, &83
	note &62, &6f, &94
	note &6f, &6f, &94
	note &94, &6f, &94
	note &58, &6f, &94
	note &6f, &6f, &94
	note &94, &6f, &94
	note &57, &68, &83
	note &68, &68, &83
	note &83, &68, &83
	note &62, &68, &83
	note &68, &68, &83
	note &83, &68, &83
	note &62, &6f, &94
	note &6f, &6f, &94
	note &94, &6f, &94
	note &76, &6f, &94
	note &6f, &6f, &94
	note &94, &6f, &94
	envelope 2400, 0, 29, 1
	note &6f, &94, &de
	note &6f, &94, &de
	note &6f, &94, &de
	note &6f, &94, &de
	note &7d, &a6, &de
	note &6f, &94, &de
	note &7d, &a6, &de
	note &6f, &94, &de
	note &5d, &8c, &de
	note &6f, &8c, &de
	note &6f, &8c, &de
	note &6f, &8c, &de
	note &7d, &8c, &de
	note &6f, &8c, &de
	note &5d, &8c, &de
	note &6f, &8c, &de
	note &53, &7c, &de
	note &63, &7c, &de
	note &7c, &7c, &de
	note &95, &7c, &de
	note &7c, &7c, &de
	note &63, &7c, &de
	note &53, &7c, &de
	note &5d, &7c, &de
	note &63, &7c, &de
	note &7c, &7c, &de
	note &6f, &6f, &de
	note &6f, &6f, &de
	note &6f, &6f, &de
	note &6f, &6f, &de
	note &6f, &6f, &de
	note &6f, &6f, &de
	note &6f, &6f, &de
	note &6f, &6f, &de
	note &6f, &6f, &de
	envelope 4800, 0, -1, 0
	note &e0, &e1, &e2
	note &e0, &e1, &e2
	envelope 2400, 0, -1, 40
	note &5d, &7c, &93
	note &e0, &e1, &e2
	note &e0, &e1, &e2
	note &5d, &7c, &93
	note &e0, &e1, &e2
	note &e0, &e1, &e2
	note &5d, &7c, &93
	note &e0, &e1, &e2
	envelope 9600, 0, -1, 30
	note &62, &7c, &a5
	envelope 2400, 0, -1, 2
	note &3d, &7a, &b8
	note &45, &6e, &b8
	note &49, &7a, &b8
	note &36, &6d, &a3
	note &3d, &61, &a3
	note &41, &6d, &a3
	note &3d, &7a, &b8
	note &45, &6e, &b8
	note &49, &7a, &b8
	note &36, &6d, &a3
	note &3d, &61, &a3
	note &41, &6d, &a3
	envelope 4800, 0, -1, 40
	note &e0, &e1, &e2
	note &e0, &e1, &e2
	envelope 2400, 0, -1, 30
	note &5d, &7c, &93
	note &e0, &e1, &e2
	note &e0, &e1, &e2
	note &5d, &7c, &93
	note &e0, &e1, &e2
	note &e0, &e1, &e2
	note &5d, &7c, &93
	note &e0, &e1, &e2
	envelope 9600, 0, -1, 30
	note &52, &6d, &82
	envelope 2400, 0, -1, 2
	note &3d, &7a, &b8
	note &45, &6e, &b8
	note &49, &7a, &b8
	note &36, &6d, &a3
	note &3d, &61, &a3
	note &41, &6d, &a3
	note &45, &8a, &cf
	note &4e, &7c, &cf
	note &53, &8b, &d0
	note &3d, &7a, &b8
	note &45, &6e, &b8
	note &49, &7a, &b8
	note &4e, &9c, &ea
	note &58, &8c, &ea
	note &5e, &9d, &eb
	note &45, &8a, &cf
	note &4e, &7c, &cf
	note &53, &8b, &d0
	note &3d, &7a, &b8
	note &45, &6e, &b8
	note &49, &7a, &b8
	note &36, &6d, &a3
	note &3d, &61, &a3
	note &41, &6d, &a3
	note &30, &60, &90
	note &36, &56, &90
	note &39, &60, &90
	note &36, &56, &90
	note &30, &60, &90
	note &36, &56, &90
	note &39, &60, &90
	note &36, &56, &90
	note &30, &60, &90
	note &36, &56, &90
	note &39, &60, &90
	note &36, &56, &90
	note &30, &60, &90
	note &36, &56, &90
	note &39, &60, &90
	note &36, &56, &90
	envelope 38400, -1, -129, 1
	note &39, &60, &90
	equb 0
.end

SAVE "play", start, end