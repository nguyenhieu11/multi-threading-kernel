ORG 0
BITS 16

_start: 
; Just a label, can be removed, but kept for clarity.
; The BIOS does NOT know _start, 
; _start works because:
;   - It is placed at offset 0
;   - BIOS jumps to it implicitly

    jmp short start ; Jump to start of code
    ; Why "short jump" is preferred here:
    ;   - 2 bytes instead of 3 with a near jump "jmp start"
    ;   - This layout matches DOS/BIOS expectations:
    ;     - Jump instruction at byte 0
    ;     - OEM/BPB data begins at byte 3

    nop ; No operation

times 33 db 0 ; This creates 33 bytes of padding
; so the layout becomes:
; Offset  Size  Description
; 0x00    3     JMP + NOP
; 0x03    33    Reserved (OEM / BPB area)
; 0x24    Code continues

; Why BIOS expects this
; Historically:
;   - Boot sectors contained:
;       - Jump instruction
;       - OEM name
;       - BPB (BIOS Parameter Block)
;   - Even if you don’t use FAT, BIOSes still tolerate this layout
; This padding:
;   - Avoids overwriting possible BPB fields
;   - Improves compatibility
;   - Makes your bootloader “filesystem-safe”

start:
    jmp 0x7c0:step2 ; Jump to step2

handle_zero:
    mov ah, 0eh ; BIOS teletype function
    mov al, 'A' ; Character to print on divide by zero
    mov bx, 0x00 ; Page number
    int 0x10 ; Call BIOS interrupt to print character in AL
    iret ; Return from interrupt

step2:
    cli ; Clear Interrupts;
    mov ax, 0x7c0
    mov ds, ax ; Data Segment = 0x7c0
    mov es, ax ; Extra Segment = 0x7c0
    mov ax, 0x00
    mov ss, ax ; Stack Segment = 0x7c0
    mov sp, 0x7c00 ; Stack Pointer = 0x7c00
    sti ; Enables Interrupts

    mov word[ss:0x00], handle_zero ; Set Divide by Zero Exception Handler
    mov word[ss:0x02], 0x7c0 ; Set Code Segment for Handler

    mov ax, 0x00
    div ax ; Trigger Divide by Zero Exception

    mov si, message ; Load address of message into SI
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

message: db 'Hello World!', 0

times 510-($ - $$) db 0 ; Pad the rest of the boot sector with zeros
dw 0xAA55 ; Boot sector signature
