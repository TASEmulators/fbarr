; Make68K - V0.30 - Copyright 1998, Mike Coates (mame@btinternet.com)
;                               & Darren Olafson (deo@mail.island.net)

		 BITS 32

		 GLOBAL _M68000_RUN
		 GLOBAL _M68000_RESET
		 GLOBAL _M68000_regs
		 GLOBAL _M68000_COMPTABLE
		 GLOBAL _M68000_OPCODETABLE
		 EXTERN _m68k_ICount
		 EXTERN _a68k_memory_intf
		 EXTERN _mem_amask
; Vars Mame declares / needs access to

		 EXTERN _mame_debug
		 EXTERN _illegal_op
		 EXTERN _illegal_pc
		 EXTERN _OP_ROM
		 EXTERN _OP_RAM
		 EXTERN _opcode_entry
		 SECTION .text

_M68000_RESET:
		 pushad

; Build Jump Table (not optimised!)

		 lea   edi,[_M68000_OPCODETABLE]		; Jump Table
		 lea   esi,[_M68000_COMPTABLE]		; RLE Compressed Table
		 mov   ebp,[esi]
		 add   esi,byte 4
RESET0:
		 mov   eax,[esi]
		 mov   ecx,eax
		 and   eax,0xffffff
		 add   eax,ebp
		 add   esi,byte 4
		 shr   ecx,24
		 jne   short RESET1
		 movzx ecx,word [esi]		; Repeats
		 add   esi,byte 2
		 jecxz RESET2		; Finished!
RESET1:
		 mov   [edi],eax
		 add   edi,byte 4
		 dec   ecx
		 jnz   short RESET1
		 jmp   short RESET0
RESET2:
		 popad
		 ret

		 ALIGN 4

_M68000_RUN:
		 pushad
		 mov   esi,[R_PC]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
; Check for Interrupt waiting

		 test  [R_IRQ],byte 07H
		 jne   near interrupt

IntCont:
		 test  dword [_m68k_ICount],-1
		 js    short MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]
		 ALIGN 4

MainExit:
		 mov   [R_PC],esi		; Save PC
		 mov   [R_CCR],edx
		 test  byte [R_SR_H],20H
		 mov   eax,[R_A7]		; Get A7
		 jne   short ME1		; Mode ?
		 mov   [R_USP],eax		;Save in USP
		 jmp   short MC68Kexit
ME1:
		 mov   [R_ISP],eax
MC68Kexit:
		 popad
		 ret
		 ALIGN 4

; Interrupt check

interrupt:
		 mov   eax,[R_IRQ]
		 and   eax,byte 07H
		 cmp   al,7		 ; Always take 7
		 je    short procint

		 mov   ebx,[R_SR_H]		; int mask
		 and   ebx,byte 07H
		 cmp   eax,ebx
		 jle   near IntCont

		 ALIGN 4

procint:
		 and   byte [R_IRQ],7fh		; remove stop

		 push  eax		; save level

		 mov   ebx,eax
		 mov   [R_CCR],edx
		 mov   ecx, eax		; irq line #
		 call  dword [R_IRQ_CALLBACK]	; get the IRQ level
		 mov   edx,[R_CCR]
		 test  eax,eax
		 jns   short AUTOVECTOR
		 mov   eax,ebx
		 add   eax,byte 24		; Vector

AUTOVECTOR:

		 call  Exception

		 pop   eax		; set Int mask
		 mov   bl,byte [R_SR_H]
		 and   bl,0F8h
		 or    bl,al
		 mov   byte [R_SR_H],bl

		 jmp   IntCont

		 ALIGN 4

Exception:
		 push  edx		; Save flags
		 and   eax,0FFH		; Zero Extend IRQ Vector
		 push  eax		; Save for Later
		 mov   al,[exception_cycles+eax]		; Get Cycles
		 sub   [_m68k_ICount],eax		; Decrement ICount
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   ECX,edx
		 and   ECX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,ECX 				; C

		 mov   ECX,edx
		 shr   ECX,10
		 and   ECX,byte 2
		 or    eax,ECX				; O

		 mov   ah,byte [R_SR_H] 	; T, S & I

		 mov   edi,[R_A7]		; Get A7
		 test  ah,20H	; Which Mode ?
		 jne   short ExSuperMode		; Supervisor
		 or    byte [R_SR_H],20H	; Set Supervisor Mode
		 mov   [R_USP],edi		; Save in USP
		 mov   edi,[R_ISP]		; Get ISP
ExSuperMode:
		 sub   edi,byte 6
		 mov   [R_A7],edi		; Put in A7
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 add   edi,byte 2
		 mov   [R_PC],ESI
		 mov   edx,ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 pop   eax		;Level
		 shl   eax,2
		 add   eax,[R_VBR]
		 mov   [R_PC],ESI
		 mov   ecx,EAX
		 call  [_a68k_memory_intf+12]
		 mov   esi,eax		;Set PC
		 pop   edx		; Restore flags
		 test  esi, dword 1
		 jz    near OP0_00001
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_00001:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_00001_Bank:
		 ret
		 ALIGN 4

OP0_1000:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1010:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1018:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_101f:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1020:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1027:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1028:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1030:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_1030_1
		 cwde
OP0_1030_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1038:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1039:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_103a:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_103b:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_103b_1
		 cwde
OP0_103b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_103c:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1080:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1090:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1098:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_109f:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10a7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_10b0_1
		 cwde
OP0_10b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10b8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10b9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10ba:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10bb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_10bb_1
		 cwde
OP0_10bb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10bc:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10c0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10d8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10df:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10e0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10e7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_10f0_1
		 cwde
OP0_10f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10fa:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10fb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_10fb_1
		 cwde
OP0_10fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_10fc:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1100:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1110:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1118:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_111f:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1120:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1127:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1128:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1130:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_1130_1
		 cwde
OP0_1130_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1138:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1139:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_113a:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_113b:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_113b_1
		 cwde
OP0_113b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_113c:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1140:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1150:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1158:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_115f:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1160:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1167:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1168:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1170:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_1170_1
		 cwde
OP0_1170_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1178:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1179:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_117a:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_117b:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_117b_1
		 cwde
OP0_117b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_117c:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1180:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_1180_1
		 cwde
OP0_1180_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1190:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_1190_1
		 cwde
OP0_1190_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1198:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_1198_1
		 cwde
OP0_1198_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_119f:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_119f_1
		 cwde
OP0_119f_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_11a0_1
		 cwde
OP0_11a0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11a7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_11a7_1
		 cwde
OP0_11a7_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_11a8_1
		 cwde
OP0_11a8_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_11b0_1
		 cwde
OP0_11b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_11b0_2
		 cwde
OP0_11b0_2:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11b8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_11b8_1
		 cwde
OP0_11b8_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11b9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_11b9_1
		 cwde
OP0_11b9_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11ba:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_11ba_1
		 cwde
OP0_11ba_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11bb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_11bb_1
		 cwde
OP0_11bb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   ECX
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_11bb_2
		 cwde
OP0_11bb_2:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11bc:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AL,AL
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_11bc_1
		 cwde
OP0_11bc_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 15
		 mov   EAX,[R_D0+ECX*4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11df:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11e7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_11f0_1
		 cwde
OP0_11f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11fa:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 test  AL,AL
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11fb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_11fb_1
		 cwde
OP0_11fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 test  AL,AL
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_11fc:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AL,AL
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_13c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 15
		 mov   EAX,[R_D0+ECX*4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_13d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_13d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_13df:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_13e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_13e7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_13e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_13f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_13f0_1
		 cwde
OP0_13f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_13f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_13f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_13fa:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 test  AL,AL
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_13fb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_13fb_1
		 cwde
OP0_13fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 test  AL,AL
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_13fc:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AL,AL
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1ec0:				;:
		 add   esi,byte 2

		 and   ecx,byte 15
		 mov   EAX,[R_D0+ECX*4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1ed0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1ed8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1edf:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1ee0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1ee7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1ee8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1ef0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_1ef0_1
		 cwde
OP0_1ef0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1ef8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1ef9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1efa:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1efb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_1efb_1
		 cwde
OP0_1efb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1efc:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1f00:				;:
		 add   esi,byte 2

		 and   ecx,byte 15
		 mov   EAX,[R_D0+ECX*4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1f10:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1f18:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1f1f:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1f20:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1f27:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1f28:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1f30:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_1f30_1
		 cwde
OP0_1f30_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1f38:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1f39:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1f3a:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1f3b:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_1f3b_1
		 cwde
OP0_1f3b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_1f3c:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AL,AL
		 pushfd
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2000:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2010:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2018:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2020:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2028:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2030:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_2030_1
		 cwde
OP0_2030_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2038:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2039:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_203a:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_203b:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_203b_1
		 cwde
OP0_203b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_203c:				;:
		 add   esi,byte 2

		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2040:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2050:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2058:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2060:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2068:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2070:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_2070_1
		 cwde
OP0_2070_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2078:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2079:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_207a:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_207b:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_207b_1
		 cwde
OP0_207b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_207c:				;:
		 add   esi,byte 2

		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2080:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2090:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2098:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_20b0_1
		 cwde
OP0_20b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20b8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20b9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20ba:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20bb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_20bb_1
		 cwde
OP0_20bb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20bc:				;:
		 add   esi,byte 2

		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20c0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20d8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20e0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_20f0_1
		 cwde
OP0_20f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20fa:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20fb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_20fb_1
		 cwde
OP0_20fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_20fc:				;:
		 add   esi,byte 2

		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2100:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2110:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2118:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2120:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2128:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2130:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_2130_1
		 cwde
OP0_2130_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2138:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2139:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_213a:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_213b:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_213b_1
		 cwde
OP0_213b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_213c:				;:
		 add   esi,byte 2

		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2140:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2150:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2158:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2160:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2168:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2170:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_2170_1
		 cwde
OP0_2170_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2178:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2179:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_217a:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_217b:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_217b_1
		 cwde
OP0_217b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_217c:				;:
		 add   esi,byte 2

		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2180:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_2180_1
		 cwde
OP0_2180_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2190:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_2190_1
		 cwde
OP0_2190_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_2198:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_2198_1
		 cwde
OP0_2198_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_21a0_1
		 cwde
OP0_21a0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_21a8_1
		 cwde
OP0_21a8_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_21b0_1
		 cwde
OP0_21b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_21b0_2
		 cwde
OP0_21b0_2:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21b8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_21b8_1
		 cwde
OP0_21b8_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21b9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_21b9_1
		 cwde
OP0_21b9_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 34
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21ba:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_21ba_1
		 cwde
OP0_21ba_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21bb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_21bb_1
		 cwde
OP0_21bb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   ECX
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_21bb_2
		 cwde
OP0_21bb_2:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21bc:				;:
		 add   esi,byte 2

		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 test  EAX,EAX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_21bc_1
		 cwde
OP0_21bc_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 15
		 mov   EAX,[R_D0+ECX*4]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_21f0_1
		 cwde
OP0_21f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21fa:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21fb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_21fb_1
		 cwde
OP0_21fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_21fc:				;:
		 add   esi,byte 2

		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_23c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 15
		 mov   EAX,[R_D0+ECX*4]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_23d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_23d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_23e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_23e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_23f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_23f0_1
		 cwde
OP0_23f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 34
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_23f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_23f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 36
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_23fa:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_23fb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_23fb_1
		 cwde
OP0_23fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 34
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_23fc:				;:
		 add   esi,byte 2

		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 test  EAX,EAX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3000:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3010:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3018:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3020:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3028:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3030:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_3030_1
		 cwde
OP0_3030_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3038:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3039:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_303a:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_303b:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_303b_1
		 cwde
OP0_303b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_303c:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3040:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 shr   ecx,9
		 and   ecx,byte 7
		 cwde
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3050:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 cwde
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3058:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 cwde
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3060:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 cwde
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3068:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 cwde
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3070:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_3070_1
		 cwde
OP0_3070_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 cwde
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3078:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 cwde
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3079:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 cwde
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_307a:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 cwde
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_307b:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_307b_1
		 cwde
OP0_307b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 shr   ecx,9
		 and   ecx,byte 7
		 cwde
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_307c:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 shr   ecx,9
		 and   ecx,byte 7
		 cwde
		 mov   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3080:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3090:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3098:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_30b0_1
		 cwde
OP0_30b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30b8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30b9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30ba:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30bb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_30bb_1
		 cwde
OP0_30bb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30bc:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30c0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30d8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30e0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_30f0_1
		 cwde
OP0_30f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30fa:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30fb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_30fb_1
		 cwde
OP0_30fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_30fc:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3100:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3110:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3118:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3120:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3128:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3130:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_3130_1
		 cwde
OP0_3130_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3138:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3139:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_313a:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_313b:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_313b_1
		 cwde
OP0_313b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_313c:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3140:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3150:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3158:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3160:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3168:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3170:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_3170_1
		 cwde
OP0_3170_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3178:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3179:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_317a:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_317b:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_317b_1
		 cwde
OP0_317b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_317c:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3180:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 mov   EAX,[R_D0+EBX*4]
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_3180_1
		 cwde
OP0_3180_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3190:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_3190_1
		 cwde
OP0_3190_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_3198:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_3198_1
		 cwde
OP0_3198_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_31a0_1
		 cwde
OP0_31a0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_31a8_1
		 cwde
OP0_31a8_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_31b0_1
		 cwde
OP0_31b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_31b0_2
		 cwde
OP0_31b0_2:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31b8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_31b8_1
		 cwde
OP0_31b8_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31b9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_31b9_1
		 cwde
OP0_31b9_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31ba:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_31ba_1
		 cwde
OP0_31ba_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31bb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_31bb_1
		 cwde
OP0_31bb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   ECX
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_31bb_2
		 cwde
OP0_31bb_2:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31bc:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AX,AX
		 pushfd
		 shr   ecx,9
		 and   ecx,byte 7
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_31bc_1
		 cwde
OP0_31bc_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 15
		 mov   EAX,[R_D0+ECX*4]
		 test  AX,AX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_31f0_1
		 cwde
OP0_31f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31fa:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 test  AX,AX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31fb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_31fb_1
		 cwde
OP0_31fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 test  AX,AX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_31fc:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AX,AX
		 pushfd
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_33c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 15
		 mov   EAX,[R_D0+ECX*4]
		 test  AX,AX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_33d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_33d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_33e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_33e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_33f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_33f0_1
		 cwde
OP0_33f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_33f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_33f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_33fa:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 test  AX,AX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_33fb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_33fb_1
		 cwde
OP0_33fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 test  AX,AX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_33fc:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  AX,AX
		 pushfd
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0000:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EAX,[R_D0+ECX*4]
		 or    AL,BL
		 pushfd
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0010:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0018:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_001f:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0020:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0027:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0028:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0030:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0030_1
		 cwde
OP0_0030_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0038:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0039:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_003c:				;:
		 add   esi,byte 2

		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   ECX,edx
		 and   ECX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,ECX 				; C

		 mov   ECX,edx
		 shr   ECX,10
		 and   ECX,byte 2
		 or    eax,ECX				; O

		 or    AL,BL
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0040:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EAX,[R_D0+ECX*4]
		 or    AX,BX
		 pushfd
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0050:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0058:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0060:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0068:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0070:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0070_1
		 cwde
OP0_0070_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0078:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0079:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_007c:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 jne   near OP0_007c_1

		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_007c_1:
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   ECX,edx
		 and   ECX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,ECX 				; C

		 mov   ECX,edx
		 shr   ECX,10
		 and   ECX,byte 2
		 or    eax,ECX				; O

		 mov   ah,byte [R_SR_H] 	; T, S & I

		 or    AX,BX
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_007c_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_007c_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0080:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EAX,[R_D0+ECX*4]
		 or    EAX,EBX
		 pushfd
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0090:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0098:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_00a0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_00a8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_00b0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_00b0_1
		 cwde
OP0_00b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 34
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_00b8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_00b9:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 36
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0200:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EAX,[R_D0+ECX*4]
		 and   AL,BL
		 pushfd
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0210:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0218:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_021f:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0220:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0227:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0228:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0230:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0230_1
		 cwde
OP0_0230_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0238:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0239:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_023c:				;:
		 add   esi,byte 2

		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   ECX,edx
		 and   ECX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,ECX 				; C

		 mov   ECX,edx
		 shr   ECX,10
		 and   ECX,byte 2
		 or    eax,ECX				; O

		 and   AL,BL
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0240:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EAX,[R_D0+ECX*4]
		 and   AX,BX
		 pushfd
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0250:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0258:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0260:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0268:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0270:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0270_1
		 cwde
OP0_0270_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0278:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0279:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_027c:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 jne   near OP0_027c_1

		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_027c_1:
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   ECX,edx
		 and   ECX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,ECX 				; C

		 mov   ECX,edx
		 shr   ECX,10
		 and   ECX,byte 2
		 or    eax,ECX				; O

		 mov   ah,byte [R_SR_H] 	; T, S & I

		 and   AX,BX
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_027c_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_027c_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0280:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EAX,[R_D0+ECX*4]
		 and   EAX,EBX
		 pushfd
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0290:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0298:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_02a0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_02a8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_02b0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_02b0_1
		 cwde
OP0_02b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 34
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_02b8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_02b9:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 36
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0400:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EAX,[R_D0+ECX*4]
		 sub   AL,BL
		 pushfd
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0410:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0418:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_041f:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0420:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0427:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0428:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0430:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0430_1
		 cwde
OP0_0430_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0438:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0439:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0440:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EAX,[R_D0+ECX*4]
		 sub   AX,BX
		 pushfd
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0450:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0458:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0460:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0468:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0470:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0470_1
		 cwde
OP0_0470_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0478:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0479:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0480:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EAX,[R_D0+ECX*4]
		 sub   EAX,EBX
		 pushfd
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0490:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0498:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_04a0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_04a8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_04b0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_04b0_1
		 cwde
OP0_04b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 34
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_04b8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_04b9:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 36
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0600:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EAX,[R_D0+ECX*4]
		 add   AL,BL
		 pushfd
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0610:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0618:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_061f:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0620:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0627:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0628:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0630:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0630_1
		 cwde
OP0_0630_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0638:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0639:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0640:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EAX,[R_D0+ECX*4]
		 add   AX,BX
		 pushfd
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0650:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0658:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0660:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0668:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0670:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0670_1
		 cwde
OP0_0670_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0678:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0679:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0680:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EAX,[R_D0+ECX*4]
		 add   EAX,EBX
		 pushfd
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0690:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0698:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_06a0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_06a8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_06b0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_06b0_1
		 cwde
OP0_06b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 34
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_06b8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_06b9:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 36
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a00:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EAX,[R_D0+ECX*4]
		 xor   AL,BL
		 pushfd
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a10:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a18:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a1f:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a20:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a27:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a28:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a30:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0a30_1
		 cwde
OP0_0a30_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a38:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a39:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,BL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a3c:				;:
		 add   esi,byte 2

		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   ECX,edx
		 and   ECX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,ECX 				; C

		 mov   ECX,edx
		 shr   ECX,10
		 and   ECX,byte 2
		 or    eax,ECX				; O

		 xor   AL,BL
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a40:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EAX,[R_D0+ECX*4]
		 xor   AX,BX
		 pushfd
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a50:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a58:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a60:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a68:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a70:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0a70_1
		 cwde
OP0_0a70_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a78:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a79:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,BX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a7c:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 jne   near OP0_0a7c_1

		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_0a7c_1:
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   ECX,edx
		 and   ECX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,ECX 				; C

		 mov   ECX,edx
		 shr   ECX,10
		 and   ECX,byte 2
		 or    eax,ECX				; O

		 mov   ah,byte [R_SR_H] 	; T, S & I

		 xor   AX,BX
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_0a7c_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_0a7c_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a80:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EAX,[R_D0+ECX*4]
		 xor   EAX,EBX
		 pushfd
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a90:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0a98:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0aa0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 30
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0aa8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0ab0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0ab0_1
		 cwde
OP0_0ab0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 34
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0ab8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 32
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0ab9:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,EBX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 36
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c00:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EAX,[R_D0+ECX*4]
		 cmp   AL,BL
		 pushfd
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c10:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   AL,BL
		 pushfd
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c18:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   AL,BL
		 pushfd
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c1f:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   AL,BL
		 pushfd
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c20:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   AL,BL
		 pushfd
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c27:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   AL,BL
		 pushfd
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c28:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   AL,BL
		 pushfd
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c30:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0c30_1
		 cwde
OP0_0c30_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   AL,BL
		 pushfd
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c38:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   AL,BL
		 pushfd
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c39:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   AL,BL
		 pushfd
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c40:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EAX,[R_D0+ECX*4]
		 cmp   AX,BX
		 pushfd
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c50:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   AX,BX
		 pushfd
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c58:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   AX,BX
		 pushfd
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c60:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   AX,BX
		 pushfd
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c68:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   AX,BX
		 pushfd
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c70:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0c70_1
		 cwde
OP0_0c70_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   AX,BX
		 pushfd
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c78:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   AX,BX
		 pushfd
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c79:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movzx EBX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   AX,BX
		 pushfd
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c80:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EAX,[R_D0+ECX*4]
		 cmp   EAX,EBX
		 pushfd
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c90:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   EAX,EBX
		 pushfd
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0c98:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   EAX,EBX
		 pushfd
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0ca0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   EAX,EBX
		 pushfd
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0ca8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   EAX,EBX
		 pushfd
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0cb0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0cb0_1
		 cwde
OP0_0cb0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   EAX,EBX
		 pushfd
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0cb8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   EAX,EBX
		 pushfd
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0cb9:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EBX,dword [esi+ebp]
		 rol   EBX,16
		 add   esi,byte 4
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   EAX,EBX
		 pushfd
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0100:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 31
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 or    edx,byte 40h	; Set Zero Flag
		 test  [R_D0+ebx*4],ECX
		 jz    short OP0_0100_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0100_1:
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0110:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0110_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0110_1:
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0118:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0118_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0118_1:
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_011f:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_011f_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_011f_1:
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0120:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0120_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0120_1:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0127:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0127_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0127_1:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0128:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0128_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0128_1:
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0130:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0130_1
		 cwde
OP0_0130_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0130_2
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0130_2:
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0138:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0138_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0138_1:
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0139:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0139_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0139_1:
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_013a:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_013a_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_013a_1:
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_013b:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_013b_1
		 cwde
OP0_013b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_013b_2
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_013b_2:
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_013c:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_013c_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_013c_1:
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0140:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 31
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 or    edx,byte 40h	; Set Zero Flag
		 test  [R_D0+ebx*4],ECX
		 jz    short OP0_0140_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0140_1:
		 xor   [R_D0+ebx*4],ECX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0150:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0150_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0150_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0158:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0158_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0158_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_015f:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_015f_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_015f_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0160:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0160_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0160_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0167:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0167_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0167_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0168:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0168_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0168_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0170:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0170_1
		 cwde
OP0_0170_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0170_2
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0170_2:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0178:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0178_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0178_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0179:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0179_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0179_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0180:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 31
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 or    edx,byte 40h	; Set Zero Flag
		 test  [R_D0+ebx*4],ECX
		 jz    short OP0_0180_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0180_1:
		 not   ecx
		 and   [R_D0+ebx*4],ECX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0190:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0190_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0190_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0198:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0198_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0198_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_019f:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_019f_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_019f_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01a0_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01a0_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01a7:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01a7_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01a7_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01a8_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01a8_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_01b0_1
		 cwde
OP0_01b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01b0_2
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01b0_2:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01b8:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01b8_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01b8_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01b9:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01b9_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01b9_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01c0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 31
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 or    edx,byte 40h	; Set Zero Flag
		 test  [R_D0+ebx*4],ECX
		 jz    short OP0_01c0_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01c0_1:
		 or    [R_D0+ebx*4],ECX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01d0_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01d0_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01d8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01d8_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01d8_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01df:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01df_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01df_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01e0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01e0_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01e0_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01e7:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01e7_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01e7_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01e8_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01e8_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_01f0_1
		 cwde
OP0_01f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01f0_2
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01f0_2:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01f8:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01f8_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01f8_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01f9:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   ecx, [R_D0+ECX*4]
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_01f9_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_01f9_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0108:				;:
		 add   esi,byte 2

		 push  edx
		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   bh,al
		 add   edi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   bl,al
		 mov   [R_D0+ecx*4],bx
		 pop   edx
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0148:				;:
		 add   esi,byte 2

		 push  edx
		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   bh,al
		 add   edi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   bl,al
		 add   edi,byte 2
		 shl   ebx,16
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   bh,al
		 add   edi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   bl,al
		 mov   [R_D0+ecx*4],ebx
		 pop   edx
		 sub   dword [_m68k_ICount],byte 36
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0188:				;:
		 add   esi,byte 2

		 push  edx
		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   eax,[R_D0+ecx*4]
		 rol   eax,byte 24
		 mov   [R_PC],ESI
		 push  EAX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 pop   EDI
		 pop   EAX
		 add   edi,byte 2
		 rol   eax,byte 8
		 mov   [R_PC],ESI
		 push  EAX
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 pop   EAX
		 pop   edx
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_01c8:				;:
		 add   esi,byte 2

		 push  edx
		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   eax,[R_D0+ecx*4]
		 rol   eax,byte 8
		 mov   [R_PC],ESI
		 push  EAX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 pop   EDI
		 pop   EAX
		 add   edi,byte 2
		 rol   eax,byte 8
		 mov   [R_PC],ESI
		 push  EAX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 pop   EDI
		 pop   EAX
		 add   edi,byte 2
		 rol   eax,byte 8
		 mov   [R_PC],ESI
		 push  EAX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 pop   EDI
		 pop   EAX
		 add   edi,byte 2
		 rol   eax,byte 8
		 mov   [R_PC],ESI
		 push  EAX
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 pop   EAX
		 pop   edx
		 sub   dword [_m68k_ICount],byte 36
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0800:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 31
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 or    edx,byte 40h	; Set Zero Flag
		 test  [R_D0+ebx*4],ECX
		 jz    short OP0_0800_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0800_1:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0810:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0810_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0810_1:
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0818:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0818_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0818_1:
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_081f:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_081f_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_081f_1:
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0820:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0820_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0820_1:
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0827:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0827_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0827_1:
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0828:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0828_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0828_1:
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0830:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0830_1
		 cwde
OP0_0830_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0830_2
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0830_2:
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0838:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0838_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0838_1:
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0839:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0839_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0839_1:
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_083a:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_083a_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_083a_1:
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_083b:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_083b_1
		 cwde
OP0_083b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_083b_2
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_083b_2:
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0840:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 31
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 or    edx,byte 40h	; Set Zero Flag
		 test  [R_D0+ebx*4],ECX
		 jz    short OP0_0840_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0840_1:
		 xor   [R_D0+ebx*4],ECX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0850:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0850_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0850_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0858:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0858_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0858_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_085f:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_085f_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_085f_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0860:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0860_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0860_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0867:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0867_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0867_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0868:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0868_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0868_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0870:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_0870_1
		 cwde
OP0_0870_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0870_2
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0870_2:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0878:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0878_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0878_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0879:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0879_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0879_1:
		 xor   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0880:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 31
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 or    edx,byte 40h	; Set Zero Flag
		 test  [R_D0+ebx*4],ECX
		 jz    short OP0_0880_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0880_1:
		 not   ecx
		 and   [R_D0+ebx*4],ECX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0890:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0890_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0890_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_0898:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_0898_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_0898_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_089f:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_089f_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_089f_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08a0_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08a0_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08a7:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08a7_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08a7_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08a8_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08a8_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_08b0_1
		 cwde
OP0_08b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08b0_2
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08b0_2:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08b8:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08b8_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08b8_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08b9:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08b9_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08b9_1:
		 not   ecx
		 and   AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08c0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 31
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 or    edx,byte 40h	; Set Zero Flag
		 test  [R_D0+ebx*4],ECX
		 jz    short OP0_08c0_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08c0_1:
		 or    [R_D0+ebx*4],ECX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08d0_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08d0_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08d8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08d8_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08d8_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08df:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08df_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08df_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08e0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08e0_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08e0_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08e7:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08e7_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08e7_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08e8_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08e8_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_08f0_1
		 cwde
OP0_08f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08f0_2
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08f0_2:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08f8:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08f8_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08f8_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_08f9:				;:
		 add   esi,byte 2

		 movzx ECX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx, byte 7
		 mov   eax,1
		 shl   eax,cl
		 mov   ecx,eax
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 or    edx,byte 40h	; Set Zero Flag
		 test  AL,CL
		 jz    short OP0_08f9_1
		 xor   edx,byte 40h	; Clear Zero Flag
OP0_08f9_1:
		 or    AL,CL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_A0+ECX*4],edi
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_A0+ECX*4],edi
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_41f0_1
		 cwde
OP0_41f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_A0+ECX*4],edi
		 sub   dword [_m68k_ICount],byte 26
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41f8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_A0+ECX*4],edi
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41f9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_A0+ECX*4],edi
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41fa:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_A0+ECX*4],edi
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41fb:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_41fb_1
		 cwde
OP0_41fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_A0+ECX*4],edi
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4850:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   ecx,[R_A7]	 ; Push onto Stack
		 sub   ecx,byte 4
		 mov   [R_A7],ecx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EDI
		 mov   ecx,ECX
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4868:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   ecx,[R_A7]	 ; Push onto Stack
		 sub   ecx,byte 4
		 mov   [R_A7],ecx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EDI
		 mov   ecx,ECX
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4870:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4870_1
		 cwde
OP0_4870_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   ecx,[R_A7]	 ; Push onto Stack
		 sub   ecx,byte 4
		 mov   [R_A7],ecx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EDI
		 mov   ecx,ECX
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 34
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4878:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   ecx,[R_A7]	 ; Push onto Stack
		 sub   ecx,byte 4
		 mov   [R_A7],ecx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EDI
		 mov   ecx,ECX
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4879:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   ecx,[R_A7]	 ; Push onto Stack
		 sub   ecx,byte 4
		 mov   [R_A7],ecx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EDI
		 mov   ecx,ECX
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 32
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_487a:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   ecx,[R_A7]	 ; Push onto Stack
		 sub   ecx,byte 4
		 mov   [R_A7],ecx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EDI
		 mov   ecx,ECX
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_487b:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_487b_1
		 cwde
OP0_487b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   ecx,[R_A7]	 ; Push onto Stack
		 sub   ecx,byte 4
		 mov   [R_A7],ecx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EDI
		 mov   ecx,ECX
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 30
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_40c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 mov   ah,byte [R_SR_H] 	; T, S & I

		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_40d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 mov   ah,byte [R_SR_H] 	; T, S & I

		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_40d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 mov   ah,byte [R_SR_H] 	; T, S & I

		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_40e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 mov   ah,byte [R_SR_H] 	; T, S & I

		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_40e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 mov   ah,byte [R_SR_H] 	; T, S & I

		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_40f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 mov   ah,byte [R_SR_H] 	; T, S & I

		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_40f0_1
		 cwde
OP0_40f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_40f8:				;:
		 add   esi,byte 2

		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 mov   ah,byte [R_SR_H] 	; T, S & I

		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_40f9:				;:
		 add   esi,byte 2

		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 mov   ah,byte [R_SR_H] 	; T, S & I

		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_42c0:				;:
		 add   esi,byte 2

		 mov   eax,[CPUversion]
		 test  eax,eax
		 jz    near ILLEGAL

		 and   ecx,byte 7
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_42d0:				;:
		 add   esi,byte 2

		 mov   eax,[CPUversion]
		 test  eax,eax
		 jz    near ILLEGAL

		 and   ecx,byte 7
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_42d8:				;:
		 add   esi,byte 2

		 mov   eax,[CPUversion]
		 test  eax,eax
		 jz    near ILLEGAL

		 and   ecx,byte 7
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_42e0:				;:
		 add   esi,byte 2

		 mov   eax,[CPUversion]
		 test  eax,eax
		 jz    near ILLEGAL

		 and   ecx,byte 7
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_42e8:				;:
		 add   esi,byte 2

		 mov   eax,[CPUversion]
		 test  eax,eax
		 jz    near ILLEGAL

		 and   ecx,byte 7
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_42f0:				;:
		 add   esi,byte 2

		 mov   eax,[CPUversion]
		 test  eax,eax
		 jz    near ILLEGAL

		 and   ecx,byte 7
		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_42f0_1
		 cwde
OP0_42f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_42f8:				;:
		 add   esi,byte 2

		 mov   eax,[CPUversion]
		 test  eax,eax
		 jz    near ILLEGAL

		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_42f9:				;:
		 add   esi,byte 2

		 mov   eax,[CPUversion]
		 test  eax,eax
		 jz    near ILLEGAL

		 mov   eax,edx
		 mov   ah,byte [R_XC]
		 mov   EBX,edx
		 and   EBX,byte 1
		 shr   eax,4
		 and   eax,byte 01Ch 		; X, N & Z

		 or    eax,EBX 				; C

		 mov   EBX,edx
		 shr   EBX,10
		 and   EBX,byte 2
		 or    eax,EBX				; O

		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_44f0_1
		 cwde
OP0_44f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44fa:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44fb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_44fb_1
		 cwde
OP0_44fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44fc:				;:
		 add   esi,byte 2

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46c0:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 je    near OP0_46c0_1

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_46c0_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_46c0_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_46c0_1:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46d0:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 je    near OP0_46d0_1

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_46d0_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_46d0_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_46d0_1:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46d8:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 je    near OP0_46d8_1

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_46d8_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_46d8_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_46d8_1:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46e0:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 je    near OP0_46e0_1

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_46e0_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_46e0_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_46e0_1:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46e8:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 je    near OP0_46e8_1

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_46e8_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_46e8_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_46e8_1:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46f0:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 je    near OP0_46f0_1

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_46f0_2
		 cwde
OP0_46f0_2:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_46f0_3

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_46f0_3:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_46f0_1:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46f8:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 je    near OP0_46f8_1

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_46f8_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_46f8_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_46f8_1:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46f9:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 je    near OP0_46f9_1

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_46f9_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_46f9_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_46f9_1:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46fa:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 je    near OP0_46fa_1

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_46fa_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_46fa_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_46fa_1:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46fb:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 je    near OP0_46fb_1

		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_46fb_2
		 cwde
OP0_46fb_2:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_46fb_3

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_46fb_3:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_46fb_1:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46fc:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 je    near OP0_46fc_1

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_46fc_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_46fc_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_46fc_1:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5000:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   [R_D0+ebx*4],CL
		 pushfd
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5088:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   [R_A0+ebx*4],ECX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5010:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5018:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_501f:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5020:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5027:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5028:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5030:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_5030_1
		 cwde
OP0_5030_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5038:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5039:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5040:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   [R_D0+ebx*4],CX
		 pushfd
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5050:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5058:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5060:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5068:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5070:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_5070_1
		 cwde
OP0_5070_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5078:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5079:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5080:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   [R_D0+ebx*4],ECX
		 pushfd
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5090:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5098:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_50b0_1
		 cwde
OP0_50b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50b8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50b9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 add   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   AL,byte 0ffh
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50c8:				;:
		 jmp   near OP0_50c8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_50c8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_50c8_1:
OP0_50c8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   AL,byte 0ffh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   AL,byte 0ffh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50df:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   AL,byte 0ffh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   AL,byte 0ffh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50e7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   AL,byte 0ffh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   AL,byte 0ffh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_50f0_1
		 cwde
OP0_50f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   AL,byte 0ffh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   AL,byte 0ffh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_50f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   AL,byte 0ffh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5100:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   [R_D0+ebx*4],CL
		 pushfd
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5188:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   [R_A0+ebx*4],ECX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5110:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5118:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_511f:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5120:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5127:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5128:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5130:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_5130_1
		 cwde
OP0_5130_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5138:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5139:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AL,CL
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5140:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   [R_D0+ebx*4],CX
		 pushfd
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5150:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5158:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5160:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5168:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5170:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_5170_1
		 cwde
OP0_5170_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5178:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5179:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   AX,CX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5180:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   [R_D0+ebx*4],ECX
		 pushfd
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5190:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5198:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_51b0_1
		 cwde
OP0_51b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51b8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51b9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 shr   ecx,9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 sub   EAX,ECX
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51c8:				;:
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_51c8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_51c8_1:
OP0_51c8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   EAX,0
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   EAX,0
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51df:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   EAX,0
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   EAX,0
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51e7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   EAX,0
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   EAX,0
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_51f0_1
		 cwde
OP0_51f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   EAX,0
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   EAX,0
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_51f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   EAX,0
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_52c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   ah,dl
		 sahf
		 seta  AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_52c8:				;:
		 mov   ah,dl
		 sahf
		 ja    near OP0_52c8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_52c8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_52c8_1:
OP0_52c8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_52d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   ah,dl
		 sahf
		 seta  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_52d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   ah,dl
		 sahf
		 seta  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_52df:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   ah,dl
		 sahf
		 seta  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_52e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   ah,dl
		 sahf
		 seta  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_52e7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   ah,dl
		 sahf
		 seta  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_52e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   ah,dl
		 sahf
		 seta  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_52f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_52f0_1
		 cwde
OP0_52f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   ah,dl
		 sahf
		 seta  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_52f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   ah,dl
		 sahf
		 seta  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_52f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   ah,dl
		 sahf
		 seta  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_53c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   ah,dl
		 sahf
		 setbe AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_53c8:				;:
		 mov   ah,dl
		 sahf
		 jbe   near OP0_53c8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_53c8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_53c8_1:
OP0_53c8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_53d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   ah,dl
		 sahf
		 setbe AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_53d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   ah,dl
		 sahf
		 setbe AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_53df:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   ah,dl
		 sahf
		 setbe AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_53e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   ah,dl
		 sahf
		 setbe AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_53e7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   ah,dl
		 sahf
		 setbe AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_53e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   ah,dl
		 sahf
		 setbe AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_53f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_53f0_1
		 cwde
OP0_53f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   ah,dl
		 sahf
		 setbe AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_53f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   ah,dl
		 sahf
		 setbe AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_53f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   ah,dl
		 sahf
		 setbe AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_54c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 test  dl,1		;Check Carry
		 setz  AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_54c8:				;:
		 test  dl,1H		;check carry
		 jz    near OP0_54c8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_54c8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_54c8_1:
OP0_54c8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_54d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 test  dl,1		;Check Carry
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_54d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 test  dl,1		;Check Carry
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_54df:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 test  dl,1		;Check Carry
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_54e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 test  dl,1		;Check Carry
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_54e7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 test  dl,1		;Check Carry
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_54e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 test  dl,1		;Check Carry
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_54f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_54f0_1
		 cwde
OP0_54f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 test  dl,1		;Check Carry
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_54f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 test  dl,1		;Check Carry
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_54f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 test  dl,1		;Check Carry
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_55c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 test  dl,1		;Check Carry
		 setnz AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_55c8:				;:
		 test  dl,1H		;check carry
		 jnz   near OP0_55c8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_55c8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_55c8_1:
OP0_55c8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_55d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 test  dl,1		;Check Carry
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_55d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 test  dl,1		;Check Carry
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_55df:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 test  dl,1		;Check Carry
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_55e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 test  dl,1		;Check Carry
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_55e7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 test  dl,1		;Check Carry
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_55e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 test  dl,1		;Check Carry
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_55f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_55f0_1
		 cwde
OP0_55f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 test  dl,1		;Check Carry
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_55f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 test  dl,1		;Check Carry
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_55f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 test  dl,1		;Check Carry
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_56c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 test  dl,40H		;Check Zero
		 setz  AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_56c8:				;:
		 test  dl,40H		;Check zero
		 jz    near OP0_56c8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_56c8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_56c8_1:
OP0_56c8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_56d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 test  dl,40H		;Check Zero
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_56d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 test  dl,40H		;Check Zero
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_56df:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 test  dl,40H		;Check Zero
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_56e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 test  dl,40H		;Check Zero
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_56e7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 test  dl,40H		;Check Zero
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_56e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 test  dl,40H		;Check Zero
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_56f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_56f0_1
		 cwde
OP0_56f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 test  dl,40H		;Check Zero
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_56f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 test  dl,40H		;Check Zero
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_56f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 test  dl,40H		;Check Zero
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_57c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 test  dl,40H		;Check Zero
		 setnz AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_57c8:				;:
		 test  dl,40H		;Check zero
		 jnz   near OP0_57c8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_57c8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_57c8_1:
OP0_57c8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_57d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 test  dl,40H		;Check Zero
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_57d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 test  dl,40H		;Check Zero
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_57df:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 test  dl,40H		;Check Zero
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_57e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 test  dl,40H		;Check Zero
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_57e7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 test  dl,40H		;Check Zero
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_57e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 test  dl,40H		;Check Zero
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_57f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_57f0_1
		 cwde
OP0_57f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 test  dl,40H		;Check Zero
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_57f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 test  dl,40H		;Check Zero
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_57f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 test  dl,40H		;Check Zero
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_58c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 test  dh,8H		;Check Overflow
		 setz  AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_58c8:				;:
		 test  dh,8H		;Check Overflow
		 jz    near OP0_58c8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_58c8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_58c8_1:
OP0_58c8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_58d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 test  dh,8H		;Check Overflow
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_58d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 test  dh,8H		;Check Overflow
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_58df:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 test  dh,8H		;Check Overflow
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_58e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 test  dh,8H		;Check Overflow
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_58e7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 test  dh,8H		;Check Overflow
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_58e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 test  dh,8H		;Check Overflow
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_58f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_58f0_1
		 cwde
OP0_58f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 test  dh,8H		;Check Overflow
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_58f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 test  dh,8H		;Check Overflow
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_58f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 test  dh,8H		;Check Overflow
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_59c0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 test  dh,8H		;Check Overflow
		 setnz AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_59c8:				;:
		 test  dh,8H		;Check Overflow
		 jnz   near OP0_59c8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_59c8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_59c8_1:
OP0_59c8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_59d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 test  dh,8H		;Check Overflow
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_59d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 test  dh,8H		;Check Overflow
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_59df:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 test  dh,8H		;Check Overflow
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_59e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 test  dh,8H		;Check Overflow
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_59e7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 test  dh,8H		;Check Overflow
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_59e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 test  dh,8H		;Check Overflow
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_59f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_59f0_1
		 cwde
OP0_59f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 test  dh,8H		;Check Overflow
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_59f8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 test  dh,8H		;Check Overflow
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_59f9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 test  dh,8H		;Check Overflow
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ac0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 test  dl,80H		;Check Sign
		 setz  AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ac8:				;:
		 test  dl,80H		;Check Sign
		 jz    near OP0_5ac8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_5ac8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_5ac8_1:
OP0_5ac8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ad0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 test  dl,80H		;Check Sign
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ad8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 test  dl,80H		;Check Sign
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5adf:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 test  dl,80H		;Check Sign
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ae0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 test  dl,80H		;Check Sign
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ae7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 test  dl,80H		;Check Sign
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ae8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 test  dl,80H		;Check Sign
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5af0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_5af0_1
		 cwde
OP0_5af0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 test  dl,80H		;Check Sign
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5af8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 test  dl,80H		;Check Sign
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5af9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 test  dl,80H		;Check Sign
		 setz  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5bc0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 test  dl,80H		;Check Sign
		 setnz AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5bc8:				;:
		 test  dl,80H		;Check Sign
		 jnz   near OP0_5bc8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_5bc8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_5bc8_1:
OP0_5bc8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5bd0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 test  dl,80H		;Check Sign
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5bd8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 test  dl,80H		;Check Sign
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5bdf:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 test  dl,80H		;Check Sign
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5be0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 test  dl,80H		;Check Sign
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5be7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 test  dl,80H		;Check Sign
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5be8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 test  dl,80H		;Check Sign
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5bf0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_5bf0_1
		 cwde
OP0_5bf0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 test  dl,80H		;Check Sign
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5bf8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 test  dl,80H		;Check Sign
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5bf9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 test  dl,80H		;Check Sign
		 setnz AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5cc0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 or    edx,200h
		 push  edx
		 popf
		 setge AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5cc8:				;:
		 or    edx,200h
		 push  edx
		 popf
		 jge   near OP0_5cc8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_5cc8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_5cc8_1:
OP0_5cc8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5cd0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 or    edx,200h
		 push  edx
		 popf
		 setge AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5cd8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 or    edx,200h
		 push  edx
		 popf
		 setge AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5cdf:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 or    edx,200h
		 push  edx
		 popf
		 setge AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ce0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 or    edx,200h
		 push  edx
		 popf
		 setge AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ce7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 or    edx,200h
		 push  edx
		 popf
		 setge AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ce8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 or    edx,200h
		 push  edx
		 popf
		 setge AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5cf0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_5cf0_1
		 cwde
OP0_5cf0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 or    edx,200h
		 push  edx
		 popf
		 setge AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5cf8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 or    edx,200h
		 push  edx
		 popf
		 setge AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5cf9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 or    edx,200h
		 push  edx
		 popf
		 setge AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5dc0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 or    edx,200h
		 push  edx
		 popf
		 setl  AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5dc8:				;:
		 or    edx,200h
		 push  edx
		 popf
		 jl    near OP0_5dc8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_5dc8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_5dc8_1:
OP0_5dc8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5dd0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 or    edx,200h
		 push  edx
		 popf
		 setl  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5dd8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 or    edx,200h
		 push  edx
		 popf
		 setl  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ddf:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 or    edx,200h
		 push  edx
		 popf
		 setl  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5de0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 or    edx,200h
		 push  edx
		 popf
		 setl  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5de7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 or    edx,200h
		 push  edx
		 popf
		 setl  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5de8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 or    edx,200h
		 push  edx
		 popf
		 setl  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5df0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_5df0_1
		 cwde
OP0_5df0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 or    edx,200h
		 push  edx
		 popf
		 setl  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5df8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 or    edx,200h
		 push  edx
		 popf
		 setl  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5df9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 or    edx,200h
		 push  edx
		 popf
		 setl  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ec0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 or    edx,200h
		 push  edx
		 popf
		 setg  AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ec8:				;:
		 or    edx,200h
		 push  edx
		 popf
		 jg    near OP0_5ec8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_5ec8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_5ec8_1:
OP0_5ec8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ed0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 or    edx,200h
		 push  edx
		 popf
		 setg  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ed8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 or    edx,200h
		 push  edx
		 popf
		 setg  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5edf:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 or    edx,200h
		 push  edx
		 popf
		 setg  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ee0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 or    edx,200h
		 push  edx
		 popf
		 setg  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ee7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 or    edx,200h
		 push  edx
		 popf
		 setg  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ee8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 or    edx,200h
		 push  edx
		 popf
		 setg  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ef0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_5ef0_1
		 cwde
OP0_5ef0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 or    edx,200h
		 push  edx
		 popf
		 setg  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ef8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 or    edx,200h
		 push  edx
		 popf
		 setg  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ef9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 or    edx,200h
		 push  edx
		 popf
		 setg  AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5fc0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 or    edx,200h
		 push  edx
		 popf
		 setle AL
		 neg   byte AL
		 mov   [R_D0+ECX*4],AL
		 and   eax,byte 2
		 add   eax,byte 4
		 sub   dword [_m68k_ICount],eax
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5fc8:				;:
		 or    edx,200h
		 push  edx
		 popf
		 jle   near OP0_5fc8_2
		 and   ecx,byte 7
		 mov   ax,[R_D0+ecx*4]
		 dec   ax
		 mov   [R_D0+ecx*4],ax
		 inc   ax		; Is it -1
		 jz    short OP0_5fc8_1
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_5fc8_1:
OP0_5fc8_2:
		 add   esi,byte 4
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5fd0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 or    edx,200h
		 push  edx
		 popf
		 setle AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5fd8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 or    edx,200h
		 push  edx
		 popf
		 setle AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5fdf:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 or    edx,200h
		 push  edx
		 popf
		 setle AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5fe0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 or    edx,200h
		 push  edx
		 popf
		 setle AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5fe7:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 or    edx,200h
		 push  edx
		 popf
		 setle AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5fe8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 or    edx,200h
		 push  edx
		 popf
		 setle AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ff0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_5ff0_1
		 cwde
OP0_5ff0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 or    edx,200h
		 push  edx
		 popf
		 setle AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ff8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 or    edx,200h
		 push  edx
		 popf
		 setle AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_5ff9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 or    edx,200h
		 push  edx
		 popf
		 setle AL
		 neg   byte AL
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6000:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06000
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06000:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06000_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6001:				;:
		 add   esi,byte 2

		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06005
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06005:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06005_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6100:				;:
		 add   esi,byte 2

		 movsx EBX,word [esi+ebp]
		 add   ebx,esi
		 add   esi,byte 2
		 mov   ECX,[R_A7]	 ; Push onto Stack
		 sub   ECX,byte 4
		 mov   [R_A7],ECX
		 mov   EAX,[FullPC]
		 and   EAX,0xff000000
		 or    EAX,ESI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,ECX
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 mov   esi,ebx
		 test  esi, dword 1
		 jz    near OP0_06103
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06103:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06103_Bank:
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6101:				;:
		 add   esi,byte 2

		 mov   EDI,[R_A7]	 ; Push onto Stack
		 sub   EDI,byte 4
		 mov   [R_A7],EDI
		 mov   EBX,[FullPC]
		 and   EBX,0xff000000
		 or    EBX,ESI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   edx,EBX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06105
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06105:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06105_Bank:
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6200:				;:
		 add   esi,byte 2

		 mov   ah,dl
		 sahf
		 ja    near OP0_6200_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6200_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06202
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06202:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06202_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6201:				;:
		 add   esi,byte 2

		 mov   ah,dl
		 sahf
		 ja    near OP0_6201_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6201_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06205
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06205:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06205_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6300:				;:
		 add   esi,byte 2

		 mov   ah,dl
		 sahf
		 jbe   near OP0_6300_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6300_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06302
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06302:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06302_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6301:				;:
		 add   esi,byte 2

		 mov   ah,dl
		 sahf
		 jbe   near OP0_6301_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6301_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06305
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06305:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06305_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6400:				;:
		 add   esi,byte 2

		 test  dl,1H		;check carry
		 jz    near OP0_6400_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6400_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06402
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06402:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06402_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6401:				;:
		 add   esi,byte 2

		 test  dl,1H		;check carry
		 jz    near OP0_6401_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6401_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06405
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06405:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06405_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6500:				;:
		 add   esi,byte 2

		 test  dl,1H		;check carry
		 jnz   near OP0_6500_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6500_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06502
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06502:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06502_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6501:				;:
		 add   esi,byte 2

		 test  dl,1H		;check carry
		 jnz   near OP0_6501_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6501_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06505
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06505:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06505_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6600:				;:
		 add   esi,byte 2

		 test  dl,40H		;Check zero
		 jz    near OP0_6600_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6600_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06602
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06602:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06602_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6601:				;:
		 add   esi,byte 2

		 test  dl,40H		;Check zero
		 jz    near OP0_6601_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6601_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06605
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06605:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06605_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6700:				;:
		 add   esi,byte 2

		 test  dl,40H		;Check zero
		 jnz   near OP0_6700_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6700_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06702
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06702:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06702_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6701:				;:
		 add   esi,byte 2

		 test  dl,40H		;Check zero
		 jnz   near OP0_6701_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6701_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06705
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06705:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06705_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6800:				;:
		 add   esi,byte 2

		 test  dh,8H		;Check Overflow
		 jz    near OP0_6800_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6800_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06802
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06802:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06802_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6801:				;:
		 add   esi,byte 2

		 test  dh,8H		;Check Overflow
		 jz    near OP0_6801_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6801_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06805
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06805:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06805_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6900:				;:
		 add   esi,byte 2

		 test  dh,8H		;Check Overflow
		 jnz   near OP0_6900_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6900_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06902
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06902:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06902_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6901:				;:
		 add   esi,byte 2

		 test  dh,8H		;Check Overflow
		 jnz   near OP0_6901_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6901_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06905
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06905:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06905_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6a00:				;:
		 add   esi,byte 2

		 test  dl,80H		;Check Sign
		 jz    near OP0_6a00_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6a00_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06a02
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06a02:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06a02_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6a01:				;:
		 add   esi,byte 2

		 test  dl,80H		;Check Sign
		 jz    near OP0_6a01_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6a01_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06a05
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06a05:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06a05_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6b00:				;:
		 add   esi,byte 2

		 test  dl,80H		;Check Sign
		 jnz   near OP0_6b00_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6b00_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06b02
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06b02:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06b02_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6b01:				;:
		 add   esi,byte 2

		 test  dl,80H		;Check Sign
		 jnz   near OP0_6b01_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6b01_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06b05
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06b05:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06b05_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6c00:				;:
		 add   esi,byte 2

		 or    edx,200h
		 push  edx
		 popf
		 jge   near OP0_6c00_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6c00_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06c02
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06c02:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06c02_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6c01:				;:
		 add   esi,byte 2

		 or    edx,200h
		 push  edx
		 popf
		 jge   near OP0_6c01_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6c01_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06c05
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06c05:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06c05_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6d00:				;:
		 add   esi,byte 2

		 or    edx,200h
		 push  edx
		 popf
		 jl    near OP0_6d00_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6d00_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06d02
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06d02:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06d02_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6d01:				;:
		 add   esi,byte 2

		 or    edx,200h
		 push  edx
		 popf
		 jl    near OP0_6d01_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6d01_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06d05
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06d05:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06d05_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6e00:				;:
		 add   esi,byte 2

		 or    edx,200h
		 push  edx
		 popf
		 jg    near OP0_6e00_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6e00_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06e02
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06e02:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06e02_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6e01:				;:
		 add   esi,byte 2

		 or    edx,200h
		 push  edx
		 popf
		 jg    near OP0_6e01_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6e01_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06e05
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06e05:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06e05_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6f00:				;:
		 add   esi,byte 2

		 or    edx,200h
		 push  edx
		 popf
		 jle   near OP0_6f00_1
		 add   esi,byte 2
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6f00_1:
		 movsx EAX,word [esi+ebp]
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06f02
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06f02:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06f02_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6f01:				;:
		 add   esi,byte 2

		 or    edx,200h
		 push  edx
		 popf
		 jle   near OP0_6f01_1
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_6f01_1:
		 movsx eax,cl               ; Sign Extend displacement
		 add   esi,eax
		 test  esi, dword 1
		 jz    near OP0_06f05
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_06f05:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_06f05_Bank:
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_7000:				;:
		 add   esi,byte 2

		 movsx eax,cl
		 shr   ecx,9
		 and   ecx,byte 7
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8100:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EBX,[R_D0+EBX*4]
		 mov   EAX,[R_D0+ECX*4]
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 mov   ebx,edx
		 setc  dl
		 jnz   short OP0_8100_1

		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_8100_1:
		 mov   bl,dl
		 and   bl,1
		 shl   bl,7
		 and   dl,7Fh
		 or    dl,bl
		 mov   [R_XC],edx
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8108:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 mov   ebx,edx
		 setc  dl
		 jnz   short OP0_8108_1

		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_8108_1:
		 mov   bl,dl
		 and   bl,1
		 shl   bl,7
		 and   dl,7Fh
		 or    dl,bl
		 mov   [R_XC],edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_810f:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 mov   ebx,edx
		 setc  dl
		 jnz   short OP0_810f_1

		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_810f_1:
		 mov   bl,dl
		 and   bl,1
		 shl   bl,7
		 and   dl,7Fh
		 or    dl,bl
		 mov   [R_XC],edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8f08:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   EBX,EAX
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 mov   ebx,edx
		 setc  dl
		 jnz   short OP0_8f08_1

		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_8f08_1:
		 mov   bl,dl
		 and   bl,1
		 shl   bl,7
		 and   dl,7Fh
		 or    dl,bl
		 mov   [R_XC],edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8f0f:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   EBX,EAX
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 mov   ebx,edx
		 setc  dl
		 jnz   short OP0_8f0f_1

		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_8f0f_1:
		 mov   bl,dl
		 and   bl,1
		 shl   bl,7
		 and   dl,7Fh
		 or    dl,bl
		 mov   [R_XC],edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c100:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EBX,[R_D0+EBX*4]
		 mov   EAX,[R_D0+ECX*4]
		 bt    dword [R_XC],0
		 adc   al,bl
		 daa
		 mov   ebx,edx
		 setc  dl
		 jnz   short OP0_c100_1

		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_c100_1:
		 mov   bl,dl
		 and   bl,1
		 shl   bl,7
		 and   dl,7Fh
		 or    dl,bl
		 mov   [R_XC],edx
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c108:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 bt    dword [R_XC],0
		 adc   al,bl
		 daa
		 mov   ebx,edx
		 setc  dl
		 jnz   short OP0_c108_1

		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_c108_1:
		 mov   bl,dl
		 and   bl,1
		 shl   bl,7
		 and   dl,7Fh
		 or    dl,bl
		 mov   [R_XC],edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c10f:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 bt    dword [R_XC],0
		 adc   al,bl
		 daa
		 mov   ebx,edx
		 setc  dl
		 jnz   short OP0_c10f_1

		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_c10f_1:
		 mov   bl,dl
		 and   bl,1
		 shl   bl,7
		 and   dl,7Fh
		 or    dl,bl
		 mov   [R_XC],edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_cf08:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   EBX,EAX
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 bt    dword [R_XC],0
		 adc   al,bl
		 daa
		 mov   ebx,edx
		 setc  dl
		 jnz   short OP0_cf08_1

		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_cf08_1:
		 mov   bl,dl
		 and   bl,1
		 shl   bl,7
		 and   dl,7Fh
		 or    dl,bl
		 mov   [R_XC],edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_cf0f:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   EBX,EAX
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 bt    dword [R_XC],0
		 adc   al,bl
		 daa
		 mov   ebx,edx
		 setc  dl
		 jnz   short OP0_cf0f_1

		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_cf0f_1:
		 mov   bl,dl
		 and   bl,1
		 shl   bl,7
		 and   dl,7Fh
		 or    dl,bl
		 mov   [R_XC],edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8000:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 or    [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8010:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8018:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_801f:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8020:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8027:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8028:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8030:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_8030_1
		 cwde
OP0_8030_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8038:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8039:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_803a:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_803b:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_803b_1
		 cwde
OP0_803b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_803c:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 or    [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8040:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 or    [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8050:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8058:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8060:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8068:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8070:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_8070_1
		 cwde
OP0_8070_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8078:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8079:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_807a:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_807b:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_807b_1
		 cwde
OP0_807b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_807c:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 or    [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8080:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 or    [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8090:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8098:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_80b0_1
		 cwde
OP0_80b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80b8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80b9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80ba:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80bb:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_80bb_1
		 cwde
OP0_80bb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 or    [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80bc:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 or    [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8110:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8118:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_811f:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8120:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8127:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8128:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8130:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_8130_1
		 cwde
OP0_8130_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8138:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8139:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 or    AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8150:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8158:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8160:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8168:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8170:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_8170_1
		 cwde
OP0_8170_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8178:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8179:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 or    AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8190:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_8198:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_81b0_1
		 cwde
OP0_81b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81b8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81b9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 or    EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9000:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 sub   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9010:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9018:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_901f:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9020:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9027:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9028:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9030:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_9030_1
		 cwde
OP0_9030_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9038:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9039:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_903a:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_903b:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_903b_1
		 cwde
OP0_903b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_903c:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 sub   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9040:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 sub   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9050:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9058:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9060:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9068:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9070:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_9070_1
		 cwde
OP0_9070_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9078:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9079:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_907a:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_907b:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_907b_1
		 cwde
OP0_907b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_907c:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 sub   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9080:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 sub   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9090:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9098:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_90b0_1
		 cwde
OP0_90b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90b8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90b9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90ba:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90bb:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_90bb_1
		 cwde
OP0_90bb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 sub   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90bc:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 sub   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9110:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9118:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_911f:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9120:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9127:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9128:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9130:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_9130_1
		 cwde
OP0_9130_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9138:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9139:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 sub   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9150:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9158:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9160:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9168:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9170:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_9170_1
		 cwde
OP0_9170_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9178:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9179:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sub   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9190:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9198:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_91b0_1
		 cwde
OP0_91b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91b8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91b9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 sub   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90c0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 cwde
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90d8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90e0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_90f0_1
		 cwde
OP0_90f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90f8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90f9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90fa:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90fb:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_90fb_1
		 cwde
OP0_90fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_90fc:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 cwde
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91c0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91d8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91e0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_91f0_1
		 cwde
OP0_91f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91f8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91f9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91fa:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91fb:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_91fb_1
		 cwde
OP0_91fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_91fc:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 sub   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b000:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 cmp   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b010:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b018:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b01f:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b020:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b027:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b028:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b030:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_b030_1
		 cwde
OP0_b030_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b038:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b039:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b03a:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b03b:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_b03b_1
		 cwde
OP0_b03b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b03c:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 cmp   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b040:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 cmp   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b050:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b058:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b060:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b068:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b070:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_b070_1
		 cwde
OP0_b070_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b078:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b079:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b07a:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b07b:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_b07b_1
		 cwde
OP0_b07b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b07c:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 cmp   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b080:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 cmp   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b090:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b098:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_b0b0_1
		 cwde
OP0_b0b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0b8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0b9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0ba:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0bb:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_b0bb_1
		 cwde
OP0_b0bb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 cmp   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0bc:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 cmp   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0c0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 cwde
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0d8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0e0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_b0f0_1
		 cwde
OP0_b0f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0f8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0f9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0fa:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0fb:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_b0fb_1
		 cwde
OP0_b0fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b0fc:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 cwde
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1c0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1d8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1e0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_b1f0_1
		 cwde
OP0_b1f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1f8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1f9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1fa:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1fb:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_b1fb_1
		 cwde
OP0_b1fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1fc:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 cmp   [R_A0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0c0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 cwde
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0d8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0e0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_d0f0_1
		 cwde
OP0_d0f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0f8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0f9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0fa:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0fb:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_d0fb_1
		 cwde
OP0_d0fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0fc:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 cwde
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1c0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1d8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1e0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_d1f0_1
		 cwde
OP0_d1f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1f8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1f9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1fa:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1fb:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_d1fb_1
		 cwde
OP0_d1fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1fc:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 add   [R_A0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b100:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 xor   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_D0+EBX*4],AL
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b110:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b118:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b11f:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b120:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b127:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b128:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b130:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_b130_1
		 cwde
OP0_b130_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b138:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b139:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 xor   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b140:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 xor   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_D0+EBX*4],AX
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b150:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b158:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b160:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b168:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b170:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_b170_1
		 cwde
OP0_b170_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b178:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b179:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 xor   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b180:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 xor   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_D0+EBX*4],EAX
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b190:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b198:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_b1b0_1
		 cwde
OP0_b1b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1b8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b1b9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 xor   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c000:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 and   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c010:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c018:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c01f:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c020:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c027:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c028:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c030:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_c030_1
		 cwde
OP0_c030_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c038:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c039:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c03a:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c03b:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_c03b_1
		 cwde
OP0_c03b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c03c:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 and   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c040:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 and   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c050:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c058:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c060:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c068:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c070:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_c070_1
		 cwde
OP0_c070_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c078:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c079:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c07a:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c07b:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_c07b_1
		 cwde
OP0_c07b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c07c:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 and   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c080:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 and   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c090:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c098:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_c0b0_1
		 cwde
OP0_c0b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0b8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0b9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0ba:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0bb:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_c0bb_1
		 cwde
OP0_c0bb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 and   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0bc:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 and   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c110:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c118:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c11f:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c120:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c127:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c128:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c130:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_c130_1
		 cwde
OP0_c130_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c138:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c139:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 and   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c150:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c158:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c160:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c168:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c170:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_c170_1
		 cwde
OP0_c170_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c178:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c179:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 and   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c190:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c198:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_c1b0_1
		 cwde
OP0_c1b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1b8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1b9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 and   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d000:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 add   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d010:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d018:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d01f:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d020:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d027:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d028:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d030:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_d030_1
		 cwde
OP0_d030_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d038:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d039:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d03a:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d03b:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_d03b_1
		 cwde
OP0_d03b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+32]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d03c:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 add   [R_D0+ECX*4],AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d040:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 add   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d050:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d058:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d060:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d068:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d070:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_d070_1
		 cwde
OP0_d070_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d078:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d079:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d07a:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d07b:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_d07b_1
		 cwde
OP0_d07b_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d07c:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 add   [R_D0+ECX*4],AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d080:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 15
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,[R_D0+EBX*4]
		 add   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d090:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d098:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_d0b0_1
		 cwde
OP0_d0b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0b8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0b9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0ba:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0bb:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_d0bb_1
		 cwde
OP0_d0bb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 add   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d0bc:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EAX,dword [esi+ebp]
		 rol   EAX,16
		 add   esi,byte 4
		 add   [R_D0+ECX*4],EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d110:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d118:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d11f:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d120:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d127:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d128:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d130:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_d130_1
		 cwde
OP0_d130_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d138:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d139:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 add   AL,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d150:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d158:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d160:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d168:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d170:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_d170_1
		 cwde
OP0_d170_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d178:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d179:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 add   AX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d190:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d198:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_d1b0_1
		 cwde
OP0_d1b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1b8:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d1b9:				;:
		 add   esi,byte 2

		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 add   EAX,[R_D0+ECX*4]
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 sub   dword [_m68k_ICount],byte 28
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9100:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EBX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 sbb   [R_D0+ecx*4],BL
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_9100_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_9100_1:
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9108:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 sbb   AL,BL
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_9108_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_9108_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_910f:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 sbb   AL,BL
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_910f_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_910f_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9140:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EBX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 sbb   [R_D0+ecx*4],BX
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_9140_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_9140_1:
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9148:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 sbb   AX,BX
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_9148_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_9148_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9180:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EBX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 sbb   [R_D0+ecx*4],EBX
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_9180_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_9180_1:
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9188:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 sbb   EAX,EBX
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_9188_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_9188_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 30
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9f08:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EBX,EAX
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 sbb   AL,BL
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_9f08_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_9f08_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_9f0f:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EBX,EAX
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 sbb   AL,BL
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_9f0f_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_9f0f_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d100:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EBX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 adc   [R_D0+ecx*4],BL
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_d100_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_d100_1:
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d108:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 adc   AL,BL
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_d108_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_d108_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d10f:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 adc   AL,BL
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_d10f_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_d10f_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d140:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EBX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 adc   [R_D0+ecx*4],BX
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_d140_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_d140_1:
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d148:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 adc   AX,BX
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_d148_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_d148_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d180:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EBX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 adc   [R_D0+ecx*4],EBX
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_d180_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_d180_1:
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_d188:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 adc   EAX,EBX
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_d188_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_d188_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 30
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_df08:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 dec   EDI
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EBX,EAX
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 adc   AL,BL
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_df08_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_df08_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_df0f:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EBX,EAX
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 adc   AL,BL
		 mov   ebx,edx
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_df0f_1

		 and   dl,0BFh       ; Remove Z
		 and   bl,40h        ; Mask out Old Z
		 or    dl,bl         ; Copy across

OP0_df0f_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80c0:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],133
		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EAX,[R_D0+EBX*4]
		 test  ax,ax
		 je    near OP0_80c0_1_ZERO		;do div by zero trap
		 movzx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 mov   EDX,0
		 div   ebx
		 test  eax, 0FFFF0000H
		 jnz   short OP0_80c0_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80c0_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80c0_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 95
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80d0:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],137
		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_80d0_1_ZERO		;do div by zero trap
		 movzx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 mov   EDX,0
		 div   ebx
		 test  eax, 0FFFF0000H
		 jnz   short OP0_80d0_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80d0_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80d0_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 95
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80d8:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],137
		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_80d8_1_ZERO		;do div by zero trap
		 movzx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 mov   EDX,0
		 div   ebx
		 test  eax, 0FFFF0000H
		 jnz   short OP0_80d8_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80d8_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80d8_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 95
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80e0:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],139
		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_80e0_1_ZERO		;do div by zero trap
		 movzx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 mov   EDX,0
		 div   ebx
		 test  eax, 0FFFF0000H
		 jnz   short OP0_80e0_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80e0_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80e0_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 95
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80e8:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],141
		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_80e8_1_ZERO		;do div by zero trap
		 movzx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 mov   EDX,0
		 div   ebx
		 test  eax, 0FFFF0000H
		 jnz   short OP0_80e8_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80e8_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80e8_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 95
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80f0:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],145
		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_80f0_2
		 cwde
OP0_80f0_2:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_80f0_1_ZERO		;do div by zero trap
		 movzx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 mov   EDX,0
		 div   ebx
		 test  eax, 0FFFF0000H
		 jnz   short OP0_80f0_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80f0_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80f0_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 95
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80f8:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],141
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_80f8_1_ZERO		;do div by zero trap
		 movzx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 mov   EDX,0
		 div   ebx
		 test  eax, 0FFFF0000H
		 jnz   short OP0_80f8_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80f8_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80f8_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 95
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80f9:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],145
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_80f9_1_ZERO		;do div by zero trap
		 movzx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 mov   EDX,0
		 div   ebx
		 test  eax, 0FFFF0000H
		 jnz   short OP0_80f9_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80f9_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80f9_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 95
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80fa:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],141
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_80fa_1_ZERO		;do div by zero trap
		 movzx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 mov   EDX,0
		 div   ebx
		 test  eax, 0FFFF0000H
		 jnz   short OP0_80fa_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80fa_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80fa_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 95
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80fb:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],143
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_80fb_2
		 cwde
OP0_80fb_2:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_80fb_1_ZERO		;do div by zero trap
		 movzx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 mov   EDX,0
		 div   ebx
		 test  eax, 0FFFF0000H
		 jnz   short OP0_80fb_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80fb_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80fb_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 95
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80fc:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],137
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  ax,ax
		 je    near OP0_80fc_1_ZERO		;do div by zero trap
		 movzx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 mov   EDX,0
		 div   ebx
		 test  eax, 0FFFF0000H
		 jnz   short OP0_80fc_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80fc_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_80fc_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 95
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81c0:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],150
		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EAX,[R_D0+EBX*4]
		 test  ax,ax
		 je    near OP0_81c0_1_ZERO		;do div by zero trap
		 movsx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 cdq
		 idiv  ebx
		 movsx ebx,ax
		 cmp   eax,ebx
		 jne   short OP0_81c0_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81c0_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81c0_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 112
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81d0:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],154
		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_81d0_1_ZERO		;do div by zero trap
		 movsx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 cdq
		 idiv  ebx
		 movsx ebx,ax
		 cmp   eax,ebx
		 jne   short OP0_81d0_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81d0_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81d0_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 112
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81d8:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],154
		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_81d8_1_ZERO		;do div by zero trap
		 movsx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 cdq
		 idiv  ebx
		 movsx ebx,ax
		 cmp   eax,ebx
		 jne   short OP0_81d8_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81d8_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81d8_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 112
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81e0:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],156
		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_81e0_1_ZERO		;do div by zero trap
		 movsx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 cdq
		 idiv  ebx
		 movsx ebx,ax
		 cmp   eax,ebx
		 jne   short OP0_81e0_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81e0_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81e0_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 112
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81e8:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],158
		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_81e8_1_ZERO		;do div by zero trap
		 movsx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 cdq
		 idiv  ebx
		 movsx ebx,ax
		 cmp   eax,ebx
		 jne   short OP0_81e8_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81e8_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81e8_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 112
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81f0:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],162
		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_81f0_2
		 cwde
OP0_81f0_2:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_81f0_1_ZERO		;do div by zero trap
		 movsx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 cdq
		 idiv  ebx
		 movsx ebx,ax
		 cmp   eax,ebx
		 jne   short OP0_81f0_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81f0_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81f0_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 112
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81f8:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],158
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_81f8_1_ZERO		;do div by zero trap
		 movsx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 cdq
		 idiv  ebx
		 movsx ebx,ax
		 cmp   eax,ebx
		 jne   short OP0_81f8_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81f8_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81f8_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 112
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81f9:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],162
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_81f9_1_ZERO		;do div by zero trap
		 movsx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 cdq
		 idiv  ebx
		 movsx ebx,ax
		 cmp   eax,ebx
		 jne   short OP0_81f9_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81f9_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81f9_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 112
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81fa:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],158
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_81fa_1_ZERO		;do div by zero trap
		 movsx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 cdq
		 idiv  ebx
		 movsx ebx,ax
		 cmp   eax,ebx
		 jne   short OP0_81fa_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81fa_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81fa_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 112
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81fb:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],160
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_81fb_2
		 cwde
OP0_81fb_2:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 test  ax,ax
		 je    near OP0_81fb_1_ZERO		;do div by zero trap
		 movsx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 cdq
		 idiv  ebx
		 movsx ebx,ax
		 cmp   eax,ebx
		 jne   short OP0_81fb_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81fb_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81fb_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 112
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81fc:				;:
		 add   esi,byte 2

		 and   edx,byte -2
		 mov   [R_CCR],edx
		 sub   dword [_m68k_ICount],154
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  ax,ax
		 je    near OP0_81fc_1_ZERO		;do div by zero trap
		 movsx ebx,ax
		 mov   EAX,[R_D0+ECX*4]
		 cdq
		 idiv  ebx
		 movsx ebx,ax
		 cmp   eax,ebx
		 jne   short OP0_81fc_1_OVER
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  DX,DX
		 pushfd
		 pop   EDX
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81fc_1_OVER:
		 mov   edx,[R_CCR]
		 or    edx,0x0800		;V flag
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_81fc_1_ZERO:		 ;Do divide by zero trap
		 add   dword [_m68k_ICount],byte 112
		 mov   al,5
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4840:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   eax, dword [R_D0+ECX*4]
		 ror   eax, 16
		 test  eax,eax
		 mov   dword [R_D0+ECX*4],eax
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4000:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AL,byte 0
		 neg   AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4000_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4000_1:
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4010:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AL,byte 0
		 neg   AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4010_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4010_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4018:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AL,byte 0
		 neg   AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4018_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4018_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_401f:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AL,byte 0
		 neg   AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_401f_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_401f_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4020:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AL,byte 0
		 neg   AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4020_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4020_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4027:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AL,byte 0
		 neg   AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4027_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4027_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4028:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AL,byte 0
		 neg   AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4028_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4028_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4030:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4030_1
		 cwde
OP0_4030_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AL,byte 0
		 neg   AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4030_2

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4030_2:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4038:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AL,byte 0
		 neg   AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4038_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4038_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4039:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AL,byte 0
		 neg   AL
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4039_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4039_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4040:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AX,byte 0
		 neg   AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4040_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4040_1:
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4050:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AX,byte 0
		 neg   AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4050_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4050_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4058:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AX,byte 0
		 neg   AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4058_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4058_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4060:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AX,byte 0
		 neg   AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4060_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4060_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4068:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AX,byte 0
		 neg   AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4068_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4068_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4070:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4070_1
		 cwde
OP0_4070_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AX,byte 0
		 neg   AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4070_2

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4070_2:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4078:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AX,byte 0
		 neg   AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4078_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4078_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4079:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   AX,byte 0
		 neg   AX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4079_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4079_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4080:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   EAX,byte 0
		 neg   EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4080_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4080_1:
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4090:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   EAX,byte 0
		 neg   EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4090_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4090_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4098:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   EAX,byte 0
		 neg   EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_4098_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_4098_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_40a0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   EAX,byte 0
		 neg   EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_40a0_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_40a0_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_40a8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   EAX,byte 0
		 neg   EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_40a8_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_40a8_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_40b0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_40b0_1
		 cwde
OP0_40b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   EAX,byte 0
		 neg   EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_40b0_2

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_40b0_2:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_40b8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   EAX,byte 0
		 neg   EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_40b8_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_40b8_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_40b9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   ebx,edx
		 bt    dword [R_XC],0
		 adc   EAX,byte 0
		 neg   EAX
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 jnz   short OP0_40b9_1

		 and   edx,byte -65  ; Remove Z
		 and   ebx,byte 40h  ; Mask out Old Z
		 or    edx,ebx       ; Copy across

OP0_40b9_1:
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4200:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 mov   [R_D0+ECX*4],AL
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4210:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4218:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_421f:				;:
		 add   esi,byte 2

		 mov   EAX,0
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4220:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4227:				;:
		 add   esi,byte 2

		 mov   EAX,0
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4228:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4230:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4230_1
		 cwde
OP0_4230_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4238:				;:
		 add   esi,byte 2

		 mov   EAX,0
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4239:				;:
		 add   esi,byte 2

		 mov   EAX,0
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4240:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 mov   [R_D0+ECX*4],AX
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4250:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4258:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4260:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4268:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4270:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4270_1
		 cwde
OP0_4270_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4278:				;:
		 add   esi,byte 2

		 mov   EAX,0
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4279:				;:
		 add   esi,byte 2

		 mov   EAX,0
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4280:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 mov   [R_D0+ECX*4],EAX
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4290:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4298:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_42a0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_42a8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 push  EAX
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_42b0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,0
		 push  EAX
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_42b0_1
		 cwde
OP0_42b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_42b8:				;:
		 add   esi,byte 2

		 mov   EAX,0
		 push  EAX
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_42b9:				;:
		 add   esi,byte 2

		 mov   EAX,0
		 push  EAX
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 pop   EAX
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   edx,40H
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4400:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 neg   AL
		 pushfd
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4410:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 neg   AL
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4418:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 neg   AL
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_441f:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 neg   AL
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4420:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 neg   AL
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4427:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 neg   AL
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4428:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 neg   AL
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4430:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4430_1
		 cwde
OP0_4430_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 neg   AL
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4438:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 neg   AL
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4439:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 neg   AL
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4440:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 neg   AX
		 pushfd
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4450:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 neg   AX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4458:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 neg   AX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4460:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 neg   AX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4468:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 neg   AX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4470:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4470_1
		 cwde
OP0_4470_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 neg   AX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4478:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 neg   AX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4479:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 neg   AX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4480:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 neg   EAX
		 pushfd
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 6
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4490:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 neg   EAX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4498:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 neg   EAX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44a0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 neg   EAX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44a8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 neg   EAX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44b0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_44b0_1
		 cwde
OP0_44b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 neg   EAX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44b8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 neg   EAX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_44b9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 neg   EAX
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4600:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 xor   AL,-1
		 pushfd
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4610:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 xor   AL,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4618:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 xor   AL,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_461f:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 xor   AL,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4620:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 xor   AL,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4627:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 xor   AL,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4628:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 xor   AL,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4630:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4630_1
		 cwde
OP0_4630_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 xor   AL,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4638:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 xor   AL,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4639:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 xor   AL,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4640:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 xor   AX,-1
		 pushfd
		 mov   [R_D0+ECX*4],AX
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4650:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 xor   AX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4658:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 xor   AX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4660:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 xor   AX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 10
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4668:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 xor   AX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4670:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4670_1
		 cwde
OP0_4670_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 xor   AX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4678:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 xor   AX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4679:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 xor   AX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4680:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 xor   EAX,-1
		 pushfd
		 mov   [R_D0+ECX*4],EAX
		 sub   dword [_m68k_ICount],byte 6
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4690:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 xor   EAX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4698:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 xor   EAX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46a0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 xor   EAX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46a8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 xor   EAX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46b0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_46b0_1
		 cwde
OP0_46b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 xor   EAX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46b8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 xor   EAX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_46b9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 xor   EAX,-1
		 pushfd
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e60:				;
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 jz    short OP0_4e60_Trap
		 and   ecx,7
		 mov   eax,[R_A0+ECX*4]
		 mov   [R_USP],eax
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_4e60_Trap:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e68:				;
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 jz    short OP0_4e68_Trap
		 and   ecx,7
		 mov   eax,[R_USP]
		 mov   [R_A0+ECX*4],eax
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_4e68_Trap:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4180:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 shr   ebx,byte 9
		 and   ebx,byte 7
		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 movsx ebx,word [R_D0+EBX*4]
		 movsx eax,ax
		 test  ebx,ebx
		 jl    near OP0_4180_Trap_minus
		 cmp   ebx,eax
		 jg    near OP0_4180_Trap_over
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4180_Trap_minus:
		 or    edx,0x0080
		 jmp   short OP0_4180_Trap_Exception
		 ALIGN 4

OP0_4180_Trap_over:
		 and   edx,0x007f
OP0_4180_Trap_Exception:
		 mov   al,6
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4190:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 shr   ebx,byte 9
		 and   ebx,byte 7
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 movsx ebx,word [R_D0+EBX*4]
		 movsx eax,ax
		 test  ebx,ebx
		 jl    near OP0_4190_Trap_minus
		 cmp   ebx,eax
		 jg    near OP0_4190_Trap_over
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4190_Trap_minus:
		 or    edx,0x0080
		 jmp   short OP0_4190_Trap_Exception
		 ALIGN 4

OP0_4190_Trap_over:
		 and   edx,0x007f
OP0_4190_Trap_Exception:
		 mov   al,6
		 call  Exception

		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4198:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 shr   ebx,byte 9
		 and   ebx,byte 7
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 movsx ebx,word [R_D0+EBX*4]
		 movsx eax,ax
		 test  ebx,ebx
		 jl    near OP0_4198_Trap_minus
		 cmp   ebx,eax
		 jg    near OP0_4198_Trap_over
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4198_Trap_minus:
		 or    edx,0x0080
		 jmp   short OP0_4198_Trap_Exception
		 ALIGN 4

OP0_4198_Trap_over:
		 and   edx,0x007f
OP0_4198_Trap_Exception:
		 mov   al,6
		 call  Exception

		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 shr   ebx,byte 9
		 and   ebx,byte 7
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 movsx ebx,word [R_D0+EBX*4]
		 movsx eax,ax
		 test  ebx,ebx
		 jl    near OP0_41a0_Trap_minus
		 cmp   ebx,eax
		 jg    near OP0_41a0_Trap_over
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41a0_Trap_minus:
		 or    edx,0x0080
		 jmp   short OP0_41a0_Trap_Exception
		 ALIGN 4

OP0_41a0_Trap_over:
		 and   edx,0x007f
OP0_41a0_Trap_Exception:
		 mov   al,6
		 call  Exception

		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 shr   ebx,byte 9
		 and   ebx,byte 7
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 movsx ebx,word [R_D0+EBX*4]
		 movsx eax,ax
		 test  ebx,ebx
		 jl    near OP0_41a8_Trap_minus
		 cmp   ebx,eax
		 jg    near OP0_41a8_Trap_over
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41a8_Trap_minus:
		 or    edx,0x0080
		 jmp   short OP0_41a8_Trap_Exception
		 ALIGN 4

OP0_41a8_Trap_over:
		 and   edx,0x007f
OP0_41a8_Trap_Exception:
		 mov   al,6
		 call  Exception

		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 shr   ebx,byte 9
		 and   ebx,byte 7
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_41b0_1
		 cwde
OP0_41b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 movsx ebx,word [R_D0+EBX*4]
		 movsx eax,ax
		 test  ebx,ebx
		 jl    near OP0_41b0_Trap_minus
		 cmp   ebx,eax
		 jg    near OP0_41b0_Trap_over
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41b0_Trap_minus:
		 or    edx,0x0080
		 jmp   short OP0_41b0_Trap_Exception
		 ALIGN 4

OP0_41b0_Trap_over:
		 and   edx,0x007f
OP0_41b0_Trap_Exception:
		 mov   al,6
		 call  Exception

		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41b8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 shr   ebx,byte 9
		 and   ebx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 movsx ebx,word [R_D0+EBX*4]
		 movsx eax,ax
		 test  ebx,ebx
		 jl    near OP0_41b8_Trap_minus
		 cmp   ebx,eax
		 jg    near OP0_41b8_Trap_over
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41b8_Trap_minus:
		 or    edx,0x0080
		 jmp   short OP0_41b8_Trap_Exception
		 ALIGN 4

OP0_41b8_Trap_over:
		 and   edx,0x007f
OP0_41b8_Trap_Exception:
		 mov   al,6
		 call  Exception

		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41b9:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 shr   ebx,byte 9
		 and   ebx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 movsx ebx,word [R_D0+EBX*4]
		 movsx eax,ax
		 test  ebx,ebx
		 jl    near OP0_41b9_Trap_minus
		 cmp   ebx,eax
		 jg    near OP0_41b9_Trap_over
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41b9_Trap_minus:
		 or    edx,0x0080
		 jmp   short OP0_41b9_Trap_Exception
		 ALIGN 4

OP0_41b9_Trap_over:
		 and   edx,0x007f
OP0_41b9_Trap_Exception:
		 mov   al,6
		 call  Exception

		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41ba:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 shr   ebx,byte 9
		 and   ebx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 movsx ebx,word [R_D0+EBX*4]
		 movsx eax,ax
		 test  ebx,ebx
		 jl    near OP0_41ba_Trap_minus
		 cmp   ebx,eax
		 jg    near OP0_41ba_Trap_over
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41ba_Trap_minus:
		 or    edx,0x0080
		 jmp   short OP0_41ba_Trap_Exception
		 ALIGN 4

OP0_41ba_Trap_over:
		 and   edx,0x007f
OP0_41ba_Trap_Exception:
		 mov   al,6
		 call  Exception

		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41bb:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 shr   ebx,byte 9
		 and   ebx,byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_41bb_1
		 cwde
OP0_41bb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 movsx ebx,word [R_D0+EBX*4]
		 movsx eax,ax
		 test  ebx,ebx
		 jl    near OP0_41bb_Trap_minus
		 cmp   ebx,eax
		 jg    near OP0_41bb_Trap_over
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41bb_Trap_minus:
		 or    edx,0x0080
		 jmp   short OP0_41bb_Trap_Exception
		 ALIGN 4

OP0_41bb_Trap_over:
		 and   edx,0x007f
OP0_41bb_Trap_Exception:
		 mov   al,6
		 call  Exception

		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41bc:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 shr   ebx,byte 9
		 and   ebx,byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 movsx ebx,word [R_D0+EBX*4]
		 movsx eax,ax
		 test  ebx,ebx
		 jl    near OP0_41bc_Trap_minus
		 cmp   ebx,eax
		 jg    near OP0_41bc_Trap_over
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_41bc_Trap_minus:
		 or    edx,0x0080
		 jmp   short OP0_41bc_Trap_Exception
		 ALIGN 4

OP0_41bc_Trap_over:
		 and   edx,0x007f
OP0_41bc_Trap_Exception:
		 mov   al,6
		 call  Exception

		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c140:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   eax,[R_D0+ECX*4]
		 mov   edi,[R_D0+EBX*4]
		 mov   [R_D0+ECX*4],edi
		 mov   [R_D0+EBX*4],eax
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c148:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   eax,[R_A0+ECX*4]
		 mov   edi,[R_A0+EBX*4]
		 mov   [R_A0+ECX*4],edi
		 mov   [R_A0+EBX*4],eax
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c188:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   eax,[R_D0+ECX*4]
		 mov   edi,[R_A0+EBX*4]
		 mov   [R_D0+ECX*4],edi
		 mov   [R_A0+EBX*4],eax
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b108:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 cmp   AL,BL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b10f:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 cmp   AL,BL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b148:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   ECX
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 cmp   AX,BX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_b188:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   ECX
		 mov   EBX,EAX
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 cmp   EAX,EBX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_bf08:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 inc   dword [R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EBX,EAX
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 cmp   AL,BL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_bf0f:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   ECX
		 mov   EBX,EAX
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 cmp   AL,BL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0c0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EAX,[R_D0+EBX*4]
		 mul   word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 54
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mul   word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 58
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0d8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mul   word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 58
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0e0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mul   word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 60
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mul   word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 62
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_c0f0_1
		 cwde
OP0_c0f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mul   word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 64
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0f8:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mul   word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 62
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0f9:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mul   word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 66
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0fa:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 mul   word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 62
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0fb:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_c0fb_1
		 cwde
OP0_c0fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 mul   word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 64
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c0fc:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mul   word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 54
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1c0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EAX,[R_D0+EBX*4]
		 imul  word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 54
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1d0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 imul  word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 58
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1d8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 add   dword [R_A0+EBX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 imul  word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 58
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1e0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+EBX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 imul  word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 60
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1e8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+EBX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 imul  word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 62
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1f0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,[R_A0+EBX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_c1f0_1
		 cwde
OP0_c1f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 imul  word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 64
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1f8:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 imul  word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 62
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1f9:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 imul  word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 66
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1fa:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 imul  word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 62
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1fb:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 mov   edi,esi           ; Get PC
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_c1fb_1
		 cwde
OP0_c1fb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 imul  word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 64
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_c1fc:				;:
		 add   esi,byte 2

		 shr   ecx, byte 9
		 and   ecx, byte 7
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 imul  word [R_D0+ECX*4]
		 shl   edx, byte 16
		 mov   dx,ax
		 mov   [R_D0+ECX*4],edx
		 test  EDX,EDX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 54
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e77:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]
		 add   dword [R_A7],byte 6
		 mov   [R_PC],ESI
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 add   edi,byte 2
		 mov   esi,eax
		 mov   [R_PC],ESI
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 xchg  esi,eax
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 test  esi, dword 1
		 jz    near OP0_04e77
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04e77:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04e77_Bank:
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e75:				;:
		 mov   eax,[R_A7]
		 add   dword [R_A7],byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   ecx,EAX
		 call  [_a68k_memory_intf+12]
		 mov   EDX,[R_CCR]
		 mov   esi,eax
		 test  esi, dword 1
		 jz    near OP0_04e75
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04e75:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04e75_Bank:
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e90:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   EBX,[R_A7]	 ; Push onto Stack
		 sub   EBX,byte 4
		 mov   [R_A7],EBX
		 mov   EAX,[FullPC]
		 and   EAX,0xff000000
		 or    EAX,ESI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EBX
		 call  [_a68k_memory_intf+24]
		 pop   EDI
		 mov   EDX,[R_CCR]
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04e90
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04e90:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04e90_Bank:
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ea8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   EBX,[R_A7]	 ; Push onto Stack
		 sub   EBX,byte 4
		 mov   [R_A7],EBX
		 mov   EAX,[FullPC]
		 and   EAX,0xff000000
		 or    EAX,ESI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EBX
		 call  [_a68k_memory_intf+24]
		 pop   EDI
		 mov   EDX,[R_CCR]
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04ea8
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 30
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04ea8:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04ea8_Bank:
		 sub   dword [_m68k_ICount],byte 30
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4eb0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4eb0_1
		 cwde
OP0_4eb0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   EBX,[R_A7]	 ; Push onto Stack
		 sub   EBX,byte 4
		 mov   [R_A7],EBX
		 mov   EAX,[FullPC]
		 and   EAX,0xff000000
		 or    EAX,ESI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EBX
		 call  [_a68k_memory_intf+24]
		 pop   EDI
		 mov   EDX,[R_CCR]
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04eb0
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 36
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04eb0:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04eb0_Bank:
		 sub   dword [_m68k_ICount],byte 36
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4eb8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   EBX,[R_A7]	 ; Push onto Stack
		 sub   EBX,byte 4
		 mov   [R_A7],EBX
		 mov   EAX,[FullPC]
		 and   EAX,0xff000000
		 or    EAX,ESI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EBX
		 call  [_a68k_memory_intf+24]
		 pop   EDI
		 mov   EDX,[R_CCR]
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04eb8
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 30
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04eb8:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04eb8_Bank:
		 sub   dword [_m68k_ICount],byte 30
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4eb9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   EBX,[R_A7]	 ; Push onto Stack
		 sub   EBX,byte 4
		 mov   [R_A7],EBX
		 mov   EAX,[FullPC]
		 and   EAX,0xff000000
		 or    EAX,ESI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EBX
		 call  [_a68k_memory_intf+24]
		 pop   EDI
		 mov   EDX,[R_CCR]
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04eb9
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 34
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04eb9:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04eb9_Bank:
		 sub   dword [_m68k_ICount],byte 34
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4eba:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   EBX,[R_A7]	 ; Push onto Stack
		 sub   EBX,byte 4
		 mov   [R_A7],EBX
		 mov   EAX,[FullPC]
		 and   EAX,0xff000000
		 or    EAX,ESI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EBX
		 call  [_a68k_memory_intf+24]
		 pop   EDI
		 mov   EDX,[R_CCR]
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04eba
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 30
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04eba:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04eba_Bank:
		 sub   dword [_m68k_ICount],byte 30
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ebb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4ebb_1
		 cwde
OP0_4ebb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   EBX,[R_A7]	 ; Push onto Stack
		 sub   EBX,byte 4
		 mov   [R_A7],EBX
		 mov   EAX,[FullPC]
		 and   EAX,0xff000000
		 or    EAX,ESI
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EBX
		 call  [_a68k_memory_intf+24]
		 pop   EDI
		 mov   EDX,[R_CCR]
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04ebb
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 32
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04ebb:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04ebb_Bank:
		 sub   dword [_m68k_ICount],byte 32
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ed0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04ed0
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04ed0:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04ed0_Bank:
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ee8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04ee8
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04ee8:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04ee8_Bank:
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ef0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4ef0_1
		 cwde
OP0_4ef0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04ef0
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04ef0:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04ef0_Bank:
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ef8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04ef8
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04ef8:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04ef8_Bank:
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ef9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04ef9
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 26
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04ef9:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04ef9_Bank:
		 sub   dword [_m68k_ICount],byte 26
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4efa:				;:
		 add   esi,byte 2

		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04efa
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04efa:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04efa_Bank:
		 sub   dword [_m68k_ICount],byte 22
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4efb:				;:
		 add   esi,byte 2

		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4efb_1
		 cwde
OP0_4efb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   esi,edi
		 test  esi, dword 1
		 jz    near OP0_04efb
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04efb:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04efb_Bank:
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4800:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   EBX,[R_D0+ECX*4]
		 mov   EAX,0
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 pushfd
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 6
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4810:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EBX,EAX
		 mov   EAX,0
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4818:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EBX,EAX
		 mov   EAX,0
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_481f:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EBX,EAX
		 mov   EAX,0
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4820:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EBX,EAX
		 mov   EAX,0
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4827:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EBX,EAX
		 mov   EAX,0
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4828:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EBX,EAX
		 mov   EAX,0
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4830:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4830_1
		 cwde
OP0_4830_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EBX,EAX
		 mov   EAX,0
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4838:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EBX,EAX
		 mov   EAX,0
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4839:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 mov   EBX,EAX
		 mov   EAX,0
		 bt    dword [R_XC],0
		 sbb   al,bl
		 das
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ac0:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   EAX,[R_D0+ECX*4]
		 test  AL,AL
		 pushfd
		 or    al,128
		 mov   [R_D0+ECX*4],AL
		 sub   dword [_m68k_ICount],byte 4
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ad0:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 test  AL,AL
		 pushfd
		 or    al,128
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ad8:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 test  AL,AL
		 pushfd
		 or    al,128
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4adf:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 test  AL,AL
		 pushfd
		 or    al,128
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ae0:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 test  AL,AL
		 pushfd
		 or    al,128
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ae7:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 test  AL,AL
		 pushfd
		 or    al,128
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ae8:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 test  AL,AL
		 pushfd
		 or    al,128
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4af0:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4af0_1
		 cwde
OP0_4af0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 test  AL,AL
		 pushfd
		 or    al,128
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 24
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4af8:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 test  AL,AL
		 pushfd
		 or    al,128
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 22
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4af9:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 pop   EDI
		 pop   ECX
		 test  AL,AL
		 pushfd
		 or    al,128
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+16]
		 sub   dword [_m68k_ICount],byte 26
		 pop   EDX
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e40:				;:
		 add   esi,byte 2

		 mov   eax,ecx
		 and   eax,byte 15
		 or    eax,byte 32
		 call  Exception

		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e76:				;
		 add   esi,byte 2

		 test  dh,08h
		 jz    near OP0_4e76_Clear
		 sub   esi,byte 2
		 mov   al,7
		 call  Exception

		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_4e76_Clear:
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e70:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 jnz   near OP0_4e70_RESET
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],132
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]


OP0_4e70_RESET:
		 movzx ecx,word [esi+ebp]
		 mov  eax,dword [R_RESET_CALLBACK]
		 test eax,eax
		 jz   near OP0_4e70_END
		 mov   [R_PC],ESI,
		 mov   [R_CCR],edx
		 push  ECX
		 call  eax
		 mov   ESI,[R_PC]
		 mov   edx,[R_CCR]
		 pop   ECX
		 mov   ebp,dword [_OP_ROM]
OP0_4e70_END:
		 sub   dword [_m68k_ICount],132
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e71:				;:
		 add   esi,byte 2

		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e72:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 je    near OP0_4e72_1

		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_4e72_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_4e72_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 mov   eax,[R_IRQ]
		 and   eax,byte 07H
		 cmp   al,7		 ; Always take 7
		 je    near procint

		 mov   ebx,[R_SR_H]		; int mask
		 and   ebx,byte 07H
		 cmp   eax,ebx
		 jg    near procint

		 mov   ECX,0
		 mov   [_m68k_ICount],ecx
		 or    byte [R_IRQ],80h
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e72_1:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4880:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 movsx eax,byte [R_D0+ECX*4]
		 mov   [R_D0+ECX*4],ax
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_48c0:				;:
		 add   esi,byte 2

		 and   ecx, byte 7
		 movsx eax,word [R_D0+ECX*4]
		 mov   [R_D0+ECX*4],eax
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e73:				;:
		 add   esi,byte 2

		 test  byte [R_SR_H],20h 			; Supervisor Mode ?
		 je    near OP0_4e73_1

		 mov   edi,[R_A7]
		 add   dword [R_A7],byte 6
		 mov   [R_PC],ESI
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 add   edi,byte 2
		 mov   esi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 xchg  esi,eax
		 test  ah,20h 			; User Mode ?
		 jne   short OP0_4e73_2

		 mov   edx,[R_A7]
		 mov   [R_ISP],edx
		 mov   edx,[R_USP]
		 mov   [R_A7],edx
OP0_4e73_2:
		 mov   byte [R_SR_H],ah 	;T, S & I
		 and   eax,byte 1Fh
		 mov   edx,[IntelFlag+eax*4]
		 mov   [R_XC],dh
		 and   edx,0EFFh
		 test  esi, dword 1
		 jz    near OP0_04e73
		 sub   esi,byte 2
		 mov   al,3
		 call  Exception

		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_04e73:
		 mov   [FullPC],ESI
		 and   esi,[_mem_amask]
		 mov   [R_CCR],edx
		 mov   ecx,esi
		 call  [_a68k_memory_intf+28]
		 mov   edx,[R_CCR]
		 mov   ebp,dword [_OP_ROM]
OP0_04e73_Bank:
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_4e73_1:
		 sub   esi,byte 2
		 mov   al,8
		 call  Exception

		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

; Check for Interrupt waiting

		 test  byte [R_IRQ],07H
		 jne   near interrupt

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a00:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a10:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a18:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 inc   dword [R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a1f:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 add   dword [R_A7],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a20:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 dec   EDI
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a27:				;:
		 add   esi,byte 2

		 mov   edi,[R_A7]    ; Get A7
		 sub   edi,byte 2
		 mov   [R_A7],edi
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a28:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a30:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4a30_1
		 cwde
OP0_4a30_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a38:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a39:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+4]
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a40:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a48:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_A0+ECX*4]
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a50:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a58:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a60:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 10
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a68:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a70:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4a70_1
		 cwde
OP0_4a70_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a78:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a79:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a80:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_D0+ECX*4]
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a88:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EAX,[R_A0+ECX*4]
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 4
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a90:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4a98:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4aa0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 4
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4aa8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ab0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4ab0_1
		 cwde
OP0_4ab0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ab8:				;:
		 add   esi,byte 2

		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ab9:				;:
		 add   esi,byte 2

		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4890:				;:
		 add   esi,byte 2

		 push edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   ebx,1
		 mov   ECX,0
OP0_4890_Again:
		 test  edx,ebx
		 je    OP0_4890_Skip
		 mov   eax,[R_D0+ecx]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   edi,byte 2
		 sub   dword [_m68k_ICount],byte 4
OP0_4890_Skip:
		 add   ecx,byte 4h
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4890_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_48a0:				;:
		 add   esi,byte 2

		 push edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 push  ecx
		 mov   edi,[R_A0+ECX*4]
		 mov   ebx,1
		 mov   ecx,3Ch
OP0_48a0_Again:
		 test  edx,ebx
		 je    OP0_48a0_Skip
		 mov   eax,[R_D0+ecx]
		 sub   edi,byte 2
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 4
OP0_48a0_Skip:
		 sub   ecx,byte 4h
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_48a0_Again
		 pop   ecx
		 mov   [R_A0+ECX*4],edi
		 pop   edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_48a8:				;:
		 add   esi,byte 2

		 push edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   ebx,1
		 mov   ECX,0
OP0_48a8_Again:
		 test  edx,ebx
		 je    OP0_48a8_Skip
		 mov   eax,[R_D0+ecx]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   edi,byte 2
		 sub   dword [_m68k_ICount],byte 4
OP0_48a8_Skip:
		 add   ecx,byte 4h
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_48a8_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_48b0:				;:
		 add   esi,byte 2

		 push edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_48b0_1
		 cwde
OP0_48b0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   ebx,1
		 mov   ECX,0
OP0_48b0_Again:
		 test  edx,ebx
		 je    OP0_48b0_Skip
		 mov   eax,[R_D0+ecx]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   edi,byte 2
		 sub   dword [_m68k_ICount],byte 4
OP0_48b0_Skip:
		 add   ecx,byte 4h
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_48b0_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_48b8:				;:
		 add   esi,byte 2

		 push edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   ebx,1
		 mov   ECX,0
OP0_48b8_Again:
		 test  edx,ebx
		 je    OP0_48b8_Skip
		 mov   eax,[R_D0+ecx]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   edi,byte 2
		 sub   dword [_m68k_ICount],byte 4
OP0_48b8_Skip:
		 add   ecx,byte 4h
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_48b8_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_48b9:				;:
		 add   esi,byte 2

		 push edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   ebx,1
		 mov   ECX,0
OP0_48b9_Again:
		 test  edx,ebx
		 je    OP0_48b9_Skip
		 mov   eax,[R_D0+ecx]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   edi,byte 2
		 sub   dword [_m68k_ICount],byte 4
OP0_48b9_Skip:
		 add   ecx,byte 4h
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_48b9_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_48d0:				;:
		 add   esi,byte 2

		 push edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   ebx,1
		 mov   ECX,0
OP0_48d0_Again:
		 test  edx,ebx
		 je    OP0_48d0_Skip
		 mov   eax,[R_D0+ecx]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   edi,byte 4
		 sub   dword [_m68k_ICount],byte 8
OP0_48d0_Skip:
		 add   ecx,byte 4h
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_48d0_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_48e0:				;:
		 add   esi,byte 2

		 push edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 push  ecx
		 mov   edi,[R_A0+ECX*4]
		 mov   ebx,1
		 mov   ecx,3Ch
OP0_48e0_Again:
		 test  edx,ebx
		 je    OP0_48e0_Skip
		 mov   eax,[R_D0+ecx]
		 sub   edi,byte 4
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 8
OP0_48e0_Skip:
		 sub   ecx,byte 4h
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_48e0_Again
		 pop   ecx
		 mov   [R_A0+ECX*4],edi
		 pop   edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_48e8:				;:
		 add   esi,byte 2

		 push edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   ebx,1
		 mov   ECX,0
OP0_48e8_Again:
		 test  edx,ebx
		 je    OP0_48e8_Skip
		 mov   eax,[R_D0+ecx]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   edi,byte 4
		 sub   dword [_m68k_ICount],byte 8
OP0_48e8_Skip:
		 add   ecx,byte 4h
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_48e8_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_48f0:				;:
		 add   esi,byte 2

		 push edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_48f0_1
		 cwde
OP0_48f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   ebx,1
		 mov   ECX,0
OP0_48f0_Again:
		 test  edx,ebx
		 je    OP0_48f0_Skip
		 mov   eax,[R_D0+ecx]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   edi,byte 4
		 sub   dword [_m68k_ICount],byte 8
OP0_48f0_Skip:
		 add   ecx,byte 4h
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_48f0_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_48f8:				;:
		 add   esi,byte 2

		 push edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   ebx,1
		 mov   ECX,0
OP0_48f8_Again:
		 test  edx,ebx
		 je    OP0_48f8_Skip
		 mov   eax,[R_D0+ecx]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   edi,byte 4
		 sub   dword [_m68k_ICount],byte 8
OP0_48f8_Skip:
		 add   ecx,byte 4h
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_48f8_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_48f9:				;:
		 add   esi,byte 2

		 push edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   ebx,1
		 mov   ECX,0
OP0_48f9_Again:
		 test  edx,ebx
		 je    OP0_48f9_Skip
		 mov   eax,[R_D0+ecx]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 add   edi,byte 4
		 sub   dword [_m68k_ICount],byte 8
OP0_48f9_Skip:
		 add   ecx,byte 4h
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_48f9_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4c90:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   ebx,1
		 mov   ECX,0
OP0_4c90_Again:
		 test  edx,ebx
		 je    OP0_4c90_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 mov   [R_D0+ecx],eax
		 add   edi,byte 2
		 sub   dword [_m68k_ICount],byte 4
OP0_4c90_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4c90_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4c98:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 push   ecx
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   ebx,1
		 mov   ECX,0
OP0_4c98_Again:
		 test  edx,ebx
		 je    OP0_4c98_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 mov   [R_D0+ecx],eax
		 add   edi,byte 2
		 sub   dword [_m68k_ICount],byte 4
OP0_4c98_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4c98_Again
		 pop   ecx
		 mov   [R_A0+ECX*4],edi
		 pop   edx
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ca8:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   ebx,1
		 mov   ECX,0
OP0_4ca8_Again:
		 test  edx,ebx
		 je    OP0_4ca8_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 mov   [R_D0+ecx],eax
		 add   edi,byte 2
		 sub   dword [_m68k_ICount],byte 4
OP0_4ca8_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4ca8_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4cb0:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4cb0_1
		 cwde
OP0_4cb0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   ebx,1
		 mov   ECX,0
OP0_4cb0_Again:
		 test  edx,ebx
		 je    OP0_4cb0_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 mov   [R_D0+ecx],eax
		 add   edi,byte 2
		 sub   dword [_m68k_ICount],byte 4
OP0_4cb0_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4cb0_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4cb8:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   ebx,1
		 mov   ECX,0
OP0_4cb8_Again:
		 test  edx,ebx
		 je    OP0_4cb8_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 mov   [R_D0+ecx],eax
		 add   edi,byte 2
		 sub   dword [_m68k_ICount],byte 4
OP0_4cb8_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4cb8_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4cb9:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   ebx,1
		 mov   ECX,0
OP0_4cb9_Again:
		 test  edx,ebx
		 je    OP0_4cb9_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 mov   [R_D0+ecx],eax
		 add   edi,byte 2
		 sub   dword [_m68k_ICount],byte 4
OP0_4cb9_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4cb9_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4cba:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   ebx,1
		 mov   ECX,0
OP0_4cba_Again:
		 test  edx,ebx
		 je    OP0_4cba_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 mov   [R_D0+ecx],eax
		 add   edi,byte 2
		 sub   dword [_m68k_ICount],byte 4
OP0_4cba_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4cba_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4cbb:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4cbb_1
		 cwde
OP0_4cbb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   ebx,1
		 mov   ECX,0
OP0_4cbb_Again:
		 test  edx,ebx
		 je    OP0_4cbb_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+36]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 cwde
		 mov   [R_D0+ecx],eax
		 add   edi,byte 2
		 sub   dword [_m68k_ICount],byte 4
OP0_4cbb_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4cbb_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 26
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4cd0:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   ebx,1
		 mov   ECX,0
OP0_4cd0_Again:
		 test  edx,ebx
		 je    OP0_4cd0_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   [R_D0+ecx],eax
		 add   edi,byte 4
		 sub   dword [_m68k_ICount],byte 8
OP0_4cd0_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4cd0_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4cd8:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 push   ecx
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 4
		 mov   ebx,1
		 mov   ECX,0
OP0_4cd8_Again:
		 test  edx,ebx
		 je    OP0_4cd8_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   [R_D0+ecx],eax
		 add   edi,byte 4
		 sub   dword [_m68k_ICount],byte 8
OP0_4cd8_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4cd8_Again
		 pop   ecx
		 mov   [R_A0+ECX*4],edi
		 pop   edx
		 test  dword [_m68k_ICount],0xffffffff
		 jle   near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4ce8:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   ebx,1
		 mov   ECX,0
OP0_4ce8_Again:
		 test  edx,ebx
		 je    OP0_4ce8_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   [R_D0+ecx],eax
		 add   edi,byte 4
		 sub   dword [_m68k_ICount],byte 8
OP0_4ce8_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4ce8_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4cf0:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4cf0_1
		 cwde
OP0_4cf0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   ebx,1
		 mov   ECX,0
OP0_4cf0_Again:
		 test  edx,ebx
		 je    OP0_4cf0_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   [R_D0+ecx],eax
		 add   edi,byte 4
		 sub   dword [_m68k_ICount],byte 8
OP0_4cf0_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4cf0_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4cf8:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   ebx,1
		 mov   ECX,0
OP0_4cf8_Again:
		 test  edx,ebx
		 je    OP0_4cf8_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   [R_D0+ecx],eax
		 add   edi,byte 4
		 sub   dword [_m68k_ICount],byte 8
OP0_4cf8_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4cf8_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4cf9:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   ebx,1
		 mov   ECX,0
OP0_4cf9_Again:
		 test  edx,ebx
		 je    OP0_4cf9_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   [R_D0+ecx],eax
		 add   edi,byte 4
		 sub   dword [_m68k_ICount],byte 8
OP0_4cf9_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4cf9_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 28
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4cfa:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 movsx EAX,word [esi+ebp]
		 mov   EDI,ESI           ; Get PC
		 add   esi,byte 2
		 add   edi,eax         ; Add Offset to PC
		 mov   ebx,1
		 mov   ECX,0
OP0_4cfa_Again:
		 test  edx,ebx
		 je    OP0_4cfa_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   [R_D0+ecx],eax
		 add   edi,byte 4
		 sub   dword [_m68k_ICount],byte 8
OP0_4cfa_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4cfa_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 24
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4cfb:				;:
		 add   esi,byte 2

		 push  edx
		 movzx EDX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edi,esi           ; Get PC
		 push  edx
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_4cfb_1
		 cwde
OP0_4cfb_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 pop   edx
		 mov   ebx,1
		 mov   ECX,0
OP0_4cfb_Again:
		 test  edx,ebx
		 je    OP0_4cfb_Skip
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+40]
		 pop   EDI
		 pop   ECX
		 mov   EDX,[R_CCR]
		 mov   [R_D0+ecx],eax
		 add   edi,byte 4
		 sub   dword [_m68k_ICount],byte 8
OP0_4cfb_Skip:
		 add   ecx,byte 4
		 add   ebx,ebx
		 test  bx,bx
		 jnz   OP0_4cfb_Again
		 pop   edx
		 sub   dword [_m68k_ICount],byte 26
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e50:				;:
		 add   esi,byte 2

		 sub   dword [R_A7],byte 4
		 and   ecx, byte 7
		 mov   eax,[R_A0+ECX*4]
		 mov   edi,[R_A7]
		 mov   [R_A0+ECX*4],edi
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+24]
		 mov   EDX,[R_CCR]
		 movsx EAX,word [esi+ebp]
		 add   esi,byte 2
		 add   [R_A7],eax
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_4e58:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx, byte 7
		 mov   edi,[R_A0+EBX*4]
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+12]
		 pop   EDI
		 mov   EDX,[R_CCR]
		 mov   [R_A0+EBX*4],eax
		 add   edi,byte 4
		 mov   dword [R_A7],EDI
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e000:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 mov   EAX,[R_D0+EBX*4]
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 shrd  edx,ecx,6
		 sar   edx,31
		 and   edx,31
		 or    ecx,edx
		 sar   AL,cl
		 mov   [R_D0+EBX*4],AL
		 lahf
		 movzx edx,ah
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e020:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 mov   EAX,[R_D0+EBX*4]
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 jz   short OP0_e020_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 shrd  edx,ecx,6
		 sar   edx,31
		 and   edx,31
		 or    ecx,edx
		 sar   AL,cl
		 mov   [R_D0+EBX*4],AL
		 lahf
		 movzx edx,ah
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e020_1:
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e040:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 mov   EAX,[R_D0+EBX*4]
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 shrd  edx,ecx,6
		 sar   edx,31
		 and   edx,31
		 or    ecx,edx
		 sar   AX,cl
		 mov   [R_D0+EBX*4],AX
		 lahf
		 movzx edx,ah
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e060:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 mov   EAX,[R_D0+EBX*4]
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 jz   short OP0_e060_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 shrd  edx,ecx,6
		 sar   edx,31
		 and   edx,31
		 or    ecx,edx
		 sar   AX,cl
		 mov   [R_D0+EBX*4],AX
		 lahf
		 movzx edx,ah
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e060_1:
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e080:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 mov   EAX,[R_D0+EBX*4]
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 shrd  edx,ecx,6
		 sar   edx,31
		 and   edx,31
		 or    ecx,edx
		 sar   EAX,cl
		 mov   [R_D0+EBX*4],EAX
		 lahf
		 movzx edx,ah
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e0a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 mov   EAX,[R_D0+EBX*4]
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 jz   short OP0_e0a0_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 shrd  edx,ecx,6
		 sar   edx,31
		 and   edx,31
		 or    ecx,edx
		 sar   EAX,cl
		 mov   [R_D0+EBX*4],EAX
		 lahf
		 movzx edx,ah
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e0a0_1:
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e100:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 mov   EAX,[R_D0+EBX*4]
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   edi,eax		; Save It
		 mov   EDX,0
		 stc
		 rcr   DL,1		; d=1xxxx
		 sar   DL,cl		; d=1CCxx
		 and   eax,edx
		 jz    short OP0_e100_1_V		; No Overflow
		 cmp   eax,edx
		 je    short OP0_e100_1_V		; No Overflow
		 mov   edx,0x800
		 jmp   short OP0_e100_1_OV
OP0_e100_1_V:
		 mov   EDX,0
OP0_e100_1_OV:
		 mov   eax,edi		; Restore It
		 sal   AL,cl
		 mov   [R_D0+EBX*4],AL
		 lahf
		 mov   dl,ah
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e120:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 mov   EAX,[R_D0+EBX*4]
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 jz   short OP0_e120_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   edi,eax		; Save It
		 mov   EDX,0
		 stc
		 rcr   DL,1		; d=1xxxx
		 sar   DL,cl		; d=1CCxx
		 and   eax,edx
		 jz    short OP0_e120_1_V		; No Overflow
		 cmp   eax,edx
		 je    short OP0_e120_1_V		; No Overflow
		 mov   edx,0x800
		 jmp   short OP0_e120_1_OV
OP0_e120_1_V:
		 mov   EDX,0
OP0_e120_1_OV:
		 mov   eax,edi		; Restore It
		 sal   AL,cl
		 mov   [R_D0+EBX*4],AL
		 lahf
		 mov   dl,ah
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e120_1:
		 mov   ebx,edx
		 and   ebx,byte 1
		 test  AL,AL
		 pushfd
		 pop   EDX
		 or    edx,ebx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e140:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 mov   EAX,[R_D0+EBX*4]
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   edi,eax		; Save It
		 mov   EDX,0
		 stc
		 rcr   DX,1		; d=1xxxx
		 sar   DX,cl		; d=1CCxx
		 and   eax,edx
		 jz    short OP0_e140_1_V		; No Overflow
		 cmp   eax,edx
		 je    short OP0_e140_1_V		; No Overflow
		 mov   edx,0x800
		 jmp   short OP0_e140_1_OV
OP0_e140_1_V:
		 mov   EDX,0
OP0_e140_1_OV:
		 mov   eax,edi		; Restore It
		 sal   AX,cl
		 mov   [R_D0+EBX*4],AX
		 lahf
		 mov   dl,ah
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e160:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 mov   EAX,[R_D0+EBX*4]
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 jz   short OP0_e160_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   edi,eax		; Save It
		 mov   EDX,0
		 stc
		 rcr   DX,1		; d=1xxxx
		 sar   DX,cl		; d=1CCxx
		 and   eax,edx
		 jz    short OP0_e160_1_V		; No Overflow
		 cmp   eax,edx
		 je    short OP0_e160_1_V		; No Overflow
		 mov   edx,0x800
		 jmp   short OP0_e160_1_OV
OP0_e160_1_V:
		 mov   EDX,0
OP0_e160_1_OV:
		 mov   eax,edi		; Restore It
		 sal   AX,cl
		 mov   [R_D0+EBX*4],AX
		 lahf
		 mov   dl,ah
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e160_1:
		 mov   ebx,edx
		 and   ebx,byte 1
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    edx,ebx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e180:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 mov   EAX,[R_D0+EBX*4]
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   edi,eax		; Save It
		 mov   EDX,0
		 stc
		 rcr   EDX,1		; d=1xxxx
		 sar   EDX,cl		; d=1CCxx
		 and   eax,edx
		 jz    short OP0_e180_1_V		; No Overflow
		 cmp   eax,edx
		 je    short OP0_e180_1_V		; No Overflow
		 mov   edx,0x800
		 jmp   short OP0_e180_1_OV
OP0_e180_1_V:
		 mov   EDX,0
OP0_e180_1_OV:
		 mov   eax,edi		; Restore It
		 sal   EAX,cl
		 mov   [R_D0+EBX*4],EAX
		 lahf
		 mov   dl,ah
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e1a0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 mov   EAX,[R_D0+EBX*4]
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 jz   short OP0_e1a0_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   edi,eax		; Save It
		 mov   EDX,0
		 stc
		 rcr   EDX,1		; d=1xxxx
		 sar   EDX,cl		; d=1CCxx
		 and   eax,edx
		 jz    short OP0_e1a0_1_V		; No Overflow
		 cmp   eax,edx
		 je    short OP0_e1a0_1_V		; No Overflow
		 mov   edx,0x800
		 jmp   short OP0_e1a0_1_OV
OP0_e1a0_1_V:
		 mov   EDX,0
OP0_e1a0_1_OV:
		 test  cl,0x20
		 jnz   short OP0_e1a0_1_32

		 mov   eax,edi		; Restore It
		 sal   EAX,cl
		 mov   [R_D0+EBX*4],EAX
		 lahf
		 mov   dl,ah
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e1a0_1:
		 mov   ebx,edx
		 and   ebx,byte 1
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 or    edx,ebx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_e1a0_1_32:
		 mov   dl,40h
		 mov   EAX,0
		 mov   [R_D0+EBX*4],EAX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e300:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 sal   byte [R_D0+ecx*4],1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e340:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 sal   word [R_D0+ecx*4],1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e380:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 sal   long [R_D0+ecx*4],1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e0d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sar   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e0d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sar   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e0e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sar   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e0e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sar   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e0f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_e0f0_1
		 cwde
OP0_e0f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sar   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e0f8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sar   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e0f9:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sar   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e1d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sal   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e1d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sal   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 12
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e1e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sal   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 14
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e1e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sal   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e1f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_e1f0_1
		 cwde
OP0_e1f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sal   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 18
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e1f8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sal   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 16
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e1f9:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 sal   ax,1
		 pushfd
		 mov   [R_PC],ESI
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 sub   dword [_m68k_ICount],byte 20
		 pop   EDX
		 mov   [R_XC],edx
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e010:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 rcr   AL,cl
		 setc  ch
		 test  AL,AL
		 pushfd
		 pop   EDX
		 mov   [R_D0+EBX*4],AL
		 test  cl,cl
		 jz    OP0_e010_1
		 or    dl,ch
		 mov   [R_XC],dl
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e010_1:
		 mov   ecx,[R_XC]
		 and   ecx,byte 1
		 or    edx,ecx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e030:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 rcr   AL,cl
		 setc  ch
		 test  AL,AL
		 pushfd
		 pop   EDX
		 mov   [R_D0+EBX*4],AL
		 test  cl,cl
		 jz    OP0_e030_1
		 or    dl,ch
		 mov   [R_XC],dl
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e030_1:
		 mov   ecx,[R_XC]
		 and   ecx,byte 1
		 or    edx,ecx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e050:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 rcr   AX,cl
		 setc  ch
		 test  AX,AX
		 pushfd
		 pop   EDX
		 mov   [R_D0+EBX*4],AX
		 test  cl,cl
		 jz    OP0_e050_1
		 or    dl,ch
		 mov   [R_XC],dl
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e050_1:
		 mov   ecx,[R_XC]
		 and   ecx,byte 1
		 or    edx,ecx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e070:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 rcr   AX,cl
		 setc  ch
		 test  AX,AX
		 pushfd
		 pop   EDX
		 mov   [R_D0+EBX*4],AX
		 test  cl,cl
		 jz    OP0_e070_1
		 or    dl,ch
		 mov   [R_XC],dl
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e070_1:
		 mov   ecx,[R_XC]
		 and   ecx,byte 1
		 or    edx,ecx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e090:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 rcr   EAX,cl
		 setc  ch
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 mov   [R_D0+EBX*4],EAX
		 test  cl,cl
		 jz    OP0_e090_1
		 or    dl,ch
		 mov   [R_XC],dl
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e090_1:
		 mov   ecx,[R_XC]
		 and   ecx,byte 1
		 or    edx,ecx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e0b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 rcr   EAX,cl
		 setc  ch
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 mov   [R_D0+EBX*4],EAX
		 test  cl,cl
		 jz    OP0_e0b0_1
		 or    dl,ch
		 mov   [R_XC],dl
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e0b0_1:
		 mov   ecx,[R_XC]
		 and   ecx,byte 1
		 or    edx,ecx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e110:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 rcl   AL,cl
		 setc  ch
		 test  AL,AL
		 pushfd
		 pop   EDX
		 mov   [R_D0+EBX*4],AL
		 test  cl,cl
		 jz    OP0_e110_1
		 or    dl,ch
		 mov   [R_XC],dl
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e110_1:
		 mov   ecx,[R_XC]
		 and   ecx,byte 1
		 or    edx,ecx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e130:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 rcl   AL,cl
		 setc  ch
		 test  AL,AL
		 pushfd
		 pop   EDX
		 mov   [R_D0+EBX*4],AL
		 test  cl,cl
		 jz    OP0_e130_1
		 or    dl,ch
		 mov   [R_XC],dl
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e130_1:
		 mov   ecx,[R_XC]
		 and   ecx,byte 1
		 or    edx,ecx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e150:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 rcl   AX,cl
		 setc  ch
		 test  AX,AX
		 pushfd
		 pop   EDX
		 mov   [R_D0+EBX*4],AX
		 test  cl,cl
		 jz    OP0_e150_1
		 or    dl,ch
		 mov   [R_XC],dl
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e150_1:
		 mov   ecx,[R_XC]
		 and   ecx,byte 1
		 or    edx,ecx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e170:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 rcl   AX,cl
		 setc  ch
		 test  AX,AX
		 pushfd
		 pop   EDX
		 mov   [R_D0+EBX*4],AX
		 test  cl,cl
		 jz    OP0_e170_1
		 or    dl,ch
		 mov   [R_XC],dl
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e170_1:
		 mov   ecx,[R_XC]
		 and   ecx,byte 1
		 or    edx,ecx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e190:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 rcl   EAX,cl
		 setc  ch
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 mov   [R_D0+EBX*4],EAX
		 test  cl,cl
		 jz    OP0_e190_1
		 or    dl,ch
		 mov   [R_XC],dl
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e190_1:
		 mov   ecx,[R_XC]
		 and   ecx,byte 1
		 or    edx,ecx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e1b0:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 bt    dword [R_XC],0
		 rcl   EAX,cl
		 setc  ch
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 mov   [R_D0+EBX*4],EAX
		 test  cl,cl
		 jz    OP0_e1b0_1
		 or    dl,ch
		 mov   [R_XC],dl
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e1b0_1:
		 mov   ecx,[R_XC]
		 and   ecx,byte 1
		 or    edx,ecx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e4d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcr   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e4d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcr   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e4e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcr   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e4e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcr   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e4f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_e4f0_1
		 cwde
OP0_e4f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcr   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e4f8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcr   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e4f9:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcr   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e5d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcl   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e5d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcl   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e5e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcl   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e5e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcl   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e5f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_e5f0_1
		 cwde
OP0_e5f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcl   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e5f8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcl   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e5f9:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 bt    dword [R_XC],0
		 rcl   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e008:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 test  cl,0x20
		 jnz   OP0_e008_1_BigShift
OP0_e008_1_Continue:
		 shr   AL,cl
		 pushfd
		 pop   EDX
		 xor   dh,dh
		 mov   [R_D0+EBX*4],AL
		 jecxz OP0_e008_1
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e008_1:
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_e008_1_BigShift:
		 shr   AL,16
		 shr   AL,16
		 jmp   OP0_e008_1_Continue
		 ALIGN 4

OP0_e028:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 test  cl,0x20
		 jnz   OP0_e028_1_BigShift
OP0_e028_1_Continue:
		 shr   AL,cl
		 pushfd
		 pop   EDX
		 xor   dh,dh
		 mov   [R_D0+EBX*4],AL
		 jecxz OP0_e028_1
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e028_1:
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_e028_1_BigShift:
		 shr   AL,16
		 shr   AL,16
		 jmp   OP0_e028_1_Continue
		 ALIGN 4

OP0_e048:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 test  cl,0x20
		 jnz   OP0_e048_1_BigShift
OP0_e048_1_Continue:
		 shr   AX,cl
		 pushfd
		 pop   EDX
		 xor   dh,dh
		 mov   [R_D0+EBX*4],AX
		 jecxz OP0_e048_1
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e048_1:
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_e048_1_BigShift:
		 shr   AX,16
		 shr   AX,16
		 jmp   OP0_e048_1_Continue
		 ALIGN 4

OP0_e068:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 test  cl,0x20
		 jnz   OP0_e068_1_BigShift
OP0_e068_1_Continue:
		 shr   AX,cl
		 pushfd
		 pop   EDX
		 xor   dh,dh
		 mov   [R_D0+EBX*4],AX
		 jecxz OP0_e068_1
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e068_1:
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_e068_1_BigShift:
		 shr   AX,16
		 shr   AX,16
		 jmp   OP0_e068_1_Continue
		 ALIGN 4

OP0_e088:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 test  cl,0x20
		 jnz   OP0_e088_1_BigShift
OP0_e088_1_Continue:
		 shr   EAX,cl
		 pushfd
		 pop   EDX
		 xor   dh,dh
		 mov   [R_D0+EBX*4],EAX
		 jecxz OP0_e088_1
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e088_1:
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_e088_1_BigShift:
		 shr   EAX,16
		 shr   EAX,16
		 jmp   OP0_e088_1_Continue
		 ALIGN 4

OP0_e0a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 test  cl,0x20
		 jnz   OP0_e0a8_1_BigShift
OP0_e0a8_1_Continue:
		 shr   EAX,cl
		 pushfd
		 pop   EDX
		 xor   dh,dh
		 mov   [R_D0+EBX*4],EAX
		 jecxz OP0_e0a8_1
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e0a8_1:
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_e0a8_1_BigShift:
		 shr   EAX,16
		 shr   EAX,16
		 jmp   OP0_e0a8_1_Continue
		 ALIGN 4

OP0_e108:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 test  cl,0x20
		 jnz   OP0_e108_1_BigShift
OP0_e108_1_Continue:
		 shl   AL,cl
		 pushfd
		 pop   EDX
		 xor   dh,dh
		 mov   [R_D0+EBX*4],AL
		 jecxz OP0_e108_1
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e108_1:
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_e108_1_BigShift:
		 shl   AL,16
		 shl   AL,16
		 jmp   OP0_e108_1_Continue
		 ALIGN 4

OP0_e128:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 test  cl,0x20
		 jnz   OP0_e128_1_BigShift
OP0_e128_1_Continue:
		 shl   AL,cl
		 pushfd
		 pop   EDX
		 xor   dh,dh
		 mov   [R_D0+EBX*4],AL
		 jecxz OP0_e128_1
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e128_1:
		 test  AL,AL
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_e128_1_BigShift:
		 shl   AL,16
		 shl   AL,16
		 jmp   OP0_e128_1_Continue
		 ALIGN 4

OP0_e148:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 test  cl,0x20
		 jnz   OP0_e148_1_BigShift
OP0_e148_1_Continue:
		 shl   AX,cl
		 pushfd
		 pop   EDX
		 xor   dh,dh
		 mov   [R_D0+EBX*4],AX
		 jecxz OP0_e148_1
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e148_1:
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_e148_1_BigShift:
		 shl   AX,16
		 shl   AX,16
		 jmp   OP0_e148_1_Continue
		 ALIGN 4

OP0_e168:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 test  cl,0x20
		 jnz   OP0_e168_1_BigShift
OP0_e168_1_Continue:
		 shl   AX,cl
		 pushfd
		 pop   EDX
		 xor   dh,dh
		 mov   [R_D0+EBX*4],AX
		 jecxz OP0_e168_1
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e168_1:
		 test  AX,AX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_e168_1_BigShift:
		 shl   AX,16
		 shl   AX,16
		 jmp   OP0_e168_1_Continue
		 ALIGN 4

OP0_e188:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 test  cl,0x20
		 jnz   OP0_e188_1_BigShift
OP0_e188_1_Continue:
		 shl   EAX,cl
		 pushfd
		 pop   EDX
		 xor   dh,dh
		 mov   [R_D0+EBX*4],EAX
		 jecxz OP0_e188_1
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e188_1:
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_e188_1_BigShift:
		 shl   EAX,16
		 shl   EAX,16
		 jmp   OP0_e188_1_Continue
		 ALIGN 4

OP0_e1a8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 mov   EAX,[R_D0+EBX*4]
		 test  cl,0x20
		 jnz   OP0_e1a8_1_BigShift
OP0_e1a8_1_Continue:
		 shl   EAX,cl
		 pushfd
		 pop   EDX
		 xor   dh,dh
		 mov   [R_D0+EBX*4],EAX
		 jecxz OP0_e1a8_1
		 mov   [R_XC],edx
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e1a8_1:
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

OP0_e1a8_1_BigShift:
		 shl   EAX,16
		 shl   EAX,16
		 jmp   OP0_e1a8_1_Continue
		 ALIGN 4

OP0_e2d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e2d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e2e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e2e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e2f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_e2f0_1
		 cwde
OP0_e2f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e2f8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e2f9:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shr   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e3d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shl   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e3d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shl   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e3e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shl   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e3e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shl   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e3f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_e3f0_1
		 cwde
OP0_e3f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shl   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e3f8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shl   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e3f9:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 shl   ax,1
		 pushfd
		 pop   EDX
		 mov   [R_XC],edx
		 xor   dh,dh
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e018:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   EAX,[R_D0+EBX*4]
		 jecxz OP0_e018_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 ror   AL,cl
		 setc  ch
OP0_e018_1:
		 test  AL,AL
		 pushfd
		 pop   EDX
		 or    dl,ch
		 mov   [R_D0+EBX*4],AL
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e038:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   EAX,[R_D0+EBX*4]
		 jecxz OP0_e038_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 ror   AL,cl
		 setc  ch
OP0_e038_1:
		 test  AL,AL
		 pushfd
		 pop   EDX
		 or    dl,ch
		 mov   [R_D0+EBX*4],AL
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e058:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   EAX,[R_D0+EBX*4]
		 jecxz OP0_e058_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 ror   AX,cl
		 setc  ch
OP0_e058_1:
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,ch
		 mov   [R_D0+EBX*4],AX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e078:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   EAX,[R_D0+EBX*4]
		 jecxz OP0_e078_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 ror   AX,cl
		 setc  ch
OP0_e078_1:
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,ch
		 mov   [R_D0+EBX*4],AX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e098:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   EAX,[R_D0+EBX*4]
		 jecxz OP0_e098_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 ror   EAX,cl
		 setc  ch
OP0_e098_1:
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 or    dl,ch
		 mov   [R_D0+EBX*4],EAX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e0b8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   EAX,[R_D0+EBX*4]
		 jecxz OP0_e0b8_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 ror   EAX,cl
		 setc  ch
OP0_e0b8_1:
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 or    dl,ch
		 mov   [R_D0+EBX*4],EAX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e118:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   EAX,[R_D0+EBX*4]
		 jecxz OP0_e118_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 rol   AL,cl
		 setc  ch
OP0_e118_1:
		 test  AL,AL
		 pushfd
		 pop   EDX
		 or    dl,ch
		 mov   [R_D0+EBX*4],AL
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e138:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   EAX,[R_D0+EBX*4]
		 jecxz OP0_e138_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 rol   AL,cl
		 setc  ch
OP0_e138_1:
		 test  AL,AL
		 pushfd
		 pop   EDX
		 or    dl,ch
		 mov   [R_D0+EBX*4],AL
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e158:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   EAX,[R_D0+EBX*4]
		 jecxz OP0_e158_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 rol   AX,cl
		 setc  ch
OP0_e158_1:
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,ch
		 mov   [R_D0+EBX*4],AX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e178:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   EAX,[R_D0+EBX*4]
		 jecxz OP0_e178_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 rol   AX,cl
		 setc  ch
OP0_e178_1:
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,ch
		 mov   [R_D0+EBX*4],AX
		 sub   dword [_m68k_ICount],byte 6
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e198:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 dec   ecx          ; Move range down
		 and   ecx,byte 7   ; Mask out lower bits
		 inc   ecx          ; correct range
		 mov   EAX,[R_D0+EBX*4]
		 jecxz OP0_e198_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 rol   EAX,cl
		 setc  ch
OP0_e198_1:
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 or    dl,ch
		 mov   [R_D0+EBX*4],EAX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e1b8:				;:
		 add   esi,byte 2

		 mov   ebx,ecx
		 and   ebx,byte 7
		 shr   ecx,byte 9
		 and   ecx,byte 7
		 mov   ECX,[R_D0+ECX*4]
		 and   ecx,byte 63
		 mov   EAX,[R_D0+EBX*4]
		 jecxz OP0_e1b8_1
		 mov   edx,ecx
		 add   edx,edx
		 sub   dword [_m68k_ICount],edx
		 rol   EAX,cl
		 setc  ch
OP0_e1b8_1:
		 test  EAX,EAX
		 pushfd
		 pop   EDX
		 or    dl,ch
		 mov   [R_D0+EBX*4],EAX
		 sub   dword [_m68k_ICount],byte 8
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e6d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 ror   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e6d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 ror   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e6e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 ror   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e6e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 ror   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e6f0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 movzx EAX,word [esi+ebp]
		 add   esi,byte 2
		 mov   edx,eax
		 shr   eax,12
		 test  edx,0x0800
		 mov   eax,[R_D0+eax*4]
		 jnz   short OP0_e6f0_1
		 cwde
OP0_e6f0_1:
		 lea   edi,[edi+eax]
		 movsx edx,dl
		 lea   edi,[edi+edx]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 ror   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 18
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e6f8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EDI,word [esi+ebp]
		 add   esi,byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 ror   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 16
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e6f9:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,dword [esi+ebp]
		 rol   EDI,16
		 add   esi,byte 4
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 ror   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 20
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e7d0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 rol   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e7d8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 add   dword [R_A0+ECX*4],byte 2
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 rol   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 12
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e7e0:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 mov   EDI,[R_A0+ECX*4]
		 sub   EDI,byte 2
		 mov   [R_A0+ECX*4],EDI
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 rol   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx
		 mov   edx,EAX
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+20]
		 mov   EDX,[R_CCR]
		 sub   dword [_m68k_ICount],byte 14
		 js    near MainExit

		 movzx ecx,word [esi+ebp]
		 jmp   [_M68000_OPCODETABLE+ecx*4]

		 ALIGN 4

OP0_e7e8:				;:
		 add   esi,byte 2

		 and   ecx,byte 7
		 movsx EAX,word [esi+ebp]
		 mov   EDI,[R_A0+ECX*4]
		 add   esi,byte 2
		 add   edi,eax
		 mov   [R_PC],ESI
		 push  ECX
		 push  EDI
		 mov   ecx,EDI
		 call  [_a68k_memory_intf+8]
		 pop   EDI
		 pop   ECX
		 rol   ax,1
		 setc  bl
		 test  AX,AX
		 pushfd
		 pop   EDX
		 or    dl,bl
		 mov   [R_PC],ESI
		 mov   [R_CCR],edx

