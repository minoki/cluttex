#include "u8crt/u8crt.h"

#undef puts
#define puts u8_puts
#undef fopen
#define fopen u8_fopen
#undef freopen
#define freopen u8_freopen
#undef _popen
#define _popen u8_popen
#undef remove
#define remove u8_remove
#undef rename
#define rename u8_rename
#undef tmpnam
#define tmpnam u8_tmpnam

#undef getenv
#define getenv u8_getenv
#undef _putenv
#define _putenv u8_putenv
#undef system
#define system u8_system

#undef strerror
#define strerror u8_strerror
#undef _mktemp
#define _mktemp u8_mktemp
#undef _findfirst
#define _findfirst u8_findfirst
#undef _findfirst64
#define _findfirst64 u8_findfirst64
#undef _findfirsti64
#define _findfirsti64 u8_findfirsti64
#undef _findfirst64i32
#define _findfirst64i32 u8_findfirst64i32
#undef _findnext
#define _findnext u8_findnext
#undef _findnext64
#define _findnext64 u8_findnext64
#undef _findnexti64
#define _findnexti64 u8_findnexti64
#undef _findnext64i32
#define _findnext64i32 u8_findnext64i32
#ifndef _WIN64
#undef _findfirst32
#define _findfirst32 u8_findfirst32
#undef _findnext32
#define _findnext32 u8_findnext32
#undef _findfirst32i64
#define _findfirst32i64 u8_findfirst32i64
#undef _findnext32i64
#define _findnext32i64 u8_findnext32i64
#endif

#undef _chdir
#define _chdir u8_chdir
#undef _getcwd
#define _getcwd u8_getcwd
#undef _rmdir
#define _rmdir u8_rmdir
#undef _mkdir
#define _mkdir u8_mkdir

#if !defined(_stat)
#error _stat must be an alias for _stat32 or _stat64i32
#endif
#if !defined(_stati64)
#error _stati64 must be an alias for _stat32i64 or _stat64
#endif
#define _stat64(path, buffer) u8_stat64(path, buffer)
#define _stat64i32(path, buffer) u8_stat64i32(path, buffer)
#define _stat32(path, buffer) u8_stat32(path, buffer)
#define _stat32i64(path, buffer) u8_stat32i64(path, buffer)

#ifdef loadlib_c
#include "u8crt/u8winapi.h"
#include <winbase.h>

#undef FormatMessageA
#define FormatMessageA u8_FormatMessage
#undef GetModuleFileNameA
#define GetModuleFileNameA u8_GetModuleFileName
#undef LoadLibraryExA
#define LoadLibraryExA u8_LoadLibraryEx
#endif
// TODO: CreateFile used by lfs.c
