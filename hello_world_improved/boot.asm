ORG 0
BITS 16

jmp 0x7c0:start

start:
    cli ; Clear Interrupts;
    mov ax, 0x7c0
    mov ds, ax ; Data Segment = 0x7c0
    mov es, ax ; Extra Segment = 0x7c0
    mov ss, ax ; Stack Segment = 0x7c0
    mov sp, 0x7c00 ; Stack Pointer = 0x7c00
    sti ; Enables Interrupts

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
