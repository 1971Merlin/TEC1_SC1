; ----------------------------------------------------------------------------
;
;	Test code for RAM Memory map
;
;	Assemble with TASM using the command line options -80 -g0
;
;	Copyright (C) 2022, Craig Hart. Distributed under the GPLv3 license
;
;	https://github.com/1971Merlin/
;
; ----------------------------------------------------------------------------



; ----------------------------------------------------------------------------
; conditional defines - set the target machine platform
; comment or un-commnt the following two lines to compile for target machine
; ----------------------------------------------------------------------------

;#define SC1
#define TEC1



#ifdef SC1
	.org 2000h

startad	.equ 2000h
adinc	.equ 0100h	; 256b blocks

; SC-1 7-seg ports
disscan .equ	85h
disseg	.equ	84h

; keyboard port
keyport	.equ	86h
#endif



#ifdef TEC1
	.org 2000h

startad	.equ 2000h
adinc	.equ 0400h	; 1k blocks

; tec-1 7-seg ports
disscan	.equ	01h
disseg	.equ	02h

; keyboard port
keyport	.equ	00h


#endif

; ----------------------------------------------------------------------------
; main program section
; ----------------------------------------------------------------------------

main:
	ld hl,startad
	ld bc,adinc

	xor a			; reset display mode
	ld (mode),a

	di			; disable interrupts; avoid memory corruption

testloop:

	ld e,(hl)		; backup original value

	ld a,0aah		; test 1 store aa
	ld (hl),a
	nop
	ld d,(hl)
	cp d
	jr nz, noram

	ld a,055h		; test 2 store 55
	ld (hl),a
	nop
	ld d,(hl)
	cp d
	jr nz, noram

	ld a,00h		; test 3 store 00
	ld (hl),a
	nop
	ld d,(hl)
	cp d
	jr nz, noram

	ld a,0ffh		; test 4 store ff
	ld (hl),a
	nop
	ld d,(hl)
	cp d
	jr nz, noram

	ld (hl),e		; restore value

	add hl,bc
	jr testloop


noram:	ld (hl),e		; restore value (even if failed teset!)

	ei			; end test enable interrupts

	or a			; clear carry flag
	ld de,startad
	sbc hl,de		; subtract start offset to get size in bytes


; uncomment out next 4 lines for value in kilobytes
;	srl h			; convert bytes to kb
;	srl h
;	ld l,h
;	ld h,0


	ld (result),hl



; display results forever


disp:
	ld a,(mode)

kb:	bit 7,a
	jr nz, st

	ld hl,(result)
	call clrbuff
	call disphl		; convert HL binary to decimal digits
	jp ml


st:	ld hl,startad
	call clrbuff
	ld de,disp_buff		; where to put the decimal digits

	ld a,h			; store (HL) as BCD - Hex display
	srl a
	srl a
	srl a
	srl a
	ld (de),a
	inc de
	ld a,h
	and 0fh
	ld (de),a
	inc de


	ld a,l
	srl a
	srl a
	srl a
	srl a
	ld (de),a
	inc de
	ld a,l
	and 0fh
	ld (de),a
	inc de

	ld a,0feh		; "h"
	ld (de),a

ml:	call scan_7seg		; display on screen

	call pollkey		; sample keyboard state
	call handlekey		; process a keystroke, if any

	jp disp


; ----------------------------------------------------------------------------
; fill display buffer with blanks
; ----------------------------------------------------------------------------

clrbuff:
	push hl
	push bc
	push de

	ld hl,disp_buff
	ld de,disp_buff
	inc de
	ld (hl),0ffh		; value to store
	ld bc,0005		; n-1 bytes to fill
	ldir			; (hl)->(de) BC times inc hl, de

	pop de
	pop bc
	pop hl
	ret


; ----------------------------------------------------------------------------
; Convert HL from binery to decimal digits stored at (DE)
; In: HL = value, DE = memory location to store (up to 5 digits, 65535)
; ----------------------------------------------------------------------------

disphl:
	ld de,disp_buff		; where to put the decimal digits
	xor a			; reset leading zero trimmer
	ld (flag),a
				; convert binary to decimal
	ld	bc,-10000
	call	Num1
	ld	bc,-1000
	call	Num1
	ld	bc,-100
	call	Num1
	ld	c,-10
	call	Num1
	ld	c,-1
Num1:	ld	a,0ffh	; '0'-1
Num2:	inc	a
	add	hl,bc
	jr	c,Num2
	sbc	hl,bc
	call putchar		; store a digit
	ret


putchar:
	push bc
	ld b,a
	cp 00h
	jr nz,noxx		; not a zero, write it

	ld a,(flag)		; a zero, but have we displayed anything yet?
	bit 7,a
	jr z, skp		; no, so exit dont display anything

noxx:	ld a,80h		; flag 1 = we have written something now
	ld (flag),a

	ld a,b
	ld (de),a
	inc de

skp:	pop bc
	ret


; ----------------------------------------------------------------------------
; Utility routine to scan the internal 7-seg displays
; Borrowed from Craig Jones SC-1 monitor
; ----------------------------------------------------------------------------

scan_7seg:
	push af
	push bc
	push hl

outerloop:
	ld c,020h
	ld hl,disp_buff

scanloop:
	ld a,(hl)	; output value
	call conv7seg
	out (disseg),a
	ld a,c		; turn on display
	out (disscan),a
	ld b,0c0h
on:	djnz on

	ld a,00h	; turn off display
	out (disscan),a
	ld b,20h
off:	djnz off

	inc hl
	rrc c
	jr nc,scanloop

	ld a,00h	; turn off displays
	out (disseg),a
	out (disscan),a

	pop hl
	pop bc
	pop af
	ret

; converts a decimal value in register A to a 7-seg value of that digit
; returns A with which segs to light up

conv7seg:
	push bc		; this is really a lookup table fetch that allows
	push hl		; for memory wrapping of the lower byte

	cp 0ffh		; blank? don't light up blanks
	jr nz, cont
	ld a,00h
	jr ex

cont:	cp 0feh
	jr nz, cont2

#ifdef SC1
	ld a,074h	; "h" char
#endif

#ifdef TEC1
	ld a,076h	; "h" char
#endif

	jr ex


cont2:	ld hl, segs	; list of 0-9 digits which segs to light for each
	and 0fh		; ensure a is in a valid range
	ld c,a		; put into lwr half of bc
	ld b,00h	; upper half is 0
	add hl,bc	; 16-bit add
	ld a,(hl)	; fetch value from memory

ex:	pop hl
	pop bc
	ret


; ----------------------------------------------------------------------------
; handle key; check buffer for a keystroke and do something if found
; ----------------------------------------------------------------------------

handlekey:
	push af

	ld a,(keyval)	; bit 7=1 = valid keypress in buffer
	bit 5,a
	jr z, nohndl	; nope, no key in buffer

	res 5,a		; clear keypress valid bit - we used our keypress
	ld (keyval),a

; at this poin A contains a value 0-F representing the pressed key

	ld a,(mode)	; pressing a key
	xor 80h
	ld (mode),a


nohndl:	pop af
	ret


; ----------------------------------------------------------------------------
; poll keyboard; update buffer if a keypress detected
; ----------------------------------------------------------------------------

pollkey:
	push af
	push bc
	in a,(keyport)

; SC-1 keyboard routine. Ensures only one keypress at a time and loop doesn't pause

#ifdef SC1
	bit 5,a		; bit 5=1 = key pressed on SC-1
	jr nz, key
#endif


#ifdef TEC1
	res 5,a
	bit 6,a		; bit 6=0 = key pressed on TEC1 (Requires jmon resistor mod)
	jr nz,nokey
	set 5,a
	jr key
#endif

nokey:
	ld (keyflag),a
	jr bail


key:	and 3fh		; mask off top bits
	ld b,a		; backup value
	ld a,(keyflag)	; did we already see it pressed?
	bit 5,a
	jr nz, bail

	ld a,b		; restore value and save; set flag
	ld (keyflag),a
	ld (keyval),a

bail:
	pop bc
	pop af
	ret

; ----------------------------------------------------------------------------
;	data, variables, etc.
; ----------------------------------------------------------------------------


disp_buff:
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh

flag:	.db 00h
mode:	.db 00h
result	.dw 00h
keyflag	.db 00h
keyval	.db 00h



#ifdef SC1
segs:
	.db 3fh
	.db 06h
	.db 5bh
	.db 4fh
	.db 66h
	.db 6dh
	.db 7dh
	.db 07h
	.db 7fh
	.db 6fh
	.db 77h
	.db 7ch
	.db 39h
	.db 5eh
	.db 79h
	.db 71h

#endif

#ifdef TEC1
segs:
	.db 0ebh
	.db 028h
	.db 0cdh
	.db 0adh
	.db 02eh
	.db 0a7h
	.db 0e7h
	.db 029h
	.db 0efh
	.db 02fh
	.db 06fh
	.db 0e6h
	.db 0c3h
	.db 0ech
	.db 0c7h
	.db 047h

#endif


; ----------------------------------------------------------------------------
; end of our code and data, end of program. goodbye!
; ----------------------------------------------------------------------------

	.end
