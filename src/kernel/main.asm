; Legacy boot

org 0x0         ; Bios located at address 0x7C00, so ORG directive is used to calculate all memory offset starting at address 0x7C00 (it does not change what address the BIOS will be loaded at)
bits 16         ; Assembler needs to emit 16-bit code ()

%define ENDL 0x0D, 0x0A

start:
    ; Print message
    mov si, msg_hello
    call puts

.halt:
    cli
    hlt         ; INSTRUCTION: HLT - stops the CPU from execution

; Prints a string to the screen
; Parameters: 
;   - ds/si points to a string

puts:
    ; Save registers to be modified
    push si     ; INSTRUCTION: PUSH data - "push" data to a stack (LIFO)
    push ax
    push bx

.loop:
    lodsb       ; INSTRUCTION: LODSB - stands for "load string byte" and loads a byte/word/double-word from DS:SI into AL/AX/FAX registers and increments SI by the number of bytes loaded
                ; Essentially loads the next character in AL
    
    or al, al   ; INSTRUCTION: OR destination, source - performs bitwise OR between source and destination and stores result in destination
                ; Using or with destination = source does not modify the value, but does modify the flags in the flags register (if the result is zero, sets the zero flag)

    jz .done    ; INSTRUCTION: JZ destination - Jumps to destination if zero flag is set

    mov ah, 0x0e
    mov bh, 0

    int 0x10

    jmp .loop   ; INSTRUCTION: JMP - jumps to a given location (like goto in C)

.done:
    ; Popping registers from stack
    pop bx
    pop ax
    pop si
    ret

msg_hello: db 'Hello World!', ENDL, 0
