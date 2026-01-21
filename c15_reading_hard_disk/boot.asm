ORG 0
BITS 16

_start:
    jmp short start ; Jump to start of code
    nop ; No operation

times 33 db 0 ; This creates 33 bytes of padding

start:
    jmp 0x7c0:step2 ; Jump to step2

; https://www.ctyme.com/intr/rb-0607.htm
; DISK - READ SECTOR(S) INTO MEMORY
; AH = 02h
; AL = number of sectors to read (must be nonzero)
; CH = low eight bits of cylinder number
; CL = sector number 1-63 (bits 0-5)
; high two bits of cylinder (bits 6-7, hard disk only)
; DH = head number
; DL = drive number (bit 7 set for hard disk)
; ES:BX -> data buffer

; Return:
; CF set on error
; if AH = 11h (corrected ECC error), AL = burst length
; CF clear if successful
; AH = status (see #00234)
; AL = number of sectors transferred (only valid if CF set for some BIOSes)

step2:
    cli ; Clear Interrupts;
    mov ax, 0x7c0
    mov ds, ax ; Data Segment = 0x7c0
    mov es, ax ; Extra Segment = 0x7c0
    mov ax, 0x00
    mov ss, ax ; Stack Segment = 0x0000
    mov sp, 0x7c00 ; Stack Pointer = 0x7c00
    sti ; Enables Interrupts

    mov ah, 2 ; BIOS read sector function
    mov al, 1 ; Read 1 sector
    mov ch, 0 ; Cylinder 0
    mov cl, 2 ; Sector 2
    mov dh, 0 ; Head 0
    ; dont need to set DL because BIOS already set it for us
    mov bx, buffer ; Data buffer to store read data
    int 0x13 ; Call BIOS interrupt to read sector
    jc error ; Jump if carry flag set (error)

    mov si, buffer ; Load address of buffer into SI
    call print

    jmp $

error:
    mov si, error_message ; Load address of error message into SI
    call print
    jmp $

print:
    mov bx, 0
.loop:
    lodsb ; Load byte at DS:SI into AL and increment SI
    cmp al, 0 ; Compare AL with 0 (null terminator)
    je .done ; If zero, jump to done
    call print_char ; Call print_char to print character in AL
    jmp .loop ; Repeat loop
.done:
    ret

print_char:
    mov ah, 0eh ; BIOS teletype function
    int 0x10 ; Call BIOS interrupt to print character in AL
    ret

error_message: db 'Failed to load sector', 0

times 510-($ - $$) db 0 ; Pad the rest of the boot sector with zeros
dw 0xAA55 ; Boot sector signature

buffer: ; Data buffer starts here