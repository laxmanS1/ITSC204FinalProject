; November 14, 2022
; Southern Alberta Institute of TechnologyISS - SAIT

section .bss
    mem_ptr:    resq    100000
    mem_ptr2:   resq    100000
section .data
    NULL            equ 0x00
    MAP_SHARED      equ 0x01
    MAP_PRIVATE     equ 0x02
    MAP_FIXED       equ 0x10
    MAP_ANONYMOUS   equ 0x20
    PROT_NONE       equ 0x00
    PROT_READ       equ 0x01
    PROT_WRITE      equ 0x02
    PROT_EXEC       equ 0x04
    
    malloc_size     equ 0xffffffffffffffff
    malloc_size2    equ 0xffffffffffffffff

    HEX: db "0x000000", 0

section .text               ; defines that the text below if the program itself
    
    global _start           ; Entry point

_start:                     ; Global label
    
    call _malloc
    call _malloc2
    
    push rdx
    push rcx
    push rbx
    push qword 0x0
    push qword 0x1869D
    push qword 0x186A0
    
    call _addtoheap

    add rsp, 0x08
    pop rdx
    pop rcx
    pop rbx

    call _free
    call _free2

    jmp _exit

_malloc:
    ; malloc (mmap syscall)
    ; returns pointer to allocated memory on heap in rax
    mov rax, 0x9
    mov rdi, NULL       
    mov rsi, malloc_size      
    mov rdx, PROT_WRITE
    mov r10, MAP_ANONYMOUS
    or r10, MAP_PRIVATE
    mov r8, 0x00
    mov r9, 0x00
    syscall
    mov [mem_ptr], rax
    ret

_malloc2:
    ; malloc (mmap syscall)
    ; returns pointer to allocated memory on heap in rax
    mov rax, 0x9
    mov rdi, NULL       
    mov rsi, malloc_size2      
    mov rdx, PROT_WRITE
    mov r10, MAP_ANONYMOUS
    or r10, MAP_PRIVATE
    mov r8, 0x00
    mov r9, 0x00
    syscall
    mov [mem_ptr2], rax
    ret    

_addtoheap:
    ;prologue
    push rbp
    mov rbp, rsp
    sub rsp, 0x08
    push rsi
    push rdi
    
    mov qword [rbp - 0x08], 2
    
    xor rcx, rcx
    mov rax, [rbp - 0x08]
    mov rbx, [rbp - 0x08]
    .fillheapwithnumbers: 
        mov [mem_ptr + rcx], rax
        mov [mem_ptr2 + rcx], rbx
        inc rax
        inc rbx
        inc rcx
        
        cmp rax, [rbp + 0x10]
        jle _addtoheap.fillheapwithnumbers
        xor rcx, rcx
        xor rbx, rbx
    .loop1:							; outer loop 
        mov rbx, rcx				; Prepare rbx to be used af counter in innerloop (loop2)
		inc rcx						; Inner loop starts at rcx + 1
	   	jmp _addtoheap.loop2					; if not jump to inner loop(loop2)
	
    .counter1:					; counter point
		inc rcx					; Increment out primary counter
		cmp rcx, [rbp + 0x18]			; Are we done?
		jle _addtoheap.loop1					; If not jump to loop start.
		call _incrementheap
        jmp _addtoheap.epilogue				

	.loop2:							; Inner loop
		cmp dword [mem_ptr + rbx], -1		; Value discarded?
		jne _addtoheap.loop3					; if nor jump to loop3
	
    .counter2:					; counter point
		inc rbx                     ; Increment inner loop counter
        					
		cmp rbx, [rbp + 0x18]			; Are we done?
		jle _addtoheap.loop2					; if not go to loop start.
		jmp _addtoheap.counter1					; return to counter1.
		
	.loop3:							; Here we will test if it is a prime...
		xor rdx, rdx				; Zero out rdx
		xor rax, rax                ; Zero out rax
        mov rdx, 0				    
		mov rax, [mem_ptr + rbx]		; Place the number we want to divite in rax
		div dword [mem_ptr2 + rcx]			; Divide the numbe in eax with the value from outer loop
		cmp rdx, 0					; Check rdx for remainder
		je _addtoheap.nonprime					; If we have no remainder it the number in eax is not a prime
									; therefore we change it. (set it to -1)
		jmp _addtoheap.counter2		
   	.nonprime:
   	    mov dword [mem_ptr + rbx], -1			; Not a prime, set it to -1
   	    jmp _addtoheap.counter2	

    .epilogue:
    pop rdi
    pop rsi
    mov rsp, rbp
    pop rbp
    ret
   
_free:
    ; free (munmap syscall)
    ; returns 0x00 in rax if succesful
    mov rax, 0xb
    mov rdi, [mem_ptr]
    mov rsi, malloc_size
    syscall
    ret
_free2:
    ; free (munmap syscall)
    ; returns 0x00 in rax if succesful
    mov rax, 0xb
    mov rdi, [mem_ptr2]
    mov rsi, malloc_size2
    syscall
    ret

_incrementheap:
    xor rcx, rcx
    
    .findprime:
    cmp dword [mem_ptr + rcx], -1
    jne _incrementheap.printprime
    jmp _incrementheap.check_if_100000

    .printprime:
        xor rdx, rdx
        mov rdx, [mem_ptr + rcx]
        call _charloop
        jmp _incrementheap.check_if_100000    

    .check_if_100000:
        inc rcx
        cmp rcx, [rbp + 0x18]
        jle _incrementheap.findprime
        ret

_charloop:
    push rax
    push rbx
    push rcx
    push rdx

    mov rcx, 5       ; Start the counter
    
    .looping:
        dec rcx            ; Decrement the counter

        mov rax,rdx         ; copy bx into rax so we can mask it for the last chars
        shr rdx,4          ; shift bx 4 bits to the right
        and rax,0xf        ; mask ah to get the last 4 bits

        mov rbx, HEX   ; set bx to the memory address of our string
        add rbx, 2         ; skip the '0x'
        add rbx, rcx        ; add the current counter to the address

        cmp rax,0xa        ; Check to see if it's a letter or number
        jl .set_letter     ; If it's a number, go straight to setting the value
        add rax, 0x27      ; If it's a letter, add 0x27, and plus 0x30 down below
                            ; ASCII letters start 0x61 for "a" characters after 
                            ; decimal numbers. We need to cover that distance.
    .set_letter:
        add rax, 0x30      ; For and ASCII number, add 0x30
        mov byte [rbx], al  ; Add the value of the byte to the char at bx

        cmp rcx,0                   ; check the counter, compare with 0
        je .print_hex               ; if the counter is 0, finish
        jmp _charloop.looping     ; otherwise, loop again

    .print_hex:
        mov rbx, HEX   ; print the string pointed to by bx
        call _printpls

        pop rax
        pop rbx
        pop rcx
        pop rdx           ; pop the initial register values back from the stack
        ret
        
_printpls: 
    mov al, [rbx]    ; Set al to the value at bx
    cmp al, 0       ; Compare the value in al to 0 (check for null terminator)
    jne .printnow  ; If it's not null, print the character at al
                  ; Otherwise the string is done, and the function is ending
    ret

    .printnow:        
        push rax                ;push rax into the stack
        mov  rdx, 1            ; length of string is 1 byte
        mov  rsi, rsp             ; Address of string is RSP because string is on the stack
        mov  rax, 1             ; syscall 1 is write
        mov  rdi, 1             ; stdout has a file descriptor of 1
        syscall
        pop rax 
        jmp _printpls
        

_exit:
    mov rax, 60             ; x86-64 syscall for sys_exit
    mov rdi, 0              ; system return code of 0 (normal exit)
    syscall                 ; execute syscall