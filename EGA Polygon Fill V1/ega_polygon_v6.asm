; nasm vga3d_v16.asm -o vga3d.com -f bin

VIDEO_SEGMENT	equ	0A000h 	; display memory segment for true CGA graphics modes

VIDEO_SEGMENT_PAGE_0 equ VIDEO_SEGMENT
VIDEO_SEGMENT_PAGE_1 equ VIDEO_SEGMENT_PAGE_0 + (SCREEN_SIZE/16)

LINE_SIZE_IN_BYTES equ 40
SCREEN_WIDTH_320 equ LINE_SIZE_IN_BYTES ; LINE_SIZE_IN_BYTES/4

SCREEN_SIZE_IN_BYTES equ 320*200
SCREEN_SIZE equ SCREEN_SIZE_IN_BYTES/8
SCREEN_SIZE_DWORDS equ SCREEN_SIZE/4

INPUT_STATUS_1	equ	03dah	; VGA status register
VSYNC_MASK	equ	08h	; vertical sync bit in status register 1
DE_MASK		equ	01h	; display enable bit in status register 1

HIGH_ADDRESS equ 0Ch
LOW_ADDRESS  equ 0Dh

MAP_MASK	equ	2		; SC map mask register
SC_INDEX		equ	3c4h	; SC index register
CRTC_INDEX equ 03d4h

KEY_1	EQU	0231h
KEY_2	EQU	0332h
KEY_3	EQU	0433h
KEY_4 	EQU	0534h
KEY_5 	EQU	0635h
KEY_6 	EQU	0736h
KEY_ESC	EQU 	27

CPU 486
bits 16
org 100h

%macro middle 0
		mov		dx, 03CEh
		mov		ax, 0FF08h		; First bitmask is 11111111b
		out		dx, ax			; BitMask register
		mov 	eax,0ffffffffh			
%endmacro

%macro left_edge 0
	mov 	dx,03ceh
	mov 	al,8
	mov 	ah,[edgeleftcga+di]
	out 	dx,ax

	shr 	di,3
	add		di,si

	mov 	eax,0ffffffffh			
	stosb
%endmacro

%macro right_edge 0
	mov 	dx,03ceh
	mov 	al,8
	mov 	ah,[edgerightcga+bp]
	out 	dx,ax

	mov 	al,0ffh			
	mov		[es:di],al
%endmacro

%macro fill_cont	0
	pop		cx
	pop 	bp

	add		bp,8
	add		si,40
	dec		cl
	jnz		Fill.fillloop
%endmacro

section .text

start:	
		call	EGAMode320x200

	xor	ax,ax
	mov	[ScreenBuffer],ax
	mov	ax,VIDEO_SEGMENT
	mov	[ScreenBufferSeg],ax

	mov     dx,SC_INDEX
	mov 	ax,0ff02h
	out     dx,ax		

	mov bx,[ScreenBufferSeg]
	mov	es,bx

	cld

	mov	eax,022222222h
	xor	edi,edi
	mov	ecx,SCREEN_SIZE/4
	rep	stosd

	mov	eax,033333333h
	mov	edi,SCREEN_SIZE
	mov	ecx,SCREEN_SIZE/4
	rep	stosd
	
MainLoop:
		call	WaitVSync ; Wait for vertical sync so the new start address has a chance to take effect.
		 
		mov		bl,3
		mov		ax,0123h
		call	Hex16

		mov		bl,5
		mov		ax,4567h
		call	Hex16

		mov		bl,7
		mov		ax,089abh
		call	Hex16

		mov		bl,9
		mov		ax,0cdefh
		call	Hex16

		mov		bl,11
		mov		ax,[ScreenBuffer]
		call	Hex16

	mov	cx,3
	call	Move
	
	mov	cx,3
	call	Plots
	
	
	mov	al,55h ; 100
	mov	cx,3
	lea		si,[PointList2]
	call	Fill
		
	mov	al,33h ; 100
	mov	cx,3
	lea		si,[PointList]
	call	Fill

		call	GetKey
	jnc		MainLoop

Done: ; Finished, clear key, reset screen mode and exit.
	mov	ax,3		; reset to text mode
	int		10h
	
	mov	ah,4ch	; exit to DOS
	int		21h

; Wait for the leading edge of vertical sync pulse.
;
;WaitVSync	proc	near
;	mov	dx,INPUT_STATUS_1
;WaitNotVSyncLoop:
;	in	al,dx
;	and	al,VSYNC_MASK
;	jnz	WaitNotVSyncLoop
;WaitVSyncLoop:
;	in	al,dx
;	and	al,VSYNC_MASK
;	jz	WaitVSyncLoop
;	ret
;WaitVSync	endp

;/* Wait until we're not in vertical sync, so we can catch leading edge */
;      while ((inp(INPUT_STATUS_1) & 0x08) != 0) ;
;      /* Wait until we are in vertical sync */
;      while ((inp(INPUT_STATUS_1) & 0x08) == 0) ;

; When the offset registers are changed, the page flip does not occur until the end of the next vertical retrace.
; So after the page is flipped, the program should wait until the end of the vertical retrace before drawing to the non-visible page.

WaitVSync: ; Wait for the leading edge of vertical sync pulse.

				mov	dx,INPUT_STATUS_1
WaitNotVSyncLoop:		in		al,dx
					and	al,VSYNC_MASK 	; is bit 3 clear so its not in the vertical retrace?
					jnz		WaitNotVSyncLoop 	; no its set

;				mov	dx,INPUT_STATUS_1
WaitVSyncLoop:	in	al,dx
					and	al,VSYNC_MASK 	; is bit 3 set so its in the vertical retrace?;
					jz	WaitVSyncLoop 	; no its clear

				mov 	bx,[ScreenBuffer]
				test	bx,bx
				jnz		.page1

.page0:				mov		ax,VIDEO_SEGMENT_PAGE_1
					mov 	bx,SCREEN_SIZE
					jmp 	.cont2

.page1:				mov		ax,VIDEO_SEGMENT_PAGE_0
					xor		bx,bx

.cont2:			mov 	[ScreenBuffer],bx
				mov		[ScreenBufferSeg],ax

				mov dx, CRTC_INDEX
				mov al, LOW_ADDRESS
				mov ah,bl
				out dx,ax
				mov al, HIGH_ADDRESS
				mov ah,bh
				out dx,ax

				mov     dx, SC_INDEX
				mov 	ax, 0ff02h 
				out     dx, ax		

				mov	ax,[ScreenBufferSeg]
				mov	es,ax
				
				cld
				xor	eax,eax
				xor	edi,edi
				mov	ecx,SCREEN_SIZE/4
				rep	stosd

				ret

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
	clc
	ret
.key_esc:
	stc
	ret
.key_1:
	clc
	ret
.key_2:
	clc
	ret
.key_3:
	clc
	ret
.key_4:
	clc
	ret
.key_5:
	clc
	ret
.key_6:
	clc
	ret

SetColour:	mov   dx, 03C4h		; MapMask register
			mov   al, 02h		; 0F02h     ; ah = colour?
			out   dx, ax
			mov   dx, 03CEh		; BitMask register
			mov   ax, 0FF08h    ; First bitmask is 11111111b
			out   dx, ax
			ret

DrawLine:	mov		eax,0ffffffffh		; cx = count
			rep		stosd
			ret

SetLine:	mov	ah,40 ; screen width ; al = screen line
			mul	ah
			mov	di,ax
			ret

EGAMode320x200:

		mov    ax,12h
		int    10h          ; mode 12h to supposedly let the BIOS clear the video memory

        MOV AX, 000Dh       ; Set video mode 0Dh (EGA 320x200, 16 color)
        INT 10h

		ret
	

Move:	lea 	si,[PointList]
		lea	di,[DirList]
 
.loop		mov	ax,[si]
		mov	bx,[si+2]
		mov	dx,[di]
		mov	bp,[di+2]
		add	ax,dx
		add	bx,bp
		mov	[si],ax
		mov	[si+2],bx

		cmp 	ax,0
		jne 	.testxl
			neg 	dx
.testxl		cmp 	bx,0
		jne 	.testyl
			neg 	bp
.testyl		cmp 	ax,199
		jne 	.testxr
			neg 	dx
.testxr		cmp 	bx,319
		jne 	.testyr
			neg 	bp
.testyr		mov 	[di],dx
		mov	[di+2],bp
 
		add	si,4
		add	di,4
		dec	cx
		jne	.loop
	ret

Plot:	; bp=v / bx=h / ch=col

	mov dx,[ScreenBufferSeg]
	mov es,dx

	mov		cl,	bl	; backup
	shr		bx,	2	; /4
	add		bp,	bp 	; start ver *2
	add		bx,	[BackBufferTable320+bp]	; ver start
;	add		bx, [ScreenBuffer]

	mov		ah,	1 ; move ax,0102h
	and 	cl,	3
	shl		ah,	cl
	mov		al,	02h ; not needed if above implemented?
	mov     dx, SC_INDEX
	out     dx, ax		; 2. Put the CHAIN4-mode of Sequencer off
	
	mov		[es:bx],ch
	ret

Plots:	lea 	si,[PointList]
 
.loop	push	cx
		push si
		mov	bp,[si]
		mov	bx,[si+2]
		mov		ch,66h
;		call 	Plot

 	mov		ah,10
	call	SetColour
	mov		ax,bx
	call	SetLine
	mov		cx,1
;;	call	DrawLine

 	mov		ah,5
	call	SetColour
	mov		ax,bp
	call	SetLine
	mov		cx,1
;	call	DrawLine
 
 pop si
		pop		cx
 		add	si,4
		dec	cl
		jne	.loop
		

	mov		ah,10
;	call	SetColour
	mov		al,10
;	call	SetLine
	mov		cx,5
;	call	DrawLine

	mov		ah,12
;	call	SetColour
	mov		al,12
;	call	SetLine
	mov		cx,9
;	call	DrawLine

	mov		ah,12
;	call	SetColour
	mov		al,14
;	call	SetLine
	mov		cx,9
;	call	DrawLine

	mov		ah,10
;	call	SetColour
	mov		al,14
;	call	SetLine
	mov		cx,5
;	call	DrawLine

	ret

Fill:	mov		[Colour],al		; backup colour
	
;;		lea		si,[PointList]		; point list
		mov		bx,cx			; points
		shl		bx,2			; copy first point to last point
		mov		ebp,[si]			; get start xy words
		mov		[si+bx],ebp		; put xy words to end

		mov		bx,000ffh		; set lowest and highest

.point_loop		push	cx

				mov		ax,[si]		; vstart
				mov		bp,[si+2]	; hstart
				mov		cx,[si+4]	; vend
				mov		dx,[si+6]	; hend

				lea		di,[EdgeTable]	; get edge table start - default left edge
				cmp 	ax,cx 		; compare vstart vend
				jz 		.next 		; if same ignore
				jc		.noswap
					xchg 	ax,cx 		; swap vstart vend
					xchg 	bp,dx 		; swap hstart hend
					add		di,4		; add 4 for right edge

.noswap:		cmp 	bl,al 	; smallest xpos
				jc 	.low
					mov 	bl,al 	; yes

.low:			cmp 	bh,cl	; biggest xpos
				jnc 	.high
					mov		bh,cl 	; yes

.high			sub		cx,ax		; vdiff

				shl		ax,3		; *8
				add		di,ax		; added to di
	
				sub		dx,bp		; hdiff

.positive		shl		ebp,16		; hstart *65536

				movsx	eax,dx		; hdiff
				movsx	ecx,cx
				CDQ
				shl		eax,9		; shift left ax 9 times
				idiv	ecx			; divide dx:ax by cx
				shl		eax,7		; shift result left 7 times so becomes 16:16

.edge_loop		mov		[di],ebp		; store hstart = temp
				add		ebp,eax
				add		di,8
				dec		cl
				jnz		.edge_loop

.next			add		si,4
				pop		cx
				dec		cl
				jnz		.point_loop
 
			sub		bh,bl			; end - start
			jc		Fill_Exit		; all on same line?

			mov   	dx,03C4h		; MapMask register
			mov   	al,02h
			mov		ah,[Colour]
			out   	dx,ax

			mov		cl,bh
			xor		bh,bh
			add		bx,bx 			; start ver *2
			mov		si,[BackBufferTable320+bx]	; start of ver line
			shl		bx,2			; start ver *4*8
			lea		bp,[EdgeTable+bx+2]	; point to first 

.fillloop:		push 	bp
				push 	cx
 				mov		di,[bp+4]
				mov		bp,[bp]

				cmp		bp,di
				jnc		.no_swap
					xchg 	bp, di

.no_swap:		mov		ax,di
				mov		bx,bp

				shr		ax,3
				shr		bx,3
				sub		bx,ax
				add		bx,bx
				mov		ax,[FillJumpTable+bx]
;				mov		ebx,ecx		; backup count/colour
				JMP		(ax)

Fill000:	fill_cont
Fill_Exit:	ret

Fill008:	left_edge
			middle
			right_edge
			fill_cont
			ret

;Fill000: ; same 8 bits  
;Fill008: ; diff 8 bits

Fill016:	left_edge
			middle
			stosb
			right_edge
			fill_cont
			ret

Fill024:	left_edge
			middle
			stosw
			right_edge
			fill_cont
			ret

Fill032:	left_edge
			middle
			stosb
			stosw
			right_edge
			fill_cont
			ret

Fill040:	left_edge
			middle
			stosd
			right_edge
			fill_cont
			ret

;Fill016: ; left / stosb / right
;Fill024: ; left / stosw / right
;Fill032: ; left / stosb / stoww / right
;Fill040: ; left / stosd / right

Fill048:	left_edge
			middle
			stosb
			stosd
			right_edge
			fill_cont
			ret

Fill056:	left_edge
			middle
			stosw
			stosd
			right_edge
			fill_cont
			ret

Fill064:	left_edge
			middle
			stosb
			stosw
			stosd
			right_edge
			fill_cont
			ret

Fill072:	left_edge
			middle
			mov	cx,2
			rep	stosd
			right_edge
			fill_cont
			ret

;Fill048: ; left / stosb / stosd / right
;Fill056: ; left / stosw / stosd / right
;Fill064: ; left / stosb / stosw / stosd / right
;Fill072: ; left / stosd(2) / right

Fill080:	left_edge
			middle
			stosb
			mov	cx,2
			rep	stosd
			right_edge
			fill_cont
			ret

Fill088:
			left_edge
			middle
			stosw
			mov	cx,2
			rep	stosd
			right_edge
			fill_cont
			ret


Fill096:	left_edge
			middle
			stosb
			stosw
			mov	cx,2
			rep	stosd
			right_edge
			fill_cont
			ret

Fill104:	left_edge
			middle
			mov	cx,3
			rep	stosd
			right_edge
			fill_cont
			ret

;Fill080: ; left / stosb / stosd(2) / right
;Fill088: ; left / stosw / stosd(2) / right
;Fill096: ; left / stosb / stosw / stosd(2) / right
;Fill104: ; left / stosd(3) / right

Fill112:	left_edge
			middle
			stosb
			mov	cx,3
			rep	stosd
			right_edge
			fill_cont
			ret

Fill120:	left_edge
			middle
			stosw
			mov	cx,3
			rep	stosd
			right_edge
			fill_cont
			ret

Fill128:	left_edge
			middle
			stosb
			stosw
			mov	cx,3
			rep	stosd
			right_edge
			fill_cont
			ret

Fill136:	left_edge
			middle
			mov	cx,4
			rep	stosd
			right_edge
			fill_cont
			ret

;Fill112: ; left / stosb / stosd(3) right
;Fill120: ; left / stosw / stosd(3) right
;Fill128: ; left / stosb / stosw / stosd(3) / right
;Fill136: ; left / stosd(4) / right

Fill144:	left_edge
			middle
			stosb
			mov	cx,4
			rep	stosd
			right_edge
			fill_cont
			ret

Fill152:	left_edge
			middle
			stosw
			mov	cx,4
			rep	stosd
			right_edge
			fill_cont
			ret

Fill160:	left_edge
			middle
			stosb
			stosw
			mov	cx,4
			rep	stosd
			right_edge
			fill_cont
			ret

Fill168:	left_edge
			middle
			mov	cx,5
			rep	stosd
			right_edge
			fill_cont
			ret

;Fill144: ; left / stosb / stosd(4) right
;Fill152: ; left / stosw / stosd(4) right
;Fill160: ; left / stosb / stosw / stosd(4) / right
;Fill168: ; left / stosd(5) / right

Fill176:	left_edge
			middle
			stosb
			mov	cx,5
			rep	stosd
			right_edge
			fill_cont
			ret

Fill184:	left_edge
			middle
			stosw
			mov	cx,5
			rep	stosd
			right_edge
			fill_cont
			ret

Fill192:	left_edge
			middle
			stosb
			stosw
			mov	cx,5
			rep	stosd
			right_edge
			fill_cont
			ret

Fill200:	left_edge
			middle
			mov	cx,6
			rep	stosd
			right_edge
			fill_cont
			ret

;Fill176: ; left / stosb / stosd(5) right
;Fill184: ; left / stosw / stosd(5) right
;Fill192: ; left / stosb / stosw / stosd(5) / right
;Fill200: ; left / stosd(6) / right

Fill208:	left_edge
			middle
			stosb
			mov	cx,6
			rep	stosd
			right_edge
			fill_cont
			ret

Fill216:	left_edge
			middle
			stosw
			mov	cx,6
			rep	stosd
			right_edge
			fill_cont
			ret

Fill224:	left_edge
			middle
			stosb
			stosw
			mov	cx,6
			rep	stosd
			right_edge
			fill_cont
			ret

Fill232:	left_edge
			middle
			mov	cx,7
			rep	stosd
			right_edge
			fill_cont
			ret

;Fill208: ; left / stosb / stosd(6) right
;Fill216: ; left / stosw / stosd(6) right
;Fill224: ; left / stosb / stosw / stosd(6) / right
;Fill232: ; left / stosd(7) / right

Fill240:	left_edge
			middle
			stosb
			mov	cx,7
			rep	stosd
			right_edge
			fill_cont
			ret

Fill248:	left_edge
			middle
			stosw
			mov	cx,7
			rep	stosd
			right_edge
			fill_cont
			ret


Fill256:	left_edge
			middle
			stosb
			stosw
			mov	cx,7
			rep	stosd
			right_edge
			fill_cont
			ret

Fill264:	left_edge
			middle
			mov	cx,8
			rep	stosd
			right_edge
			fill_cont
			ret

;Fill240: ; left / stosb / stosd(7) right
;Fill248: ; left / stosw / stosd(7) right
;Fill256: ; left / stosb / stosw / stosd(7) / right
;Fill264: ; left / stosd(8) / right

Fill272:	left_edge
			middle
			stosb
			mov	cx,8
			rep	stosd
			right_edge
			fill_cont
			ret

Fill280:	left_edge
			middle
			stosw
			mov	cx,8
			rep	stosd
			right_edge
			fill_cont
			ret

Fill288:	left_edge
			middle
			stosb
			stosw
			mov	cx,8
			rep	stosd
			right_edge
			fill_cont
			ret

Fill296:	left_edge
			middle
			mov		cx,9
			rep		stosd
			right_edge
			fill_cont
			ret
			
;Fill272: ; left / stosb / stosd(8) right
;Fill280: ; left / stosw / stosd(8) right
;Fill288: ; left / stosb / stosw / stosd(8) / right
;Fill296: ; left / stosd(9) / right

Fill304:	left_edge
			middle
			stosb
			mov		cx,9
			rep		stosd
			right_edge
			fill_cont
			ret

Fill312:	left_edge
			middle
			stosw
			mov		cx,9
			rep		stosd
			right_edge
			fill_cont
			ret

Fill320:	left_edge
			middle
			stosb
			stosw
			mov		cx,9
			rep		stosd
			right_edge
			fill_cont
			ret

Fill328:	left_edge
			middle
			mov		cx,10
			rep		stosd
			right_edge
			fill_cont
			ret

;Fill304: ; left / stosb / stosd(9) right
;Fill312: ; left / stosw / stosd(9) right
;Fill320: ; left / stosb / stosw / stosd(9) / right
;Fill328: ; left / stosd(10) / right

HexChar:	mov		si,di
			mov		bl,al
			shr		bl,1
			shr		bl,1
			shr		bl,1
			shr		bl,1
			and		bx,15
			add		bx,bx
			add		bx,bx
 push ax
			mov		eax,[Hex0+bx]
			mov		[es:di],eax
			add		di,SCREEN_WIDTH_320
			mov		eax,[Hex1+bx]
			mov		[es:di],eax
			add		di,SCREEN_WIDTH_320
			mov		eax,[Hex2+bx]
			mov		[es:di],eax
			add		di,SCREEN_WIDTH_320
			mov		eax,[Hex3+bx]
			mov		[es:di],eax
			add		di,SCREEN_WIDTH_320
			mov		eax,[Hex4+bx]
			mov		[es:di],eax
 pop ax
			mov		di,si
			add		di,4

			mov		bl,al
			and		bl,15
			add		bx,bx
			add		bx,bx
			mov		eax,[Hex0+bx]
			mov		[es:di],eax
			add		di,SCREEN_WIDTH_320
			mov		eax,[Hex1+bx]
			mov		[es:di],eax
			add		di,SCREEN_WIDTH_320
			mov		eax,[Hex2+bx]
			mov		[es:di],eax
			add		di,SCREEN_WIDTH_320
			mov		eax,[Hex3+bx]
			mov		[es:di],eax
			add		di,SCREEN_WIDTH_320
			mov		eax,[Hex4+bx]
			mov		[es:di],eax
			ret

Hex24:		push	ax
			push	bx

			mov		al,bh
			call	Hex8
						
			pop		bx
			pop		ax

			push	ax
			push	bx

			mov		di,8
			call	HexByte

			pop		bx
			pop		ax

			mov		al,ah
			mov		di,8
			jmp		HexByte	; does ret

Hex16:		push	ax
			push	bx

			mov		al,ah
			call	Hex8
						
			pop		bx
			pop		ax

			mov		di,8
			jmp		HexByte ; does ret

Hex8:		xor		di,di
HexByte:	xor		bh,bh
			mov		ah,bl
			add		ah,ah	; *2
			add		bl,ah	; *3
			add		bx,bx	; *6
			add		bx,bx	; *12
			add		di,[BackBufferTable320+bx]	; lookup start ver
;				add		di, [ScreenBuffer]

			jmp		HexChar	 ; does ret
;			ret


section .data 
align	2 ; 16 ; 8 ; 16
	
BackBufferTable320:
		dw SCREEN_WIDTH_320*000,SCREEN_WIDTH_320*001,SCREEN_WIDTH_320*002,SCREEN_WIDTH_320*003,SCREEN_WIDTH_320*004,SCREEN_WIDTH_320*005,SCREEN_WIDTH_320*006,SCREEN_WIDTH_320*007,SCREEN_WIDTH_320*008,SCREEN_WIDTH_320*009
		dw SCREEN_WIDTH_320*010,SCREEN_WIDTH_320*011,SCREEN_WIDTH_320*012,SCREEN_WIDTH_320*013,SCREEN_WIDTH_320*014,SCREEN_WIDTH_320*015,SCREEN_WIDTH_320*016,SCREEN_WIDTH_320*017,SCREEN_WIDTH_320*018,SCREEN_WIDTH_320*019
		dw SCREEN_WIDTH_320*020,SCREEN_WIDTH_320*021,SCREEN_WIDTH_320*022,SCREEN_WIDTH_320*023,SCREEN_WIDTH_320*024,SCREEN_WIDTH_320*025,SCREEN_WIDTH_320*026,SCREEN_WIDTH_320*027,SCREEN_WIDTH_320*028,SCREEN_WIDTH_320*029
		dw SCREEN_WIDTH_320*030,SCREEN_WIDTH_320*031,SCREEN_WIDTH_320*032,SCREEN_WIDTH_320*033,SCREEN_WIDTH_320*034,SCREEN_WIDTH_320*035,SCREEN_WIDTH_320*036,SCREEN_WIDTH_320*037,SCREEN_WIDTH_320*038,SCREEN_WIDTH_320*039
		dw SCREEN_WIDTH_320*040,SCREEN_WIDTH_320*041,SCREEN_WIDTH_320*042,SCREEN_WIDTH_320*043,SCREEN_WIDTH_320*044,SCREEN_WIDTH_320*045,SCREEN_WIDTH_320*046,SCREEN_WIDTH_320*047,SCREEN_WIDTH_320*048,SCREEN_WIDTH_320*049
		dw SCREEN_WIDTH_320*050,SCREEN_WIDTH_320*051,SCREEN_WIDTH_320*052,SCREEN_WIDTH_320*053,SCREEN_WIDTH_320*054,SCREEN_WIDTH_320*055,SCREEN_WIDTH_320*056,SCREEN_WIDTH_320*057,SCREEN_WIDTH_320*058,SCREEN_WIDTH_320*059
		dw SCREEN_WIDTH_320*060,SCREEN_WIDTH_320*061,SCREEN_WIDTH_320*062,SCREEN_WIDTH_320*063,SCREEN_WIDTH_320*064,SCREEN_WIDTH_320*065,SCREEN_WIDTH_320*066,SCREEN_WIDTH_320*067,SCREEN_WIDTH_320*068,SCREEN_WIDTH_320*069
		dw SCREEN_WIDTH_320*070,SCREEN_WIDTH_320*071,SCREEN_WIDTH_320*072,SCREEN_WIDTH_320*073,SCREEN_WIDTH_320*074,SCREEN_WIDTH_320*075,SCREEN_WIDTH_320*076,SCREEN_WIDTH_320*077,SCREEN_WIDTH_320*078,SCREEN_WIDTH_320*079
		dw SCREEN_WIDTH_320*080,SCREEN_WIDTH_320*081,SCREEN_WIDTH_320*082,SCREEN_WIDTH_320*083,SCREEN_WIDTH_320*084,SCREEN_WIDTH_320*085,SCREEN_WIDTH_320*086,SCREEN_WIDTH_320*087,SCREEN_WIDTH_320*088,SCREEN_WIDTH_320*089
		dw SCREEN_WIDTH_320*090,SCREEN_WIDTH_320*091,SCREEN_WIDTH_320*092,SCREEN_WIDTH_320*093,SCREEN_WIDTH_320*094,SCREEN_WIDTH_320*095,SCREEN_WIDTH_320*096,SCREEN_WIDTH_320*097,SCREEN_WIDTH_320*098,SCREEN_WIDTH_320*099

		dw SCREEN_WIDTH_320*100,SCREEN_WIDTH_320*101,SCREEN_WIDTH_320*102,SCREEN_WIDTH_320*103,SCREEN_WIDTH_320*104,SCREEN_WIDTH_320*105,SCREEN_WIDTH_320*106,SCREEN_WIDTH_320*107,SCREEN_WIDTH_320*108,SCREEN_WIDTH_320*109
		dw SCREEN_WIDTH_320*110,SCREEN_WIDTH_320*111,SCREEN_WIDTH_320*112,SCREEN_WIDTH_320*113,SCREEN_WIDTH_320*114,SCREEN_WIDTH_320*115,SCREEN_WIDTH_320*116,SCREEN_WIDTH_320*117,SCREEN_WIDTH_320*118,SCREEN_WIDTH_320*119
		dw SCREEN_WIDTH_320*120,SCREEN_WIDTH_320*121,SCREEN_WIDTH_320*122,SCREEN_WIDTH_320*123,SCREEN_WIDTH_320*124,SCREEN_WIDTH_320*125,SCREEN_WIDTH_320*126,SCREEN_WIDTH_320*127,SCREEN_WIDTH_320*128,SCREEN_WIDTH_320*129
		dw SCREEN_WIDTH_320*130,SCREEN_WIDTH_320*131,SCREEN_WIDTH_320*132,SCREEN_WIDTH_320*133,SCREEN_WIDTH_320*134,SCREEN_WIDTH_320*135,SCREEN_WIDTH_320*136,SCREEN_WIDTH_320*137,SCREEN_WIDTH_320*138,SCREEN_WIDTH_320*139
		dw SCREEN_WIDTH_320*140,SCREEN_WIDTH_320*141,SCREEN_WIDTH_320*142,SCREEN_WIDTH_320*143,SCREEN_WIDTH_320*144,SCREEN_WIDTH_320*145,SCREEN_WIDTH_320*146,SCREEN_WIDTH_320*147,SCREEN_WIDTH_320*148,SCREEN_WIDTH_320*149
		dw SCREEN_WIDTH_320*150,SCREEN_WIDTH_320*151,SCREEN_WIDTH_320*152,SCREEN_WIDTH_320*153,SCREEN_WIDTH_320*154,SCREEN_WIDTH_320*155,SCREEN_WIDTH_320*156,SCREEN_WIDTH_320*157,SCREEN_WIDTH_320*158,SCREEN_WIDTH_320*159
		dw SCREEN_WIDTH_320*160,SCREEN_WIDTH_320*161,SCREEN_WIDTH_320*162,SCREEN_WIDTH_320*163,SCREEN_WIDTH_320*164,SCREEN_WIDTH_320*165,SCREEN_WIDTH_320*166,SCREEN_WIDTH_320*167,SCREEN_WIDTH_320*168,SCREEN_WIDTH_320*169
		dw SCREEN_WIDTH_320*170,SCREEN_WIDTH_320*171,SCREEN_WIDTH_320*172,SCREEN_WIDTH_320*173,SCREEN_WIDTH_320*174,SCREEN_WIDTH_320*175,SCREEN_WIDTH_320*176,SCREEN_WIDTH_320*177,SCREEN_WIDTH_320*178,SCREEN_WIDTH_320*179
		dw SCREEN_WIDTH_320*180,SCREEN_WIDTH_320*181,SCREEN_WIDTH_320*182,SCREEN_WIDTH_320*183,SCREEN_WIDTH_320*184,SCREEN_WIDTH_320*185,SCREEN_WIDTH_320*186,SCREEN_WIDTH_320*187,SCREEN_WIDTH_320*188,SCREEN_WIDTH_320*189
		dw SCREEN_WIDTH_320*190,SCREEN_WIDTH_320*191,SCREEN_WIDTH_320*192,SCREEN_WIDTH_320*193,SCREEN_WIDTH_320*194,SCREEN_WIDTH_320*195,SCREEN_WIDTH_320*196,SCREEN_WIDTH_320*197,SCREEN_WIDTH_320*198,SCREEN_WIDTH_320*199

FillJumpTable:
				dw	Fill000,Fill008,Fill016,Fill024,Fill032,Fill040,Fill048,Fill056,Fill064,Fill072
				dw	Fill080,Fill088,Fill096,Fill104,Fill112,Fill120,Fill128,Fill136,Fill144,Fill152
				dw	Fill160,Fill168,Fill176,Fill184,Fill192,Fill200,Fill208,Fill216,Fill224,Fill232
				dw	Fill240,Fill248,Fill256,Fill264,Fill272,Fill280,Fill288,Fill296,Fill304,Fill312
				dw	Fill320,Fill328


Hex0	dd 000555555h,000005500h,000555555h,000555555h,000550055h,000555555h,000555555h,000555555h,000555555h,000555555h,000555555h,000555555h,000555555h,000005555h,000555555h,000555555h
Hex1	dd 000550055h,000005555h,000550000h,000550000h,000550055h,000000055h,000000055h,000550000h,000550055h,000550055h,000550055h,000550055h,000000055h,000550055h,000000055h,000000055h
Hex2	dd 000550055h,000005500h,000555555h,000555555h,000555555h,000555555h,000555555h,000550000h,000555555h,000555555h,000555555h,000005555h,000000055h,000550055h,000555555h,000555555h
Hex3	dd 000550055h,000005500h,000000055h,000550000h,000550000h,000550000h,000550055h,000550000h,000550055h,000550000h,000550055h,000550055h,000000055h,000550055h,000000055h,000000055h
Hex4	dd 000555555h,000555555h,000555555h,000555555h,000550000h,000555555h,000555555h,000550000h,000555555h,000555555h,000550055h,000555555h,000555555h,000005555h,000555555h,000000055h

align	4
PointList: dw 0b8h, 13ch, 22h, 0ebh, 0c2h, 016h, 0, 0

PointList2: dw 0, 0, 7, 319, 191, 315, 0, 0
 
; dw 0a1h, 12bh, 039h, 0d4h, 0b5h, 01h
 
; dw	056h,0e0h 
; dw	084h,089h 
; dw	06ah,04ch 

; dw 0bah, 03ah,120h
; dw 0edh,0c0h
; dw 018h,0bah

; dw 095h, 011fh 
; dw 045h, 0c8h
; dw 0a9h, 00dh
 
;		dw	10,10
;		dw	190,90
;		dw	30,310
		dw	0,0
		dw	0,0
		dw	0,0
		dw	0,0
		dw	0,0
;		resw	256

DirList:
 dw 1,-1,-1,1,-1,1
 
; dw 1,1,-1,1,1,-1
 
; dw 1,-1
; dw -1,1
; dw -1,1
 
 dw	1,1
 dw	-1,1
 dw	1,-1
 dw 	+1,-1,+1,-1,+1,-1,+1,-1,+1,-1,+1,-1
 
edgeleft:  times 360/4 db 15-1, 15-(2+1), 15-(4+2+1), 15-(8+4+2+1)
edgeright: times 360/4 db 1, (2+1), (4+2+1), (8+4+2+1) ; , (4+2+1), (2+1), 1

edgerightcga: times 320/8  db 10000000b,11000000b,11100000b,11110000b,11111000b,11111100b,11111110b,11111111b
;edgeleftcga: times 320/8  db 00000001b,00000011b,00000111b,00001111b,00011111b,00111111b,01111111b,11111111b
;edgeleftcga: times 320/8  db 11111111b,11111110b,11111100b,11111000b,11110000b,11100000b,11000000b,10000000b
edgeleftcga: times 320/8  db 11111111b,01111111b,00111111b,00011111b,00001111b,00000111b,00000011b,00000001b

		
section .bss 	; put uninitialized data here
align	4
EdgeTable	resd	800

ScreenBuffer	resw	1
ScreenBufferSeg	resw	1
Colour		resb	1

; left = set bitmap register 	- 11111111, 01111111, 00111111, 00011111, 00001111, 00000111, 00000011, 00000001, 00000000
; right = set bitmap register 	- 11111111, 11111110, 11111100, 11111000, 11110000, 11100000, 11000000, 10000000, 00000000
