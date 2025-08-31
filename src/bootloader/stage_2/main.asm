bits 16

section _ENTRY class=CODE

extern _cstart_
extern _puts

global entry

entry:
    cli
    ; setup stack
    mov ax, ds
    mov ss, ax
    mov sp, 0
    mov bp, sp
    sti

    ; expect boot drive in dl, send it as argument to cstart function
    xor dh, dh
    push dx
    call _cstart_

    cli
    hlt

msg_entry: db 'Stage 2 entry point reached', 0x0D, 0x0A, 0