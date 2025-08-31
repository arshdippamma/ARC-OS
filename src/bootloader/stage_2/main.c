//#pragma aux cstart_ "_cstart_"

#include "stdint.h"
#include "stdio.h"

void _cdecl cstart_(uint16_t bootDrive)
{
    const char far* far_str = "far string";

    puts("Hello world from C!\r\n");
    
    printf("Formatted %% %c %s %ls\r\n", 'a', "string", far_str);
    printf("Formatted %d %i %x %p %o %hd %hi %hhu %hhd\r\n", 1234, -5678, 0x1234, (void*)0x4321, 012345, (short)27, (short)-42, (unsigned char)20, (signed char)-10);
    printf("Formatted %ld %lx %lld %llx\r\n", -100000000l, 0x12345678ul, 9876543210ll, 0x123456789abcdefull);
    
    for(;;);
}
