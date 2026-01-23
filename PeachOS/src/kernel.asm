[BITS 32]
;   - Tells NASM: assemble this code as 32-bit instructions
;   - Registers like EAX, ESP, EBP are allowed
;   - Instruction encoding changes compared to 16-bit
; ⚠️ This does not switch the CPU into 32-bit mode
; → It only affects how NASM encodes instructions.

global _start
; Makes _start visible to the linker
; _start is the entry symbol of the kernel

CODE_SEG equ 0x08 ; Code segment selector, index 1 in GDT
DATA_SEG equ 0x10 ; Data segment selector, index 2 in GDT

_start:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
; Why this is required
;   In protected mode:
;       Segment registers contain selectors
;       After switching from real mode:
;           Only CS is guaranteed to be valid
;           All other segment registers are undefined
;   So you must reload them.
; What this does
; All these segments now point to the same flat data segment

    mov ebp, 0x00200000
    mov esp, ebp
; Stack base = 0x00200000 (2 MB)
; Stack grows downward

    ; Enable the A20 line
    in al, 0x92
    or al, 2
    out 0x92, al

; What is A20?
;   Originally, the 8086 CPU could only access:
;   1 MB (0x000000 – 0x0FFFFF)
; Address bit 20 was forced to zero, causing wraparound.

; Why enable A20?
;   Without A20:
;       0x100000 → 0x000000  ❌
;   With A20:
;       0x100000 → 0x100000  ✅
;   Since your stack is at 2 MB, A20 must be enabled.

; Why port 0x92?
; This is the Fast A20 Gate:
;   Faster than keyboard controller (0x64)
;   Supported by most modern chipsets

; Bit meaning:
;   bit 1 = A20 enable

    jmp $

times 512-($ - $$) db 0