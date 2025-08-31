; Legacy boot

org 0x7C00      ; Bios located at address 0x7C00, so ORG directive is used to calculate all memory offset starting at address 0x7C00 (it does not change what address the BIOS will be loaded at)
bits 16         ; Assembler needs to emit 16-bit code ()

%define ENDL 0x0D, 0x0A

; FAT12 Header

jmp short start
nop

bdb_oem:                         db 'MSWIN4.1'              ; 8 bytes
bdb_bytes_per_sector:            dw 512
bdb_sectors_per_cluster:         db 1
bdb_reserved_sectors:            dw 1
bdb_fat_count:                   db 2
bdb_dir_entries_count:           dw 0E0h
bdb_total_sectors:               dw 2880                    ; 2880 * 512 = 1.44 MB
bdb_media_descriptor_type:       db 0F0h                    ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:             dw 9                       ; 9 sectors/fat
bdb_sectors_per_track:           dw 18
bdb_heads:                       dw 2
bdb_hidden_sectors:              dd 0
bdb_large_sector_count:          dd 0

; Extended Boot Record

ebr_drive_number:                db 0                       ; 0x00 = floppy, 0x80 = HDD (this is a useless value)
                                 db 0                       ; Reserved byte
ebr_signature:                   db 29h
ebr_volume_id:                   db 12h, 34h, 56h, 78h      ; Serial number -- value does not matter
ebr_volume_label:                db 'ARC-OS     '           ; 11 bytes padded with spaces
ebr_system_id:                   db 'FAT12   '              ; 8 bytes padded with spaces

start:
    ; Setting up data segments
    mov ax, 0   ; INSTRUCTION: MOV destination, source - copies data from source to destination
                ; Can't write to ds/es directly
    mov ds, ax
    mov es, ax

    ; Setting up stack
    mov ss, ax
    mov sp, 0x7C00      ; Stack grows downwards from where we are loaded in memory

    ; Some BIOSs might start at 07C0:000 instead of 0000:7C00, so we need to make sure we are in the expected location
    push es
    push word .after
    retf

.after:
    ; Read something from floppy disk
    ; BIOS should set DL to drive number
    mov [ebr_drive_number], dl

    ; Show loading message
    mov si, msg_loading
    call puts

    ; Read drive parameters (sectors per track and head count) instead of relying on data from formatted disk
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3F                        ; Remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx     ; Sector count

    inc dh
    mov [bdb_heads], dh                 ; Head count

    ; Read FAT root directory
    ; Compute LBA of root directory = reserved + fats * sectors_per_fat\
    ; Note: This section can be hardcoded
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx                              ; ax = fats * sectors_per_fat
    add ax, [bdb_reserved_sectors]      ; ax = LBA of root directory
    push ax

    ; Compute size of root directory = 32 * number_of_entries / bytes_per_sector
    mov ax, [bdb_dir_entries_count]
    shl ax, 5                           ; ax *= 32
    xor dx, dx                          ; dx = 0
    div word [bdb_bytes_per_sector]     ; Number of sectors to be read

    test dx, dx                         ; if dx != 0, increment by 1
    jz .root_dir_after
    inc ax                              ; If division remainder != 0, increment by 1
                                        ; This means we have a sector that is only partially filled with entries

.root_dir_after:
    ; Read root directory
    mov cl, al                  ; Number of sectors to read = size of root directory
    pop ax                      ; LBA of root directory
    mov dl, [ebr_drive_number]  ; dl = drive number (previously saved)
    mov bx, buffer              ; es:bx = buffer
    call disk_read

    ; Search for stage_2.bin
    xor bx, bx
    mov di, buffer

.search_stage_2:
    mov si, file_stage_2_bin
    mov cx, 11                  ; Compare up to 11 characters
    push di
    repe cmpsb                  ; INSTRUCTION: REPE - shorthand for "repeat while equal"
                                ; Repeats the instruction while the operands are equal (zero flag = 1) or until cx = 0. cx is decremented for each iteration.
                                ; INSTRUCTION: CMPSB - shorthand for "compare string bytes"
                                ; Compares 2 bytes located in memory addresses ds:si and es:di.
                                ; If direction flag = 0 (cleared), si and di are incremented. If direction flag = 1 (set), si and di are decremented.
                                ; The comparison works similarly to the CMP instruction, as a subtraction is performed and the flags are set accordingly
                                ; cmpsv, cmpsd, and smpsq are equivalent for comparing words, double words, and quads
    pop di
    je .found_stage_2

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_stage_2

    ; Stage 2 not found
    jmp stage_2_not_found_error

.found_stage_2:
    ; di should have the address of the entry for the stage 2
    mov ax, [di + 26]                   ; First logical cluster field (offset 26)
    mov [stage_2_cluster], ax

    ; Load FAT into memory from disk
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ; Read stage 2 and process FAT chain
    mov bx, STAGE_2_LOAD_SEGMENT
    mov es, bx
    mov bx, STAGE_2_LOAD_OFFSET

.load_stage_2_loop:
    ; Read next cluster
    mov ax, [stage_2_cluster]
    add ax, 31                         ; first_cluster = (cluster_number - 2) * sectors_per_cluster + start_sector
                                        ; start_sector = reserved + fats + root_directory_size = 1 + 18 + 14 = 33
    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]      ; NOTE: this will overflow if the STAGE_2.BIN file is larger than 64 KiB

    ; Compute location of next cluster
    mov ax, [stage_2_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx                              ; ax = index of entry in FAT, dx = cluster % 2

    mov si, buffer
    add si, ax
    mov ax, [ds:si]                     ; Read entry from FAT table at index ax

    or dx, dx
    jz .even

.odd:
    shr ax, 4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0x0FF8                      ; Check if we have reached the end of the chain
    jae .read_finish

    mov [stage_2_cluster], ax
    jmp .load_stage_2_loop

.read_finish:
    ; Jump to stage 2
    mov dl, [ebr_drive_number]          ; Boot device in dl

    ; Set data registers
    mov ax, STAGE_2_LOAD_SEGMENT
    mov ds, ax
    mov es, ax

    jmp STAGE_2_LOAD_SEGMENT:STAGE_2_LOAD_OFFSET

    ; This should never happen
    jmp wait_key_and_reboot
    cli                                 ; disable interrupts
    hlt                                 ; INSTRUCTION: HLT - stops the CPU from execution

; Prints a string to the screen
; Parameters: 
;   - ds/si - points to a string

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

; Disk Routines

; Converts from Logical Block Addressing (LBA) to Cylinder Head Sector (CHS) Address
; Parameters:
;   - ax - LBA address
; Returns:
;   - cx (bits 0-5) - sector
;   - cx (bits 6-15) - cylinder
;   - dh - head

lba_to_chs:
    push ax
    push dx
    
    ; Sector
    xor dx, dx                              ; dx = 0
    div word [bdb_sectors_per_track]        ; ax = LBA / SectorsPerTrack
                                            ; dx = LBA % SectorsPerTrack
    inc dx                                  ; sector = dx = (LBA % SectorsPerTrack + 1)
    mov cx, dx                              ; cx = sector

    ; Head
    xor dx, dx                              ; dx = 0
    div word [bdb_heads]                    ; cylinder = ax = (LBA / SectorsPerTrack) / Heads
                                            ; head = dx = (LBA / SectorsPerTrack) % Heads
    mov dh, dl                              ; dh = head

    ; Cylinder
    mov ch, al                              ; ch = cylinder (lower 8 bits)

    shl ah, 6                               ; shift left 6 positions
    or cl, ah                               ; put upper 2 bits of cylinder in CL

    pop ax
    mov dl, al                              ; restore DL
    pop ax

    ret

; Reads sectors from a disk
; Parameters:
;   - ax - LBA address
;   - cl - number of sectors to read (up to 128)
;   - dl - drive number
;   - es:bx - memory address where read data is stored

disk_read:
    ; Save registers to be modified
    push ax
    push bx
    push cx
    push dx
    push di

    push cx                                 ; temporarily save CL (number of sectors to read) by pushing to stack
    call lba_to_chs
    pop ax                                  ; AL = number of sectors to read

    mov ah, 02h
    mov di, 3                               ; number of times to retry in an unused register

    .retry:
        pusha                               ; save all registers (we don't know what the bios will modify)
        stc                                 ; set carry flag manually, as some BIOSs don't do this automatically
        int 13h                             ; carry flag cleared = success
        jnc .done                           ; jump if carry flag is not set

        ; Read failure
        popa
        call disk_reset

        dec di
        test di, di
        jnz .retry
    
    ; If all attempts are exhausted
    .fail:
        jmp floppy_error

    .done:
        popa

        ; Restore modified registers
        pop di
        pop dx
        pop cx
        pop bx
        pop ax

        ret

; Error Handlers

floppy_error:
    mov si, msg_read_failure
    call puts
    jmp wait_key_and_reboot

stage_2_not_found_error:
    mov si, msg_stage_2_not_found
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h             ; wait for keystroke
    jmp 0FFFFh:0        ; jump to beginning of BIOS (essentially a reboot)

; If the CPU starts executing beyond the end of the program, it will get caught in this infinite loop

.halt:
    cli                 ; disable interrupts so the CPU can't exit "halt" state
    hlt

; Resets disc controller
; Parameters:
;   - dl - drive number
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    
    ret

msg_loading:            db 'Loading...', ENDL, 0
msg_read_failure:       db 'Read from disk failed.', ENDL, 0
msg_stage_2_not_found:   db 'STAGE_2.BIN not found.', ENDL, 0
file_stage_2_bin:        db 'STAGE_2 BIN'    ; String containing stage_2.bin file name in format expected by FAT
stage_2_cluster:         dw 0

STAGE_2_LOAD_SEGMENT     equ 0x2000      ; We choose where to load the file into memory, and since we are still in 16-bit real mode, we only have access to the lower memory (access to 1 MiB)
                                        ; We choose address 0x2000 based on a memory map, as the area between the bootloader and the EBDA (0x00007E00 to 0x0007FFFF) is the largest 
                                        ; section of memory (~480 KiB) and we are already using some memory at the end of the bootloader to store the FAT, so we also need to leave some
                                        ; extra room there
                                        ; DIRECTIVE: equ - signifies that no memory will be allocated for the constant and will be replaced with the value at assembly time
STAGE_2_LOAD_OFFSET      equ 0

times 510-($-$$) db 0       ; DIRECTIVE: DB byte1, byte2, byte3, ... - stands for "define byte(s)" and writes the given byte(s) to the assembled binary file
                            ; DIRECTIVE: TIMES number instruction/data -  
                            ; $ symbol signifies the memory offset of the current line
                            ; $$ symbol signifies the memory offset of the beginning of the current section (in this case, it is the entire program)
                            ; $-$$ gives the size of the program so far in bytes

dw 0AA55h                   ; DIRECTIVE: DW word1, word2, word3, ... - stands for "define word(s)" and writes the given word(s) (2 byte values encoded in little endian) to the assembled binary file

buffer: