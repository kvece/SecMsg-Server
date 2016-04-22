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

    usage_str:
        .ascii "Usage:\n"
        .ascii "spritz N mode [options]\n\n"
        .ascii "Modes:\n"
        .ascii "  1    encrypt/decrypt (K) (M)\n"
        .ascii "  2    encrypt/decrypt (K) (IV) (M)\n"
        .ascii "  3    hash (r) (M)\n"
        .ascii "  4    mac (K) (r) (M)\n"
        .asciz "  5    prga (s) (N) (offset)\n\n"
    .equ usage_str_len, ($-usage_str-1)

    bad_N_str:
        .asciz "N value supported up to 256 only\n"
    .equ bad_N_str_len, ($-bad_N_str-1)

    bad_file_str:
        .asciz "Unable to open file: "
    .equ bad_file_str_len, ($-bad_file_str-1)
    
    newline_str:
        .asciz "\n"

    i: .int 0
    j: .int 0
    k: .int 0
    z: .int 0
    a: .int 0
    w: .int 1

.bss

    .lcomm data_buffer, 65537
    .lcomm S, 256
    N: .int

.text

_start:

    # setup registers
    push rbp
    mov rbp, rsp

    # check argc (type)
    # 1 = encrypt/decrypt (K, M)
    # 2 = encrypt/decrypt with IV (K, IV, M)
    # 3 = hash (r, M)
    # 4 = mac (K, r, M)
    # 5 = prga (s)
    cmp qword ptr [rbp+8], 2        # check argc for N and type
    jle usage

    mov rdi, [rbp+24]               # N = atoi(argv[1])
    call atoi
    lea rdi, N
    mov [rdi], eax                  

    # check N <= 256
    cmp eax, 256
    jg bad_N

    mov rdi, [rbp+32]               # rax (type) = argv[2][0]
    xor rax, rax
    mov al, [rdi]

    sub rax, 48                     # ascii code for 0

    dec rax
    jz encrypt
    
usage:
    # print usage message
    mov rdx, usage_str_len
    lea rsi, usage_str
    mov rdi, STDOUT
    mov rax, sys_write
    syscall

exit:
    # exit(0)
    mov rdi, 0
    mov rax, sys_exit
    syscall

bad_file:
    # print bad file message
    mov rdx, bad_file_str_len
    lea rsi, bad_file_str
    mov rdi, STDOUT
    mov rax, sys_write
    syscall
    jmp exit
    
bad_N:
    # print bad N message
    mov rdx, bad_N_str_len
    lea rsi, bad_N_str
    mov rdi, STDOUT
    mov rax, sys_write
    syscall
    jmp exit
    
encrypt:

    # key setup
    call initialize_state
    call absorb

    # check if file parameter is specified
    cmp qword ptr [rbp+8], 3
    jg encrypt_with_file


    jmp exit

encrypt_with_file:

    jmp exit

initialize_state:
    lea rdi, S          # dest = S
    mov ecx, N          # count = N
    xor al, al          # i = 0

    .L_state_for:
    stosb
    inc al
    loop .L_state_for
    ret
    
absorb:
    push rbp
    mov rbp, rsp
    push rdi
    push r12

    # rdx = I.length
    mov rdi, [rbp+16]   
    call strlen
    mov rdx, rax

    # r12 = I
    mov r12, [rbp+16]   

    # for v = 0 to I.length-1
    xor rcx, rcx                    # v = 0
    .L_absorb_for:
    xor rax, rax                    # clear contents
    mov al, byte ptr [r12 + rcx]
    mov rdi, rax
    push rcx
    push rdx
    call absorb_byte
    pop rdx
    pop rcx
    inc rcx
    cmp rcx, rdx
    jge .L_absorb_for

    pop r12
    pop rdi
    leave
    ret

absorb_byte:
    push rbp
    mov rbp, rsp
    push rbx

    # get byte in bl, copy to cl
    mov rax, rdi
    xor rbx, rbx
    mov bl, al
    mov cl, bl

    # mask low and high values
    and rcx, 0b1111
    shr rbx, 4
    and rbx, 0b1111

    # absorb_nibble(low)
    mov rdi, rcx
    call absorb_nibble

    # absorb_nibble(high)
    mov rdi, rbx
    call absorb_nibble

    pop rbx
    leave
    ret

absorb_nibble:
    push rbp
    mov rbp, rsp
    push rsi
    push rbx

    # ecx = N/2
    lea rsi, N
    xor rcx, rcx
    mov ecx, dword ptr [rsi]
    shr ecx, 1

    # eax = a
    lea rsi, a
    xor rax, rax
    mov eax, dword ptr [rsi]

    # if (a == N/2) { shuffle }
    cmp eax, ecx
    jne .L_absorb_swap
    push rax
    push rcx
    call shuffle
    pop rcx
    pop rax

    # swap(S[a], S[N/2 + x])
    .L_absorb_swap:
    lea rsi, S
    add rsi, rax
    mov dl, byte ptr [rsi]          # temp = S[a]
    lea r10, S
    add r10, rcx
    add r10, rdi
    mov bl, byte ptr [r10]    
    mov byte ptr [rsi], bl          # S[a] = S[N/2 + x]
    mov byte ptr [r10], dl          # S[N/2 + x] = temp

    # a = a+1
    inc eax
    lea rsi, a
    mov dword ptr [rsi], eax

    pop rbx
    pop rsi
    leave
    ret

absorb_stop:
    push rbp
    mov rbp, rsp
    push rsi
    push rbx

    # ecx = N/2
    lea rsi, N
    xor rcx, rcx
    mov ecx, dword ptr [rsi]
    shr ecx, 1

    # eax = a
    lea rsi, a
    xor rax, rax
    mov eax, dword ptr [rsi]

    # if (a == N/2) { shuffle }
    cmp eax, ecx
    jne .L_absorb_swap
    push rax
    push rcx
    call shuffle
    pop rcx
    pop rax

    # a = a+1
    inc eax
    lea rsi, a
    mov dword ptr [rsi], eax

    pop rbx
    pop rsi

    leave
    ret

shuffle:
    push rbp
    mov rbp, rsp

    # ecx = 2N
    lea rsi, N
    xor rcx, rcx
    mov ecx, dword ptr [rsi]
    shl rcx, 1

    push rcx
    call whip
    call crush
    call whip
    call crush
    call whip
    add esp, 8

    # a = 0
    lea rsi, a
    mov dword ptr [rsi], 0

    leave
    ret

gcd:
    push rbp
    mov rbp, rsp

    # get arguments
    mov rax, [rbp+8]
    mov rdx, [rbp+16]

    # rcx = d = 0
    xor rcx, rcx

    .L_gcd_while_even:          # while (a is even && b is even) {
    mov r8, rax
    and r8, 1
    mov r9, rdx
    and r9, 1
    or r8, r9
    jnz .L_gcd_while_even_done
    shr rax, 1                  #   a /= 2;
    shr rdx, 1                  #   a /= 2;
    inc rcx                     #   d++;
    jmp .L_gcd_while_even
    .L_gcd_while_even_done:     # }

    .L_gcd_while_a_ne_b:        # while (a != b) {
    cmp rax, rdx
    je .L_gcd_while_a_ne_b_done

    .L_gcd_while_if_a_even:
    mov r8, rax
    and r8, 1
    jz .L_gcd_while_if_b_even
    shr rax, 1                  #   if (a is even) a /= 2
    jmp .L_gcd_while_a_ne_b

    .L_gcd_while_if_b_even:
    mov r9, rdx
    and r9, 1
    jz .L_gcd_while_if_a_gt_b
    shr rdx, 1                  #   else if (b is even) b /= 2
    jmp .L_gcd_while_a_ne_b

    .L_gcd_while_if_a_gt_b:
    mov r8, rax
    mov r9, rdx
    cmp r8, r9
    jle .L_gcd_while_else
    sub rax, rdx                #   else if (a > b) a = (a-b)/2
    shr rax, 1
    jmp .L_gcd_while_a_ne_b

    .L_gcd_while_else:
    sub rdx, rax                #   else b = (b-a)/2
    shr rdx, 1
    jmp .L_gcd_while_a_ne_b

    .L_gcd_while_a_ne_b_done:   #}

    # rax *= 2^rcx
    .L_gcd_mul:
    shl rax, 1
    loop .L_gcd_mul
   
    leave
    ret

whip:
    push rbp
    mov rbp, rsp

    # rcx = r
    mov rcx, [rbp + 8]

    .L_whip_for:
    push rcx
    call update
    pop rcx
    loop .L_whip_for

    # rcx = N
    lea rsi, N
    xor rcx, rcx
    mov ecx, dword ptr [rsi]

    # rdx = w
    lea rsi, w
    xor rdx, rdx
    mov edx, dword ptr [rsi]

    .L_whip_do:     # do {
    inc rdx         #   w++;
    push rcx
    push rdx
    call gcd
    pop rdx
    pop rcx
    cmp rax, 1      # } while gcd(w,N) != 1
    jne .L_whip_do

    leave
    ret

crush:
    push rbp
    mov rbp, rsp

    leave
    ret

squeeze:
    push rbp
    mov rbp, rsp

    leave
    ret

drip:
    push rbp
    mov rbp, rsp

    leave
    ret

update:
    push rbp
    mov rbp, rsp

    leave
    ret

output:
    push rbp
    mov rbp, rsp

    leave
    ret
