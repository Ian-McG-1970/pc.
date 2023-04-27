; nasm cga_line_v7.asm -o cgaline.com -f bin


; list of next line tables - even values = +8192 odd values = -8192 - put into 2 registers - swap registers after each next line

VIDEO_SEGMENT	equ	0b800h 	; display memory segment for true CGA graphics modes
SW				equ 80 		; screen width
SE				equ	0		; screen even start
SO				equ	8192	; screen odd start

INPUT_STATUS_1	equ	03dah	; VGA status register
VSYNC_MASK	equ	08h	; vertical sync bit in status register 1
DE_MASK		equ	01h	; display enable bit in status register 1

MAP_MASK	equ	2		; SC map mask register
SC_INDEX		equ	3c4h	; SC index register
 
KEY_1	EQU	0231h
KEY_2	EQU	0332h
KEY_3	EQU	0433h
KEY_4 	EQU	0534h
KEY_5 	EQU	0635h
KEY_6 	EQU	0736h
KEY_ESC	EQU 27

ODD_INC 	EQU 8192; -80; +80
EVEN_INC 	EQU -8192+80; +80; +80 ;-80

CPU 8086
bits 16
org 100h

section .text

start:
	CLI			; disable interrupts
	call	BuildScreenTable
	mov	ax,04h 	; CGA 320 x 200 4 colors
	int		10h

;	mov	ax,0Bh 	; Pallette
;	mov	bh,1
;	mov	bl,0
;	mov	bx,00000h ; pallette 0 high
;	int	10h 

	mov		bx,1000h
	call	AllocMem
	mov		[BackBufferSeg],ax
	
;	mov	ah, 4ah
;	mov	bx, 1000h
;	int	21h
;	mov	ah, 48h
;	mov	bx, 1000h
;	int	21h
;	mov	[BackBufferSeg], ax

	xor ax,ax
	mov	[Exit],al
		
MainLoop:
		call	WaitVSync ; Wait for vertical sync so the new start address has a chance to take effect.
		call	CopyClearBackBuffer ; copy back to front
	
		mov		bx,[BackBufferSeg]
		mov		es,bx

		mov		bl,0
		mov		ax,[XPos]
		call	Hex16
		mov		bl,1
		mov		ax,[YPos]
		call	Hex16
;		mov		bl,2
;		mov		ax,[ZOffset]
;		call	Hex16

;		mov		bl,4
;		mov		ax,[XAngle]
;		call	Hex16
;		mov		bl,5
;		mov		ax,[YAngle]
;		call	Hex16
;		mov		bl,6
;		mov		ax,[ZAngle]
;		call	Hex16

;		mov		bl,9
;		mov		ax,[Test0]
;		call	Hex16
;		mov		bl,10
;		mov		ax,[Test1]
;		call	Hex16
;		mov		bl,11
;		mov		ax,[Test2]
;		call	Hex16
;		mov		bl,12
;		mov		ax,[Test3]
;		call	Hex16
;		mov		bl,13
;		mov		ax,[Test4]
;		call	Hex16
;		mov		bl,14
;		mov		ax,[Test5]
;		call	Hex16
;		mov		bl,15
;		mov		ax,[Test6]
;		call	Hex16
;		mov		bl,16
;		mov		ax,[Test7]
;		call	Hex16
;		mov		bl,17
;		mov		ax,[Test8]
;		call	Hex16
;		mov		bl,18
;		mov		ax,[Test9]
;		call	Hex16

		mov		si,[XPos]	; ver pixel pos
		mov		di,[YPos]	; hor pixel pos
		mov		bx,5		; words copied
		mov		dl,9		; lines copied /2
		call	SpriteV4

		
		call	GetKey
		
	mov		al,[Exit]
	or		al,al
	je		MainLoop

Done:	mov		ax,3	; reset to text mode
		int		10h
		mov		ah,4ch	; exit to DOS
		int		21h

AllocMem:	mov		ah,4ah
			push	bx
			int		21h
			mov		ah,48h
			pop		bx
			int		21h
			ret

BuildScreenTable:	lea		di,[BackBufferTable]
					xor		bp,bp	; even lines

					lea		si,[BackBufferTableInc]
					mov 	bx,ODD_INC
					mov		dx,EVEN_INC

					mov		cx,100
.loop:					mov		[di],bp
						add		bp,bx	; ODD_INC
						mov		[di+2],bp
						sub		bp,8192-80

						mov		[ds:si],bx
						mov 	[ds:si+2],dx
						add		si,4

						add		di,4
						loop	.loop
					ret

; si=v pos
; di=h pos
; bx=h size in words
; dl=v size /2

; copy permanent background to temp background - ds = perm background + es = temp background
; copy temp background to screen - ds = temp background + es = screen

SpriteV4:
;			mov		cl,2
;			shr		di,cl

			shr		di,1
			shr		di,1
			dec		di

			add		si,si
			mov		ax,[BackBufferTableInc+si]		; either -8192 or 8192
			mov		bp,[BackBufferTableInc+2+si]	; either 8192 or -8192
			add		di,[BackBufferTable+si]			; di=di (screen hor char pos) + screen ver pos

			mov		cx,bx
			add		cx,cx

			sub		ax,cx
			sub		bp,cx

.loop			mov		si,di
				mov		cx,bx
				rep		movsw
				add		di,ax

				mov		si,di
				mov		cx,bx
				rep		movsw
				add		di,bp

				dec		dl							; ver count
				jne		.loop
			ret

; draw sprite on temp background - ds = sprite + es = temp background

GetKey:
	mov	ah,11h
	int	16h         	; has a key been pressed
	jz	.key_none ; no
	mov	ah,10h      ; yes 
	int	16h         	; get it in AX (al= ascii, ah=scan code)
	cmp	al,KEY_ESC
	je	.key_esc
	cmp 	ax,KEY_1
	je 	.key_1
	cmp 	ax,KEY_2
	je 	.key_2
	cmp 	ax,KEY_3
	je 	.key_3
	cmp 	ax,KEY_4
	je 	.key_4
	cmp 	ax,KEY_5
	je 	.key_5
	cmp 	ax,KEY_6
	je 	.key_6
.key_none:
	ret
.key_esc:
	mov	al,1
	mov	[Exit],al
	ret
.key_1:
	mov ax,[XPos]
	dec ax
	mov [XPos],ax
	ret
.key_2:
	mov ax,[XPos]
	inc ax
	mov [XPos],ax
	ret
.key_3:
	mov ax,[YPos]
	dec ax
	mov [YPos],ax
	ret
.key_4:
	mov ax,[YPos]
	inc ax
	mov [YPos],ax
	ret
.key_5:
;	mov ax,[ZOffset]
	sub ax,37
;	mov [ZOffset],ax
	ret
.key_6:
;	mov ax,[ZOffset]
	add ax,37
;	mov [ZOffset],ax
	ret

WaitVSync: 			mov		dx,INPUT_STATUS_1	; Wait for the leading edge of vertical sync pulse.
WaitNotVSyncLoop:		in		al,dx
						and		al,VSYNC_MASK
						jnz		WaitNotVSyncLoop
WaitVSyncLoop:			in		al,dx
						and		al,VSYNC_MASK
						jz		WaitVSyncLoop
					ret
		
CopyClearBackBuffer:
	cld

	mov		bp,ds			; backup ds

	mov		dx,[BackBufferSeg]
	mov		ds,dx

	mov		ax,VIDEO_SEGMENT
	mov		es,ax

	xor		si,si		; DS:SI points to even back buffer
	mov		di,si		; ES:DI points to CGA memory.

	mov		cx,4000
	rep	movsw			; copy from ds:si to es:di

	mov		si,8192		; DS:SI points to odd back buffer
	mov		di,si		; ES:DI points to CGA memory.

	mov		cx,4000
	rep	movsw			; copy from ds:si to es:di

	mov		ax,ds		; es points to ds
	mov		es,ax

	mov		ax,00101101001011010b ;
	
	xor		di,di		; DS:SI points to even back buffer	
	mov		cx,4000
	rep	stosw			; clear odd back buffer

	mov		di,8192		; DS:SI points to odd back buffer	
	mov		cx,4000
	rep	stosw			; clear odd back buffer

	mov		ds,bp			; restore ds

	ret

HexChar:	mov		si,di
			mov		bl,al
			shr		bl,1
			shr		bl,1
			shr		bl,1
			shr		bl,1
			and		bx,15
			mov		ah,[Hex0+bx]
			mov		[es:di],ah
			add		di,8192
			mov		ah,[Hex1+bx]
			mov		[es:di],ah
			sub		di,8192-80
			mov		ah,[Hex2+bx]
			mov		[es:di],ah
			add		di,8192
			mov		ah,[Hex3+bx]
			mov		[es:di],ah
			sub		di,8192-80
			mov		ah,[Hex4+bx]
			mov		[es:di],ah

			mov		di,si
			inc		di

			mov		bl,al
			and		bl,15
			mov		al,[Hex0+bx]
			mov		[es:di],al
			add		di,8192
			mov		al,[Hex1+bx]
			mov		[es:di],al
			sub		di,8192-80
			mov		al,[Hex2+bx]
			mov		[es:di],al
			add		di,8192
			mov		al,[Hex3+bx]
			mov		[es:di],al
			sub		di,8192-80
			mov		al,[Hex4+bx]
			mov		[es:di],al
			ret

Hex24:		push	ax
			push	bx

			mov		al,bh
			call	Hex8
						
			pop		bx
			pop		ax

			push	ax
			push	bx

			mov		di,2
			call	HexByte

			pop		bx
			pop		ax

			mov		al,ah
			mov		di,4
			jmp		HexByte	; does ret

Hex16:		push	ax
			push	bx

			mov		al,ah
			call	Hex8
						
			pop		bx
			pop		ax

			mov		di,2
			jmp		HexByte ; does ret

Hex8:		xor		di,di
HexByte:	xor		bh,bh
			mov		ah,bl
			add		ah,ah	; *2
			add		bl,ah	; *3
			add		bx,bx	; *6
			add		bx,bx	; *12
			add		di,[BackBufferTable+bx]	; lookup start ver
			jmp		HexChar	 ; does ret
;			ret
	
section .data align=8 ; 16 ; 8 ; 16

XPos:	dw		100
YPos:	dw		100
ZPos:	dw		100

Hex0	db 11111100b,00110000b,11111100b,11111100b,11001100b,11111100b,11111100b,11111100b,11111100b,11111100b,11111100b,11111100b,11111100b,11110000b,11111100b,11111100b
Hex1	db 11001100b,11110000b,00001100b,00001100b,11001100b,11000000b,11000000b,00001100b,11001100b,11001100b,11001100b,11001100b,11000000b,11001100b,11000000b,11000000b
Hex2	db 11001100b,00110000b,11111100b,11111100b,11111100b,11111100b,11111100b,00001100b,11111100b,11111100b,11111100b,11110000b,11000000b,11001100b,11111100b,11111100b
Hex3	db 11001100b,00110000b,11000000b,00001100b,00001100b,00001100b,11001100b,00001100b,11001100b,00001100b,11001100b,11001100b,11000000b,11001100b,11000000b,11000000b
Hex4	db 11111100b,11111100b,11111100b,11111100b,00001100b,11111100b,11111100b,00001100b,11111100b,11111100b,11001100b,11111100b,11111100b,11110000b,11111100b,11000000b

section .bss 	; put uninitialized data here
BackBufferTable: 	resw 202 	; 200 screen lines as words
BackBufferTableInc:	resw 202	; 200 screen line next line increments
BackBuffer: 		resw 16384	; 2 screen buffers

Test0: 	resw	1
Test1: 	resw	1
Test2: 	resw	1
Test3: 	resw	1
Test4: 	resw	1
Test5: 	resw	1
Test6: 	resw	1
Test7: 	resw	1
Test8: 	resw	1
Test9: 	resw	1

BackBufferSeg	resw	1	; pointer to the segment containing the back buffer

Exit:	resb	1

; .ver
; .hor
;   mov ax,[ds,si]

;   lda dl,[es,di]
;   and dl,al
;   or dl.ah
;   sta [es,di],dl

;   inc di
;   loop .hor
;  add stride,di
;  loop .ver


; .ver
; .hor

;   lda dx,[es,di]

;   mov ax,[ds,si]
;   and dl,al
;   or dl.ah
;   mov ax,[ds,si]
;   and dh,al
;   or dh.ah

;   sta [es,di]

;   inc di
;   loop .hor
;  add stride,di
;  loop .ver
