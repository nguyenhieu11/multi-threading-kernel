ORG 0x7c00
BITS 16

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

_start:
    jmp short start
    nop

 times 33 db 0
 
start:
    jmp 0:step2

step2:
    cli ; Clear Interrupts
    mov ax, 0x00
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti ; Enables Interrupts

.load_protected:
    cli
    lgdt[gdt_descriptor] 
; Important:
;   This does NOT enable protected mode
;   It just tells the CPU where descriptors are

    mov eax, cr0 ; Copies CR0 into EAX so we can modify it
; CR0 is a control register.
; Bit 0  = PE (Protection Enable)
; Bit 31 = PG (Paging)

    or eax, 0x1
    mov cr0, eax
; CPU enters protected mode
; BUT :
;   CS still contains a real-mode segment
;   Prefetch queue still has 16-bit instructions
;   CPU is in an undefined transitional state
; This is why the next instruction must be a far jump.

    jmp CODE_SEG:load32
; This is a far jump, meaning:
;   CS ← CODE_SEG
;   EIP (Extended Instruction Pointer) ← load32

; GDT
gdt_start:
gdt_null:
    dd 0x0
    dd 0x0

; offset 0x8
gdt_code:     ; CS SHOULD POINT TO THIS
    dw 0xffff ; Segment limit first 0-15 bits
    dw 0      ; Base first 0-15 bits
    db 0      ; Base 16-23 bits
    db 0x9a   ; Access byte
    db 11001111b ; High 4 bit flags and the low 4 bit flags
    db 0        ; Base 24-31 bits

; offset 0x10
gdt_data:      ; DS, SS, ES, FS, GS
    dw 0xffff ; Segment limit first 0-15 bits
    dw 0      ; Base first 0-15 bits
    db 0      ; Base 16-23 bits
    db 0x92   ; Access byte
    db 11001111b ; High 4 bit flags and the low 4 bit flags
    db 0        ; Base 24-31 bits

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start-1 ; Limit -> GDTR.limit
    dd gdt_start ; Base -> GDTR.base
 
 [BITS 32]
 load32:
    mov eax, 1
; EAX = LBA (Logical Block Address)
; LBA 0 → boot sector
; LBA 1 → first sector AFTER boot sector
; --> Start reading from disk sector #1

    mov ecx, 100
; ECX = number of sectors to read
; Each sector = 512 bytes
; --> Read 100 sectors = 51200 bytes = 50 KB

    mov edi, 0x0100000
; EDI = destination memory address
; 0x0100000 = 1 MB
; This is:  
;   Above real-mode memory
;   Requires A20 enabled
;   Typical kernel load address
; --> Load the sectors starting at 1 MB

    call ata_lba_read
    jmp CODE_SEG:0x0100000
; CS  = CODE_SEG
; EIP = 0x0100000
; Start executing the kernel I just loaded
; This assumes:
;   Kernel is flat 32-bit
;   Kernel entry point is exactly 0x0100000
;   Kernel expects CS already valid


; This code directly talks to the ATA hard-disk controller (using PIO + LBA28) 
; to read raw disk sectors into RAM, starting at a given LBA, 
; for a given number of sectors, and stores the data sequentially 
; at a memory address you provide.

; Please read N sectors, starting from sector X, using LBA mode, from the master drive

ata_lba_read:
; ATA PIO driver
; This is raw hardware programming.
; No BIOS. No safety nets.

; EAX: LBA start
; ECX: number of sectors to read
; EDI: destination memory address

    mov ebx, eax, ; Backup the LBA
; Why?
;   ATA protocol requires sending LBA in pieces
;   We must reuse the original LBA multiple times
; So: EBX = original LBA

    ; Send the highest 8 bits of the lba to hard disk controller
    shr eax, 24
    or eax, 0xE0 ; Select the  master drive
    mov dx, 0x1F6 ; Port for Drive + LBA bits 24–27
    out dx, al
    ; Finished sending the highest 8 bits of the lba

    ; Send the total sectors to read
    mov eax, ecx
    mov dx, 0x1F2 ; Port for Sector Count
    out dx, al
    ; Finished sending the total sectors to read

    ; Send more bits of the LBA
    mov eax, ebx ; Restore the backup LBA
    mov dx, 0x1F3 ; Port for LBA bits 0–7
    out dx, al
    ; Finished sending more bits of the LBA

    ; Send more bits of the LBA
    mov dx, 0x1F4 ; Port for LBA bits 8–15
    mov eax, ebx ; Restore the backup LBA
    shr eax, 8
    out dx, al
    ; Finished sending more bits of the LBA

    ; Send upper 16 bits of the LBA
    mov dx, 0x1F5 ; Port for LBA bits 16–23
    mov eax, ebx ; Restore the backup LBA
    shr eax, 16
    out dx, al
    ; Finished sending upper 16 bits of the LBA

    mov dx, 0x1f7 ; Command / Status port
    mov al, 0x20
    out dx, al

    ; Read all sectors into memory
.next_sector:
    push ecx

; Checking if we need to read
.try_again:
    mov dx, 0x1f7 ; Command / Status port
    in al, dx
    test al, 8
    jz .try_again

; We need to read 256 words at a time
    mov ecx, 256
    mov dx, 0x1F0 ; Data port
    rep insw
    pop ecx
    loop .next_sector
    ; End of reading sectors into memory
    ret ; End of ata_lba_read

times 510-($ - $$) db 0
dw 0xAA55

; Disk (sectors)
;┌──────────────┐
;│ LBA 1        │ ──┐
;│ LBA 2        │   │
;│ ...          │   │   ATA PIO
;│ LBA 100      │   │   transfers
;└──────────────┘   │
;                   ▼
;RAM
;0x00100000  ← first sector
;0x00100200
;0x00100400
;...