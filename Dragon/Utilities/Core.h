//
//  Core.h
//
//  Created by Project Contributors on 03.08.25.
//

#pragma once


typedef int8_t      int8;
typedef int16_t     int16;
typedef int32_t     int32;
typedef int64_t     int64;
typedef intptr_t    intptr;

typedef uint8_t     uint8;
typedef uint16_t    uint16;
typedef uint32_t    uint32;
typedef uint64_t    uint64;
typedef uintptr_t   uintptr;

#define FORCEINLINE inline __attribute__((always_inline))
#define FORCENOINLINE __attribute__((noinline))
#define RESTRICT __restrict

template <typename T>
FORCEINLINE T&& MoveTemp(T& Obj)
{
    return static_cast<T&&>(Obj);
}

template <typename T>
FORCEINLINE T CopyTemp(T& Val)
{
    return const_cast<const T&>(Val);
}

template <typename T>
FORCEINLINE T CopyTemp(const T& Val)
{
    return Val;
}

template <typename T>
FORCEINLINE T&& CopyTemp(T&& Val)
{
    // If we already have an rvalue, just return it unchanged, rather than needlessly creating yet another rvalue from it.
    return MoveTemp(Val);
}
