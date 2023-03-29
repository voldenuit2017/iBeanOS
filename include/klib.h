/*******************************************************************
*	include/klib.h ( for klib.c and klib.asm )
*Descriptor:
*	The most kernel help functions are decleared here. 
*******************************************************************/

#ifndef _KLIB_H_
#define _KLIB_H_

void disp_str( char *buf );
char *strcpy( char *dst, char *src );
int strlen( char *str );
int vsprintf(char *buf, char *fmt, va_list args);
int printf( char *fmt, ... );
void memset( void *dst, char ch, int size );
void* memcpy( void *dest, void *src, int size );

#endif
