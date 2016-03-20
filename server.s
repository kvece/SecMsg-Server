.intel_syntax noprefix

.globl _start

# DEFINES
.equ AF_INET, 2
.equ SOCK_STREAM, 1
.equ INADDR_ANY, 0

.equ STDIN, 0
.equ STDOUT, 1
.equ STDERR, 2

.equ sys_read, 0
.equ sys_write, 1
.equ sys_open, 2
.equ sys_close, 3
.equ sys_mmap, 9
.equ sys_munmap, 11
.equ sys_select, 23
.equ sys_socket, 41
.equ sys_accept, 43
.equ sys_bind, 49
.equ sys_listen, 50
.equ sys_fork, 57
.equ sys_execve, 59
.equ sys_exit, 60

.data

    newline_str:
        .asciz "\n"

    start_str:
        .asciz "Starting Server\n"
        .equ start_str_len, ($-start_str-1)

    bind_str:
        .asciz "Binding to port \n"
        .equ bind_str_len, ($-bind_str-1)
    
.bss

    .lcomm read_buffer, 1024

.text

_start:

    # setup registers
    mov rbp, rsp
   
    # DECLARE VARIABLES
    # int sock_fd;                  (rbp-4)
    # int comm_fd;                  (rbp-8)
    # struct sockaddr_in {
    #   short sin_family;           (rbp-24)
    #   unsigned short sin_port;    (rbp-22)
    #   unsigned long sin_addr;     (rbp-20)
    #   char sin_zero[8];
    # } servaddr;                   (rbp-24)
    # int port;                     (rbp-28)
    sub rsp, 28

    # read from arg vector
    here:
    mov dword ptr [rbp-28], 8080    # default port 8080
    cmp qword ptr [rbp], 1          # check argc
    jle .L_default
    lea rdi, [rbp+8]                # set port = argv[1]
    call atoi
    mov dword ptr [rbp-28], eax
    .L_default:
    mov edi, dword ptr [rbp-28]
    call print_uint
 
    # print start message
    mov rdx, start_str_len
    lea rsi, start_str
    mov rdi, STDOUT
    mov rax, sys_write
    syscall

    # rbp-4 = socket(AF_INET, SOCK_STREAM, 0)
    xor rdx, rdx
    mov rsi, SOCK_STREAM
    mov rdi, AF_INET
    mov rax, sys_socket
    syscall
    mov dword ptr [rbp-4], eax      

    # set value in sockaddr_in
    mov qword ptr [rbp-24], 0
    mov qword ptr [rbp-16], 0
    mov word ptr [rbp-24], AF_INET
    mov edi, dword ptr [rbp-28]
    call htons
    mov word ptr [rbp-22], ax

    # bind(sock_fd, servaddr, 32)
    mov rdx, 32
    lea rsi, [rbp-24]
    mov edi, dword ptr [rbp-4]
    mov rax, sys_bind
    syscall

    # print debugging message
    mov rdx, bind_str_len
    lea rsi, bind_str
    mov rdi, STDOUT
    mov rax, sys_write
    syscall


    # listen(sock_fd, 10)
    mov rsi, 10
    mov edi, dword ptr [rbp-4]
    mov rax, sys_listen
    syscall

    # comm_fd = accept(sock_fd, NULL, NULL)
    xor rdx, rdx
    xor rsi, rsi
    mov edi, dword ptr [rbp-4]
    mov rax, sys_accept
    syscall
    mov dword ptr [rbp-8], eax

    # read(comm_fd, read_buffer, 1024)
    mov rdx, 1024
    lea rsi, read_buffer
    mov edi, dword ptr [rbp-8]
    mov rax, sys_read
    syscall

    # echo buffer
    lea rdi, read_buffer
    call strlen
    mov rdx, rax
    lea rsi, read_buffer
    mov edi, dword ptr [rbp-8]
    mov rax, sys_write
    syscall

    # exit(0)
    mov rdi, 0
    mov rax, sys_exit
    syscall

print_uint:
    push rbp
    mov rbp, rsp

    mov r8, rbp
    sub rsp, 16                 # reserve space for string
    sub r8, 8                   # move away from old rbp
    mov dword ptr [r8], 0       # add terminating null

    # special case for zero
    cmp edi, 0
    jnz .L_print_uint_nzero
    sub r8, 1
    mov dword ptr [r8], 48      # ascii code for zero 
    mov rsi, r8
    mov rdx, 1
    mov rdi, STDOUT
    mov rax, sys_write
    syscall
    leave
    ret 
    .L_print_uint_nzero:

    mov ecx, 10                 # load divisor
    mov eax, edi                # load dividend

    .L_print_uint_loop:
    sub r8, 1                   # make room for next char
    xor edx,edx                 # clear remainder
    div ecx                     # edx:eax / ecx(10) = eax remainder edx
    add edx, 48                 # ascii code 48 = '0'
    mov byte ptr [r8], dl       # save next char on stack
    cmp eax, 0
    jnz .L_print_uint_loop
    
    mov rsi, r8
    mov r9, rbp
    sub r9, r8                  # calc length of number
    mov rdx, r9
    mov rdi, STDOUT
    mov rax, sys_write
    syscall
    
    leave
    ret

htons:
    xor rax, rax
    mov eax, edi
    shl eax, 8
    mov edx, edi
    shr edx, 8
    mov al, dl
    and rax, 0xffff
    ret

strlen:
    xor rcx, rcx
    not rcx
    xor al, al
    cld
    repnz scasb
    not rcx
    lea rax, [rcx-1]
    ret

atoi:
    push rbp
    mov rbp, rsp
    push rbx                # save register

    # get length of string to convert
    push rdi
    call strlen
    pop rdi

    mov rcx, rax            # set loop counter
    sub rax, 1
    add rdi, rax            # move to end of string
    xor r8, r8              # holds result
    mov edx, 1              # holds current power of 10
    mov bl, 10              # used for multiplying
    
    .L_add_loop:
    xor rax, rax            # clear rax
    mov al, byte ptr [rdi]  # load next digit
    mul dl                  # multiply by next power of 10
    add r8, rax             # add to result
    sub rdi, 1              # move left one digit
    mov rax, rdx            # load power of 10 for moving
    mul bl                  # mulitply power of 10
    mov edx, eax            # save new power of 10
    loop .L_add_loop

    mov rax, r8
    pop rbx                 # restore register
    leave
    ret
