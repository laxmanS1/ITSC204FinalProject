NULL            equ 0x00            ; malloc (mmap syscall)
MAP_SHARED      equ 0x01
MAP_PRIVATE     equ 0x02
MAP_FIXED       equ 0x10
MAP_ANONYMOUS   equ 0x20
PROT_NONE       equ 0x00
PROT_READ       equ 0x01
PROT_WRITE      equ 0x02
PROT_EXEC       equ 0x04
malloc_size     equ 0x400
MSG_DONTWAIT    equ 0x40
MSG_WAITALL     equ 0x100
count           equ 0x99


;*****************************
struc sockaddr_in_type
; defined in man ip(7) because it's dependent on the type of address
    .sin_family:        resw 1
    .sin_port:          resw 1
    .sin_addr:          resd 1
    .sin_zero:          resd 2          ; padding       
endstruc
;*****************************
MSG_DONTWAIT equ 0x40
MSG_WAITALL equ 0x100

section .data
    send_command:   db "100", 0xA   ; DO NOT TERMINATE WITH 0x00
    send_command_l: equ $ - send_command
    socket_f_msg:   db "Socket failed to be created.", 0xA, 0x0
    socket_f_msg_l: equ $ - socket_f_msg
    socket_t_msg:   db "Socket created.", 0xA, 0x0
    socket_t_msg_l: equ $ - socket_t_msg
    con_f_msg:   db "Socket failed to connect.", 0xA, 0x0
    con_f_msg_l: equ $ - con_f_msg
    con_t_msg:   db "Socket connected.", 0xA, 0x0
    con_t_msg_l: equ $ - con_t_msg
    bind_t_msg:   db "Socket bound.", 0xA, 0x0
    bind_t_msg_l: equ $ - bind_t_msg
    bind_f_msg:   db "Socket failed to bind.", 0xA, 0x0
    bind_f_msg_l: equ $ - bind_f_msg
    filename: db "File.txt",0x0
    filename_l: equ $ - filename
    fileCre_t_msg: db "File Created.", 0xA, 0x0
    fileCre_t_msg_l: equ $ - fileCre_t_msg
    message1: db "---- Random Data-----", 0xA, 0x00
    message1_l: equ $ - message1
    message2: dq  "---- Sorted Data-----", 0xA, 0x00
    message2_l: equ $ - message2
    message_sent_f: db "Failed to send message to server.", 0xA, 0x0
    message_sent_f_l: equ $ - message_sent_f
    message_sent: db "Message received from server.", 0xA, 0x0
    message_sent_l: equ $ - message_sent
    swap db 0x64

   
        sockaddr_in: 
        istruc sockaddr_in_type 
            at sockaddr_in_type.sin_family,  dw 0x02            ;AF_INET -> 2 
            at sockaddr_in_type.sin_port,    dw 0xDF27          ;port 10207;(DEFAULT, passed on stack) port in hex and big endian order, 10209 -> 0xE127
            at sockaddr_in_type.sin_addr,    dd 0xB886EE8C      ;IP 140.238.134.184 ;(DEFAULT) 00 -> any address, address 127.0.0.1 -> 0x0100007F
        iend
    sockaddr_in_l:  equ $ - sockaddr_in

    space: db 0xA
    space_l: equ $ - space



section .text
global _start
_start:

  
    call _malloc.allocate           ;allocate memory in heap
    call _network.init              ;call network init function
    call _network.connect           ;NNetwork connect call
    call _network.send_rec          ; data send call
    call _network.receive           ; data received receive
   
    call _file.create               ;create file call

    push message1_l                 ; write message "Random Data" on the text file
    push message1
    call _file.write
    call _file.append
    
    
   
    push 0x100
    push rec_buffer
    call _file.write                ; writing data that are recieved from the server to the file
    call _file.append
 

    push message2_l                 ;wrining message "sorted data" and append on text file"
    push message2
    call _file.write
    call _file.append
    
    push 0x100
    push rec_buffer
    call _bubblesort                ; writing data recieved after bubble sort and append to the text file
    call _file.write      
    call _file.append
  
   
    call _malloc.free               ;free nmap syscall
    call _file.close
    jmp _exit

    
    
_malloc:                            ; malloc (mmap syscall); returns pointer to allocated memory on heap in rax
    .allocate:
        mov rax, 0x9
        mov rdi, NULL       
        mov rsi, malloc_size      
        mov rdx, PROT_WRITE
        mov r10, MAP_ANONYMOUS
        or r10, MAP_PRIVATE
        mov r8, 0x00
        mov r9, 0x00
        syscall
        mov [mem_map_ptr], rax
        ret

    .free:
        ; free (munmap syscall)
        ; returns 0x00 in rax if succesful
        mov rax, 0xb
        mov rdi, [mem_map_ptr]
        mov rsi, malloc_size
        syscall
        ret

_network:
        .init:
        ; socket, based on IF_INET to get tcp
        mov rax, 0x29                       ; socket syscall
        mov rdi, 0x02                       ; int domain - AF_INET = 2, AF_LOCAL = 1
        mov rsi, 0x01                       ; int type - SOCK_STREAM = 1
        mov rdx, 0x00                       ; int protocol is 0
        syscall 
        cmp rax, 0x00
        jl _socket_failed                   ; jump if negative
        mov [socket_fd], rax                 ; save the socket fd to basepointer

        call _socket_created
        ret

        .connect:
        ; connect, based on connect(2) syscall
        mov rax, 0x2A                       ; connect syscall
        mov rdi, qword [socket_fd]          ; int socketfd
        mov rsi, sockaddr_in                       
        mov rdx, sockaddr_in_l                     
        syscall     
        cmp rax, 0x00
        jl _connect_failed                  ;prints connection failed
        call _connect_created               ;prints connection successful
        ret

        .send_rec:
        ; based on sendto syscall
        mov rax, 0x2C                        ; sendmsg syscall
        mov rdi, [socket_fd]                 ; int fd
        mov rsi, send_command                ; int type - SOCK_STREAM = 1
        mov rdx, send_command_l              ; int protocol is 0
        mov r10, MSG_DONTWAIT
        mov r8, sockaddr_in
        mov r9, sockaddr_in_l 
        syscall
        
        cmp rax, 0x0
        jl _message_sent_f                    ;prints message sent fail
        call _message_sent                     ;prints message received from server
        ret

        .receive:
        ; using receivefrom syscall
        mov rax, 0x2D
        mov rdi, [socket_fd]
        mov rsi, rec_buffer
        mov rdx, 0x100                      ; must match the requested number of bytes
        mov r10, MSG_WAITALL                ; 
        mov r8, 0x00
        mov r9, 0x00
        syscall
        ret                          
       
               
_file:  

    .create:                                  ; creating file
   
        mov rax, 0x55                            
        mov rdi, filename
        mov rsi, 0511                          ; permissions to read and write to owner and read to all                 
        syscall
    
        cmp rax, 0x0
        mov [message_fd], rax                 ; moving file descriptor for the file to message_fd
        ret
        call _file_created
        ret

        .write:
        ; prologue
        push rbp
        mov rbp, rsp
        push rdi
        push rsi
                                                                                     
        
        mov rax, 0x1                            ;write to file
        mov rdi, [message_fd]
        mov rsi, [rbp + 0x10]
        mov rdx, [rbp + 0x18]
        syscall
        ; epilogue
        pop rsi
        pop rdi
        pop rbp
        ret 0x10   

    .append:
                                                ;to append data on file
        ; prologue
        push rbp
        mov rbp, rsp
        push rdi
        push rsi
       
        mov rax, 0x8
        mov rdi, [readfile_fd]
        mov rsi, 0x0                        ; data to write to file
        mov rdx, 1                                         
        syscall

    ; [rbp + 0x10]  buffer pointer

        ; epilogue
        pop rsi
        pop rdi
        pop rbp
        ret 0x10                            ; clean up the stack upon return - not strictly following C Calling Convention

    .close:                                 ; close the file

        mov rax, 0x3
        mov rdi, [readfile_fd]                      
        syscall
        ret
_bubblesort:
      
    
        push 0x100
        push rec_buffer
        
        
        
        push rbp       
        mov rbp, rsp
        sub rsp, 0x08                        ; allocate place for single local variable
        push rsi
        push rdi
        push r8
        push r9

    
    
    .start:
        ; if low < high, jmp noswap
        mov r8, [rbp + 0x10]
        mov r9, [rbp + 0x18]
    
        cmp r8, r9
        jae .noswap

        
    
   .compare:

        mov r8, [rbp + 0x18]
        mov r9, [rbp + 0x20]

        cmp r8, r9
        
        jae .noswap

    .swapping:
        mov rdx, [rbp + 0x18] 
        mov [rbp + 0x18] ,rax
        mov [rbp + 0x10], rdx
        pop rax
        pop rdx
        pop rsp
        call _file.write
        call _file.append
        mov byte [swap], 1
        
   
    
    .noswap:
        add rbx, 0x08
        cmp rbx, 0x64
        jne .compare
        

        cmp byte [swap],0x0
        jnz .start

        
            ; callee epilogue
        pop r8
        pop rdi
        pop rsi
        pop rbp  
        ret

_print:
    ; prologue
    push rbp
    mov rbp, rsp
    push rdi
    push rsi

    ; [rbp + 0x10] -> buffer pointer
    ; [rbp + 0x18] -> buffer length
    
    mov rax, 0x1
    mov rdi, 0x1
    mov rsi, [rbp + 0x10]
    mov rdx, [rbp + 0x18]
    syscall

    ; epilogue
    pop rsi
    pop rdi
    pop rbp
    ret 0x10

_socket_failed:
    ; print socket failed
    push socket_f_msg_l
    push socket_f_msg
    call _print
    jmp _exit
    
_socket_created:
    ; print socket created
    push socket_t_msg_l
    push socket_t_msg
    call _print
    ret

_connect_failed:
    ; print bind failed
    push con_f_msg_l
    push con_f_msg
    call _print
    jmp _exit
_connect_created:
    ; print bind created
    push con_t_msg_l
    push con_t_msg
    call _print
    ret

_exit:
    ;call _network.close
    ;call _network.shutdown
    mov rax, 0x3C       ; sys_exit
    mov rdi, 0x00       ; return code  
    syscall

_file_created:
    ; print file Created
    push fileCre_t_msg_l
    push fileCre_t_msg
    call _print
    ret

_message_sent_f:
    ;print message sent to server
    push message_sent_f_l
    push message_sent_f
    call _print 
    ret
_message_sent:
    ;print message sent to server
    push message_sent_l
    push message_sent
    call _print 
    ret

section .bss                              ;reserving bytes;buffer
    mem_map_ptr:    resq    1             ; malloc pointer reserve
    rec_buffer:     resb    0x101         ; store data recieved from server
    socket_fd:      resq    1             ; socket file descriptor
    character       resb    100             
    message_fd      resq    1             ;  File descriptor to write file    
    message_buf_l   resq    4              
    readfile_fd     resq    1             ;file descriptor for read file
    
