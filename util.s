.intel_syntax noprefix

# EXPORTS
.globl print_uint
.globl htons
.globl strlen
.globl atoi

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

.text

print_uint:
    push rbp
    mov rbp, rsp

    mov r8, rbp                 # r8 will hold the string ptr
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
    sub r9, 8                   # remove space for old rbp
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
    mov ebx, 1              # holds current power of 10
    
    .L_add_loop:
    xor rax, rax            # clear rax
    mov al, byte ptr [rdi]  # load next digit
    sub al, 48              # convert from ascii
    mul bx                  # multiply by next power of 10
    shl edx, 16             # move top half over
    xor eax, edx            # add top half into result
    add r8, rax             # add to result
    sub rdi, 1              # move left one digit
    mov ax, bx              # load power of 10 for moving
    mov dx, 10              # used for multiplying
    mul dx                  # mulitply power of 10
    mov bx, ax              # save new power of 10
    shl edx, 16             # move top half over
    xor ebx, edx            # add to saved power of 10
    loop .L_add_loop

    mov rax, r8
    pop rbx                 # restore register
    leave
    ret

