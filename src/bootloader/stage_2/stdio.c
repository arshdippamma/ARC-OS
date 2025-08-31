#pragma aux puts "_puts"

#include "stdint.h"
#include "stdio.h"

typedef enum {
    LEN_DEFAULT = 0,    // Default length
    LEN_HH,             // Short short
    LEN_H,              // Short
    LEN_L,              // Long
    LEN_LL              // Long long
} Length;

void putc(char c)
{
    // Inline assembly
    __asm {
        mov ah, 0Eh    ; BIOS teletype
        mov al, c      ; Character to print
        xor bh, bh     ; Page 0
        mov bl, 07h    ; Light gray on black
        int 10h        ; BIOS video interrupt
    }
}

void _cdecl puts(const char* str)
{
    while (*str)
    {
        putc(*str);
        str++;
    }
}

static uint32_t divide_u32_by_u16(uint32_t dividend, uint16_t divisor, uint16_t* remainder_ptr)
{
    unsigned shift = 0;
    uint16_t temp = divisor;
    uint16_t dividend_high = 0;
    uint16_t dividend_low = 0;
    uint16_t quotient_high = 0;
    uint16_t quotient_low = 0;
    uint16_t remainder_high = 0;
    uint16_t remainder_low = 0;

    if ((divisor & (divisor - 1)) == 0)
    {
        while (temp >>= 1)
            ++shift;
        
        *remainder_ptr = (uint16_t)(dividend & (divisor - 1));
        
        return dividend >> shift;
    }
    
    dividend_high = (uint16_t)(dividend >> 16);
    dividend_low = (uint16_t)(dividend & 0xFFFF);

    // Inline assembly
    __asm{
        /* quotient_high = dividend_high / divisor
         * remainder_high = dividend_high % divisor */
        mov ax, dividend_high
        xor dx, dx
        mov bx, divisor
        div bx
        mov quotient_high, ax
        mov remainder_high, dx
        

        /* quotient_low = (remainder_high << 16 | dividend_low) / divisor
         * remainder_low = (remainder_high << 16 | dividend_low) % divisor */
        mov ax, dividend_low
        mov dx, remainder_high
        mov bx, divisor
        div bx
        mov quotient_low, ax
        mov remainder_low, dx
    }

    *remainder_ptr = remainder_low;

    return ((uint32_t)quotient_high << 16) | (uint32_t)quotient_low;
}

static void print_unsigned_int_base(uint32_t value, int base)
{
    static const char digits[] = "0123456789abcdef";
    char buffer[33];
    int index = 0;

    if (value == 0)
    {
        putc('0');
        return;
    }

    while (value != 0)
    {
        uint16_t remainder;
        value = divide_u32_by_u16(value, (uint16_t)base, &remainder);
        buffer[index++] = digits[remainder];
    }
    
    while (index--)
    {
        putc(buffer[index]);
    }
}

static uint32_t get_numeric_arg(int** pargp, int len, uint8_t signed_flag)
{
    int* p = *pargp;

    if (len == LEN_L || len == LEN_LL)
    {
        uint32_t low = (uint16_t)p[0];
        uint32_t high = (uint16_t)p[1];
        uint32_t combined = (high << 16) | low;

        if (signed_flag)
        {
            int32_t signed_val = (int32_t)combined;

            if (signed_val < 0)
            {
                putc('-');
                combined = (uint32_t)(-signed_val);
            }
        }
        
        *pargp = p + 2;

        return combined;
    }
    else
    {
        uint16_t unsigned_val_16 = (uint16_t)p[0];

        if (signed_flag)
        {
            int16_t signed_val_16 = (int16_t)unsigned_val_16;

            if (signed_val_16 < 0)
            {
                putc('-');
                unsigned_val_16 = (uint16_t)(-signed_val_16);
            }
        }

        *pargp = p + 1;

        return (uint32_t)unsigned_val_16;
    }
}

static int* printf_num(int* argp, int len, uint8_t sign_flag, int radix)
{
    int* p = argp;
    uint32_t magnitude = get_numeric_arg(&p, len, sign_flag);
    
    print_unsigned_int_base(magnitude, radix);
    
    return p;
}

static Length parse_len(const char** fmtptr)
{
    const char* fmt = *fmtptr;
    Length len = LEN_DEFAULT;

    if (*fmt == 'h')
    {
        fmt++;

        if (*fmt == 'h')
        {
            len = LEN_HH;
            fmt++;
        }
        else
        {
            len = LEN_H;
        }
    }
    else if (*fmt == 'l')
    {
        fmt++;

        if (*fmt == 'l')
        {
            len = LEN_LL;
            fmt++;
        }
        else
        {
            len = LEN_L;
        }
    }

    *fmtptr = fmt;

    return len;
}

static void handle_format_specifier(char specifier, Length len, int** pargp)
{
    int* argp = *pargp;

    switch(specifier)
    {
        case 'c':
            putc((char)(*argp));
            *pargp = argp + 1;
            return;

        case 's':
            puts((const char*)(*argp));
            *pargp = argp + 1;
            return;

        case 'd':
        case 'i':
            *pargp = printf_num(argp, (int)len, 1, 10);
            return;

        case 'u':
            *pargp = printf_num(argp, (int)len, 0, 10);
            return;
        
        case 'x':
        case 'X':
        case 'p':
            *pargp = printf_num(argp, (int)len, 0, 16);
            return;

        case 'o':
            *pargp = printf_num(argp, (int)len, 0, 8);
            return;

        case '%':
            putc('%');
            return;
        
        default:
            return;
    }
}

void _cdecl printf(const char* fmt, ...)
{
    int *argp = (int*)(&fmt + 1);
    Length len;

    while (*fmt)
    {
        if (*fmt != '%')
        {
            putc(*fmt++);
            continue;
        }

        fmt++;

        len = parse_len(&fmt);

        if (*fmt == '\0')
            break;
        
        handle_format_specifier(*fmt, len, &argp);
        fmt++;
    }
}
