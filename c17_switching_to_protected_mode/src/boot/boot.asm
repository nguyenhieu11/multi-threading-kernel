ORG 0x7c00 ; Assume the first byte of this file starts at offset 0x7c00 inside SEGMENT
BITS 16

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

_start:
    jmp short start ; Jump to start of code
    nop ; No operation

times 33 db 0 ; This creates 33 bytes of padding

start:
    jmp 0:step2 ; Jump to step2

; https://wiki.osdev.org/Protected_Mode
; https://wiki.osdev.org/Global_Descriptor_Table

step2:
    cli ; Clear Interrupts;
    mov ax, 0x00
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00 ; Stack Pointer = 0x7c00
    sti ; Enables Interrupts

.load_protected:
    cli ; Clear Interrupts
    lgdt[gdt_descriptor] ; Load the GDT
    mov eax, cr0
    or eax, 0x1 ; Set PE bit (Protection Enable)
    mov cr0, eax ; Enter Protected Mode
    jmp CODE_SEG:load32 ; Far jump to clear prefetch queue
                        ; CS = CODE_SEG ( = 0x08, the offset of gdt_code in GDT)

; GDT (Global Descriptor Table)
gdt_start:
gdt_null:      ; Null Descriptor
    dd 0x0
    dd 0x0

; Offset 0x8
gdt_code:     ; CS SHOULD POINT TO THIS
    dw 0xffff ; Segment limit first 0-15 bits
    dw 0      ; Base address bits 0-15
    db 0      ; Base address bits 16-23
    db 0x9a   ; Access byte
    db 11001111b ; High 4 bit flags and the low 4 bit flags
    db 0      ; Base 24-31 bits

; Offset 0x10
gdt_data:     ; DS, SS, ES, FS, GS should point to offset of gdt_data in GDT
    dw 0xffff ; Segment limit first 0-15 bits
    dw 0      ; Base address bits 0-15
    db 0      ; Base address bits 16-23
    db 0x92   ; Access byte
    db 11001111b ; High 4 bit flags and the low 4 bit flags
    db 0      ; Base 24-31 bits

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1 ; Size of GDT - 1
    dd gdt_start                ; Address of GDT

[BITS 32]
load32:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov ebp, 0x00200000
    mov esp, ebp

    ; Enable the A20 line
    in al, 0x92
    or al, 2
    out 0x92, al

    jmp $

times 510-($ - $$) db 0 ; Pad the rest of the boot sector with zeros
dw 0xAA55 ; Boot sector signature
