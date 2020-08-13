#make_bin#

#LOAD_SEGMENT=FFFFh#
#LOAD_OFFSET=0000h#

#CS=0000h#
#IP=0000h#

#DS=0000h#
#ES=0000h#

#SS=0000h#
#SP=FFFEh#

#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#

; add your code here
         jmp     st1 
         nop
         dw      0000
         dw      0000
         dw      tisr
         dw      0000
		 db     1020 dup(0)
;main program


porta equ 20h
portb equ 22h
portc equ 24h
creg equ 26h

counter0 equ 10H
counter1 equ 12H
counter2 equ 14h
creg_count equ 16h

porta2 equ 18h
portb2 equ 1Ah
portc2 equ 1Ch
creg2 equ 1Eh

timer1 equ 30h
level equ 02h
power equ 03h

st1:      cli 
 ;intialize ds, es,ss to start of RAM
         mov       ax,0200h
         mov       ds,ax
         mov       es,ax
         mov       ss,ax
         mov       sp,0FFEH
ini:
;;default values to data locations 

    mov word ptr timer1 , 0000h
    mov byte ptr level , 80h
    mov byte ptr power , 05h
	mov al,10001001b
	out creg,al ;; init 8255(1)
	mov al,00h
	out portb,al
	out porta,al 
	mov al,10000000b
	out creg2,al ;; init 8255(2)  
	mov al,00
	out portc2,al   
	
;;timer1 
;;initialize counter0 and counter1
	mov al,00000011b
	out creg2,al;;gate high
	mov al,00110100b
	out creg_count,al
	mov al,0A8h
	out counter0,al
	mov al,61h;;count of 25000
	out counter0,al
	mov al,01010101b
	out creg_count,al
	mov al,9Ah
	out counter1,al
	mov al,00000010b
	out creg2,al;;gate low
	
	
;;main_main
Y12:in al,portc
	and al,1fh
	cmp al,1fh
	jnz Y12
	
	call delay
	
Y13: in al,portc
	and al,1fh
	cmp al,1fh
	jz Y13
	
	call delay
	
	in al,portc
	and al,1fh
	cmp al,1fh
	jz Y13

	cmp al,0fh
	je Y14
	cmp al,017h
	je Y15
	cmp al,01bh
	je Y16
	cmp al,01dh
	je Y17
	cmp al,01eh
	je start_start
	jmp Y13
	
Y14:call time_10m
	mov byte ptr [level] , 00
	jmp Y12
	
Y15: call time_1m
	mov byte ptr [level] , 00
	jmp Y12

Y16: call time_10s
	mov byte ptr [level] , 00
	jmp Y12

Y17: call power_sub
	mov byte ptr [level] , 00
	jmp Y12
;;end of debounce

start_start:
	cmp byte ptr [level] , 80h
	jnz no_quick
	mov word ptr [timer1] , 0030h
	mov byte ptr [level] , 00h
no_quick:
	mov al,00000011b;;gate high 
	out creg2,al
	mov al,00000111b;;initial impulse 
	out creg2,al
	mov al,00000110b;;initial impulse over
	out creg2,al
	stc 
	call parts
	
;;poll the stop button 
	and ah,00
	
;;wait till start button lifted 	
Y40:in al,portc
	test ax,1
	jz Y40
	call delay
a1:	
	cmp byte ptr [level] , 0FFh
	jz complete
	in al,portc
	and al,20h
	cmp al,00h
	je Y30
	and al,01h
	cmp al,00h
	je Y31
	jmp a1
Y31: 
	call delay
	in al,portc
	and al,01h
	cmp al,00h
	jne a1
	call add30
	call delay
	
;;wait til start button lifted 		
Y48:in al,portc
	and al,01h
	cmp al,00h
	je Y48
	jmp a1
Y30: 
	in al,portc
	and al,20h
	cmp al,00h
	jne a1
	mov al,00000010b
	out creg2,al;;gate low
	clc
	call parts
	
;;wait til stop button lifted 
Y49:in al,portc
	test ax,20h
	jz Y49
a3:	in al,portc
	test ax,20h
	jz reset_now
	test ax,1
	jz start_again
	jmp a3

reset_now:
	in al,portc
	test ax,20h
	jnz a3
	mov word ptr [timer1] , 0000h
	call update_disp
	jmp ini

start_again:
	in al,portc
	test ax,01h
	jnz a3
	mov al,00000011b
	out creg2,al;;gate high
	mov bh,byte ptr [level]
	ror bh,1
	jnc no_on 
	stc 
	call parts 
Y50:in al,portc
	test ax,01h
	jz Y50
no_on:	jmp a1	

;;;;;;;;;;;;;;;

add30:
	mov ax , word ptr [timer1] 
	add ax,030h
	and ax,0f0h
	cmp ax,060h
	jl lesss
	add word ptr [timer1] , 0d0h
	jmp donn
lesss:	add word ptr [timer1] , 030h
donn:	
ret

;;;;;;;;;;;;;;;

tisr:
	in al,portc
	test al,80h
	jz a10s
	test al,40h
	jz a1s

iret 	

;;;;;;;;;;;;;;;

a1s:
	cmp word ptr [timer1] , 00
	jz n1;;just if in case there is skew
	call dec_timer 
	call update_disp
n1:
iret

;;;;;;;;;;;;;;

a10s:
	PUSH BX
	PUSH CX
	PUSH AX
	test al,40h
	jnz noq1s
	cmp word ptr [timer1] , 00
	je finish
	call dec_timer
	call update_disp
noq1s:	
	cmp word ptr [timer1] , 00
	jz finish
no_second:	
	mov bl,byte ptr [power]
	shl bl,1
	mov bh,byte ptr [level]
	ror bh,1
	jc second_count
	stc
	call parts
	mov al,10011000b
	out creg_count,al
	mov al,bl
	out counter2,al
	inc byte ptr [level]
	jmp done_quantum_10s
second_count:
	clc
	call parts
	neg bl
	add bl,0Ah
	cmp bl,00
	jne not_nocount
	dec byte ptr [level]
	jmp no_second
not_nocount:	
	mov al,bl
	out counter2,al	 
	dec byte ptr [level]
	jmp done_quantum_10s
finish:
	mov byte ptr level,0FFh
done_quantum_10s:
	POP AX
	POP CX
	POP BX
iret

;;;;;;;;;;;;;;;;;
;;set cf to on the parts 
;;reset cf to off the parts 
parts: 
	jnc offf
	mov al,00000001b
	out creg2,al;;gate high again
	mov al,00000101b
	out creg2,al
	jmp retur
offf:
	mov al,00000000b
	out creg2,al;;gate high again
	mov al,00000100b
	out creg2,al
retur: ret 

;;;;;;;;;;;;;;;;;;;

dec_timer:
	PUSH DX
	PUSH BX
	mov ax,word ptr [timer1]
	mov bx,ax
	dec ax
	mov dx,ax
	and ax,000fh
	cmp ax,000fh
	jz Y20
	jmp Y21
Y20:
	and dx,0fff0h
	add dx,0009h
Y21:
	mov ax,bx
	and ax,00f0h
	cmp ax,00f0h
	jz Y22
	jmp Y23
Y22:
	and dx,0ff0fh
	add dx,0050h
Y23:
	mov ax,bx
	and ax,0f00h
	cmp ax,0f00h
	jz Y24
	jmp Y25
Y24:
	and dx,0f0ffh
	add dx,0900h
Y25: 
	mov word ptr [timer1],dx
	POP BX
	POP DX
ret

;;;;;;;;;;;;;;;;;;;

time_10s:
	push bx
	add word ptr timer1,0010h
	mov bx , word ptr [timer1]
	and bx,0f0h
	cmp bx,060h
	je Y2
Y4: jmp Y3
Y2: sub word ptr timer1,0060h
	add word ptr timer1,0100h
	jmp Y4	
Y3: call update_disp
	pop bx
ret
 
;;;;;;;;;;;;

time_1m:
	push bx
	add word ptr timer1,0100h
	mov bx , word ptr [timer1]
	and bx,0f00h
	cmp bx,0a00h
	je Y5
	jmp Y6
Y5:	add word ptr timer1,0600h
Y6: call update_disp
	pop bx
ret

;;;;;;;;;;;;;
	
time_10m:
	add word ptr timer1,1000h
	cmp word ptr timer1,6000h
	jge Y7
	jmp Y8
Y7:	mov word ptr timer1,6000h
Y8: call update_disp
ret

;;;;;;;;;;;;;

power_sub:
	dec byte ptr power
	cmp byte ptr power,0
	je Y11
	jmp Y10
Y11: mov byte ptr power,5	
Y10: call update_pow
ret

;;;;;;;;;;;
update_pow:
	PUSH BX
	mov bx, word ptr [power]
	mov al,bl
	out portb,al
	
	POP BX
ret
update_disp:
	PUSH BX
	mov bx, word ptr [timer1]
	mov al,bl
	out portb,al
	mov al,bh
	out porta,al
	POP BX
ret
	
;;;;;;;;;;;;;;;

delay:
	mov cx,3020 
Yn: nop
	dec cx
	jnz Yn
ret 

;;;;;;;;;;;;;;;

complete: 
	clc
	call parts
	mov cx,0FFFFh
Y66:mov al,00001001b
	out creg2,al
	loop Y66
	mov al,00001000b
	out creg2,al
	jmp ini

;;;;;;;;;;;;;;;