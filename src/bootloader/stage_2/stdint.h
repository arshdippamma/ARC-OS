#ifndef MY_STDINT_H
#define MY_STDINT_H

typedef signed char                 int8_t;
typedef unsigned char               uint8_t;

typedef signed short                int16_t;
typedef unsigned short              uint16_t;

typedef signed long int             int32_t;
typedef unsigned long int           uint32_t;

// Only include 64-bit if compiler supports long long (C99)
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L
typedef signed long long int        int64_t;
typedef unsigned long long int      uint64_t;
#endif

#ifndef __cplusplus
typedef uint8_t bool;

#ifndef true
#define true 1
#endif

#ifndef false
#define false 0
#endif

#endif

#endif
