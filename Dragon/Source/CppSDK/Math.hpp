#pragma once

#include <cmath>

#include "UnrealContainers.hpp"

#undef  PI
#define PI                     (3.1415926535897932f)    /* Extra digits if needed: 3.1415926535897932384626433832795f */
#define SMALL_NUMBER        (1.e-8f)
#define KINDA_SMALL_NUMBER    (1.e-4f)
#define BIG_NUMBER            (3.4e+38f)
#define EULERS_NUMBER       (2.71828182845904523536f)
#define UE_GOLDEN_RATIO        (1.6180339887498948482045868343656381f)    /* Also known as divine proportion, golden mean, or golden section - related to the Fibonacci Sequence = (1 + sqrt(5)) / 2 */
#define FLOAT_NON_FRACTIONAL (8388608.f) /* All single-precision floating point numbers greater than or equal to this have no fractional value. */

// Copied from float.h
#define MAX_FLT 3.402823466e+38F

// Aux constants.
#define INV_PI            (0.31830988618f)
#define HALF_PI            (1.57079632679f)

// Common square roots
#define UE_SQRT_2        (1.4142135623730950488016887242097f)
#define UE_SQRT_3        (1.7320508075688772935274463415059f)
#define UE_INV_SQRT_2    (0.70710678118654752440084436210485f)
#define UE_INV_SQRT_3    (0.57735026918962576450914878050196f)
#define UE_HALF_SQRT_2    (0.70710678118654752440084436210485f)
#define UE_HALF_SQRT_3    (0.86602540378443864676372317075294f)


// Magic numbers for numerical precision.
#define DELTA            (0.00001f)

/**
 * Lengths of normalized vectors (These are half their maximum values
 * to assure that dot products with normalized vectors don't overflow).
 */
#define FLOAT_NORMAL_THRESH                (0.0001f)

//
// Magic numbers for numerical precision.
//
#define THRESH_POINT_ON_PLANE            (0.10f)        /* Thickness of plane for front/back/inside test */
#define THRESH_POINT_ON_SIDE            (0.20f)        /* Thickness of polygon side's side-plane for point-inside/outside/on side test */
#define THRESH_POINTS_ARE_SAME            (0.00002f)    /* Two points are same if within this distance */
#define THRESH_POINTS_ARE_NEAR            (0.015f)    /* Two points are near if within this distance and can be combined if imprecise math is ok */
#define THRESH_NORMALS_ARE_SAME            (0.00002f)    /* Two normal points are same if within this distance */
#define THRESH_UVS_ARE_SAME                (0.0009765625f)/* Two UV are same if within this threshold (1.0f/1024f) */
                                                    /* Making this too large results in incorrect CSG classification and disaster */
#define THRESH_VECTORS_ARE_NEAR            (0.0004f)    /* Two vectors are near if within this distance and can be combined if imprecise math is ok */
                                                    /* Making this too large results in lighting problems due to inaccurate texture coordinates */
#define THRESH_SPLIT_POLY_WITH_PLANE    (0.25f)        /* A plane splits a polygon in half */
#define THRESH_SPLIT_POLY_PRECISELY        (0.01f)        /* A plane exactly splits a polygon */
#define THRESH_ZERO_NORM_SQUARED        (0.0001f)    /* Size of a unit normal that is considered "zero", squared */
#define THRESH_NORMALS_ARE_PARALLEL        (0.999845f)    /* Two unit vectors are parallel if abs(A dot B) is greater than or equal to this. This is roughly cosine(1.0 degrees). */
#define THRESH_NORMALS_ARE_ORTHOGONAL    (0.017455f)    /* Two unit vectors are orthogonal (perpendicular) if abs(A dot B) is less than or equal this. This is roughly cosine(89.0 degrees). */

#define THRESH_VECTOR_NORMALIZED        (0.01f)        /** Allowed error for a normalized vector (against squared magnitude) */
#define THRESH_QUAT_NORMALIZED            (0.01f)        /** Allowed error for a normalized quaternion (against squared magnitude) */


/**
 * Generic implementation for most platforms
 */
struct FGenericPlatformMath
{
    //https://gist.github.com/rygorous/2156668
    static FORCEINLINE float LoadHalf(const uint16* Ptr)
    {
        uint16 FP16 = *Ptr;
        uint32 shifted_exp = 0x7c00 << 13;            // exponent mask after shift
        union FP32T
        {
            uint32 u;
            float f;
        } FP32, magic = { 113 << 23 };

        FP32.u = (FP16 & 0x7fff) << 13;                // exponent/mantissa bits
        uint32 exp = shifted_exp & FP32.u;            // just the exponent
        FP32.u += uint32(127 - 15) << 23;            // exponent adjust

        // handle exponent special cases
        if (exp == shifted_exp)                        // Inf/NaN?
        {
            FP32.u += uint32(128 - 16) << 23;        // extra exp adjust
        }
        else if (exp == 0)                            // Zero/Denormal?
        {
            FP32.u += 1 << 23;                        // extra exp adjust
            FP32.f -= magic.f;                        // renormalize
        }

        FP32.u |= (FP16 & 0x8000) << 16;            // sign bit
        return FP32.f;
    }

    //https://gist.github.com/rygorous/2156668
    static FORCEINLINE void StoreHalf(uint16* Ptr, float Value)
    {
        union FP32T
        {
            uint32 u;
            float f;
        } FP32 = {};
        uint16 FP16 = {};

        FP32.f = Value;

        FP32T f32infty = { uint32(255 << 23) };
        FP32T f16max = { uint32(127 + 16) << 23 };
        FP32T denorm_magic = { (uint32(127 - 15) + uint32(23 - 10) + 1) << 23 };
        uint32 sign_mask = 0x80000000u;

        uint32 sign = FP32.u & sign_mask;
        FP32.u ^= sign;

        // NOTE all the integer compares in this function can be safely
        // compiled into signed compares since all operands are below
        // 0x80000000. Important if you want fast straight SSE2 code
        // (since there's no unsigned PCMPGTD).

        if (FP32.u >= f16max.u) // result is Inf or NaN (all exponent bits set)
        {
            FP16 = (FP32.u > f32infty.u) ? 0x7e00 : 0x7c00; // NaN->qNaN and Inf->Inf
        }
        else // (De)normalized number or zero
        {
            if (FP32.u < uint32(113 << 23)) // resulting FP16 is subnormal or zero
            {
                // use a magic value to align our 10 mantissa bits at the bottom of
                // the float. as long as FP addition is round-to-nearest-even this
                // just works.
                FP32.f += denorm_magic.f;

                // and one integer subtract of the bias later, we have our final float!
                FP16 = uint16(FP32.u - denorm_magic.u);
            }
            else
            {
                uint32 mant_odd = (FP32.u >> 13) & 1; // resulting mantissa is odd

                // update exponent, rounding bias part 1
                FP32.u += (uint32(15 - 127) << 23) + 0xfff;
                // rounding bias part 2
                FP32.u += mant_odd;
                // take the bits!
                FP16 = uint16(FP32.u >> 13);
            }
        }

        FP16 |= sign >> 16;
        *Ptr = FP16;
    }

    static FORCEINLINE void VectorLoadHalf(float* RESTRICT Dst, const uint16* RESTRICT Src)
    {
        Dst[0] = LoadHalf(&Src[0]);
        Dst[1] = LoadHalf(&Src[1]);
        Dst[2] = LoadHalf(&Src[2]);
        Dst[3] = LoadHalf(&Src[3]);
    }

    static FORCEINLINE void VectorStoreHalf(uint16* RESTRICT Dst, const float* RESTRICT Src)
    {
        StoreHalf(&Dst[0], Src[0]);
        StoreHalf(&Dst[1], Src[1]);
        StoreHalf(&Dst[2], Src[2]);
        StoreHalf(&Dst[3], Src[3]);
    }

    static FORCEINLINE void WideVectorLoadHalf(float* RESTRICT Dst, const uint16* RESTRICT Src)
    {
        VectorLoadHalf(Dst, Src);
        VectorLoadHalf(Dst + 4, Src + 4);
    }

    static FORCEINLINE void WideVectorStoreHalf(uint16* RESTRICT Dst, const float* RESTRICT Src)
    {
        VectorStoreHalf(Dst, Src);
        VectorStoreHalf(Dst + 4, Src + 4);
    }

    /**
     * Converts a float to an integer with truncation towards zero.
     * @param F        Floating point value to convert
     * @return        Truncated integer.
     */
    static constexpr FORCEINLINE int32 TruncToInt(float F)
    {
        return (int32_t)F;
    }

    /**
     * Converts a float to an integer value with truncation towards zero.
     * @param F        Floating point value to convert
     * @return        Truncated integer value.
     */
    static FORCEINLINE float TruncToFloat(float F)
    {
        return truncf(F);
    }

    /**
     * Converts a double to an integer value with truncation towards zero.
     * @param F        Floating point value to convert
     * @return        Truncated integer value.
     */
    static FORCEINLINE double TruncToDouble(double F)
    {
        return trunc(F);
    }

    /**
     * Converts a float to a nearest less or equal integer.
     * @param F        Floating point value to convert
     * @return        An integer less or equal to 'F'.
     */
    static FORCEINLINE int32 FloorToInt(float F)
    {
        return TruncToInt(floorf(F));
    }

    /**
    * Converts a float to the nearest less or equal integer.
    * @param F        Floating point value to convert
    * @return        An integer less or equal to 'F'.
    */
    static FORCEINLINE float FloorToFloat(float F)
    {
        return floorf(F);
    }

    /**
    * Converts a double to a less or equal integer.
    * @param F        Floating point value to convert
    * @return        The nearest integer value to 'F'.
    */
    static FORCEINLINE double FloorToDouble(double F)
    {
        return floor(F);
    }

    /**
     * Converts a float to the nearest integer. Rounds up when the fraction is .5
     * @param F        Floating point value to convert
     * @return        The nearest integer to 'F'.
     */
    static FORCEINLINE int32 RoundToInt(float F)
    {
        return FloorToInt(F + 0.5f);
    }

    /**
    * Converts a float to the nearest integer. Rounds up when the fraction is .5
    * @param F        Floating point value to convert
    * @return        The nearest integer to 'F'.
    */
    static FORCEINLINE float RoundToFloat(float F)
    {
        return FloorToFloat(F + 0.5f);
    }

    /**
    * Converts a double to the nearest integer. Rounds up when the fraction is .5
    * @param F        Floating point value to convert
    * @return        The nearest integer to 'F'.
    */
    static FORCEINLINE double RoundToDouble(double F)
    {
        return FloorToDouble(F + 0.5);
    }

    /**
    * Converts a float to the nearest greater or equal integer.
    * @param F        Floating point value to convert
    * @return        An integer greater or equal to 'F'.
    */
    static FORCEINLINE int32 CeilToInt(float F)
    {
        return TruncToInt(ceilf(F));
    }

    /**
    * Converts a float to the nearest greater or equal integer.
    * @param F        Floating point value to convert
    * @return        An integer greater or equal to 'F'.
    */
    static FORCEINLINE float CeilToFloat(float F)
    {
        return ceilf(F);
    }

    /**
    * Converts a double to the nearest greater or equal integer.
    * @param F        Floating point value to convert
    * @return        An integer greater or equal to 'F'.
    */
    static FORCEINLINE double CeilToDouble(double F)
    {
        return ceil(F);
    }

    /**
    * Returns signed fractional part of a float.
    * @param Value    Floating point value to convert
    * @return        A float between >=0 and < 1 for nonnegative input. A float between >= -1 and < 0 for negative input.
    */
    static FORCEINLINE float Fractional(float Value)
    {
        return Value - TruncToFloat(Value);
    }

    /**
    * Returns the fractional part of a float.
    * @param Value    Floating point value to convert
    * @return        A float between >=0 and < 1.
    */
    static FORCEINLINE float Frac(float Value)
    {
        return Value - FloorToFloat(Value);
    }

    /**
    * Breaks the given value into an integral and a fractional part.
    * @param InValue    Floating point value to convert
    * @param OutIntPart Floating point value that receives the integral part of the number.
    * @return            The fractional part of the number.
    */
    static FORCEINLINE float Modf(const float InValue, float* OutIntPart)
    {
        return modff(InValue, OutIntPart);
    }

    /**
    * Breaks the given value into an integral and a fractional part.
    * @param InValue    Floating point value to convert
    * @param OutIntPart Floating point value that receives the integral part of the number.
    * @return            The fractional part of the number.
    */
    static FORCEINLINE double Modf(const double InValue, double* OutIntPart)
    {
        return modf(InValue, OutIntPart);
    }

    // Returns e^Value
    static FORCEINLINE float Exp( float Value ) { return expf(Value); }
    // Returns 2^Value
    static FORCEINLINE float Exp2( float Value ) { return powf(2.f, Value); /*exp2f(Value);*/ }
    static FORCEINLINE float Loge( float Value ) {    return logf(Value); }
    static FORCEINLINE float LogX( float Base, float Value ) { return Loge(Value) / Loge(Base); }
    // 1.0 / Loge(2) = 1.4426950f
    static FORCEINLINE float Log2( float Value ) { return Loge(Value) * 1.4426950f; }

    /**
    * Returns the floating-point remainder of X / Y
    * Warning: Always returns remainder toward 0, not toward the smaller multiple of Y.
    *            So for example Fmod(2.8f, 2) gives .8f as you would expect, however, Fmod(-2.8f, 2) gives -.8f, NOT 1.2f
    * Use Floor instead when snapping positions that can be negative to a grid
    *
    * This is forced to *NOT* inline so that divisions by constant Y does not get optimized in to an inverse scalar multiply,
    * which is not consistent with the intent nor with the vectorized version.
    */
    static FORCENOINLINE float Fmod(float X, float Y); // Imp

    static FORCEINLINE float Sin( float Value ) { return sinf(Value); }
    static FORCEINLINE float Asin( float Value ) { return asinf( (Value<-1.f) ? -1.f : ((Value<1.f) ? Value : 1.f) ); }
    static FORCEINLINE float Sinh(float Value) { return sinhf(Value); }
    static FORCEINLINE float Cos( float Value ) { return cosf(Value); }
    static FORCEINLINE float Acos( float Value ) { return acosf( (Value<-1.f) ? -1.f : ((Value<1.f) ? Value : 1.f) ); }
    static FORCEINLINE float Tan( float Value ) { return tanf(Value); }
    static FORCEINLINE float Atan( float Value ) { return atanf(Value); }
    static float Atan2( float Y, float X ); // Imp
    static FORCEINLINE float Sqrt( float Value ) { return sqrtf(Value); }
    static FORCEINLINE float Hypot( float A, float B ) { return hypot(A, B); }
    static FORCEINLINE float Pow( float A, float B ) { return powf(A,B); }

    /** Computes a fully accurate inverse square root */
    static FORCEINLINE float InvSqrt( float F )
    {
        return 1.0f / sqrtf( F );
    }

    /** Computes a faster but less accurate inverse square root */
    static FORCEINLINE float InvSqrtEst( float F )
    {
        return InvSqrt( F );
    }

    /** Return true if value is NaN (not a number). */
    static FORCEINLINE bool IsNaN( float A )
    {
        return ((*(uint32*)&A) & 0x7FFFFFFFU) > 0x7F800000U;
    }
    static FORCEINLINE bool IsNaN(double A)
    {
        return ((*(uint64*)&A) & 0x7FFFFFFFFFFFFFFFULL) > 0x7FF0000000000000ULL;
    }

    /** Return true if value is finite (not NaN and not Infinity). */
    static FORCEINLINE bool IsFinite( float A )
    {
        return ((*(uint32*)&A) & 0x7F800000U) != 0x7F800000U;
    }
    static FORCEINLINE bool IsFinite(double A)
    {
        return ((*(uint64*)&A) & 0x7FF0000000000000ULL) != 0x7FF0000000000000ULL;
    }

    static FORCEINLINE bool IsNegativeFloat(float A)
    {
        return ( (*(uint32*)&A) >= (uint32)0x80000000 ); // Detects sign bit.
    }

    static FORCEINLINE bool IsNegativeDouble(double A)
    {
        return ( (*(uint64*)&A) >= (uint64)0x8000000000000000 ); // Detects sign bit.
    }

    /** Returns a random integer between 0 and RAND_MAX, inclusive */
    static FORCEINLINE int32 Rand() { return rand(); }

    /** Seeds global random number functions Rand() and FRand() */
    static FORCEINLINE void RandInit(int32 Seed) { srand( Seed ); }

    /** Returns a random float between 0 and 1, inclusive. */
    static FORCEINLINE float FRand()
    {
        // FP32 mantissa can only represent 24 bits before losing precision
        constexpr int32_t RandMax = 0x00ffffff < RAND_MAX ? 0x00ffffff : RAND_MAX;
        return (Rand() & RandMax) / (float)RandMax;
    }

    /** Seeds future calls to SRand() */
    static void SRandInit( int32 Seed );

    /** Returns the current seed for SRand(). */
    static int32 GetRandSeed();

    /** Returns a seeded random float in the range [0,1), using the seed from SRandInit(). */
    static float SRand();

    /**
     * Computes the base 2 logarithm for an integer value that is greater than 0.
     * The result is rounded down to the nearest integer.
     *
     * @param Value        The value to compute the log of
     * @return            Log2 of Value. 0 if Value is 0.
     */
    static FORCEINLINE uint32 FloorLog2(uint32 Value)
    {
/*        // reference implementation
        // 1500ms on test data
        uint32 Bit = 32;
        for (; Bit > 0;)
        {
            Bit--;
            if (Value & (1<<Bit))
            {
                break;
            }
        }
        return Bit;
*/
        // same output as reference

        // see http://codinggorilla.domemtech.com/?p=81 or http://en.wikipedia.org/wiki/Binary_logarithm but modified to return 0 for a input value of 0
        // 686ms on test data
        uint32 pos = 0;
        if (Value >= 1<<16) { Value >>= 16; pos += 16; }
        if (Value >= 1<< 8) { Value >>=  8; pos +=  8; }
        if (Value >= 1<< 4) { Value >>=  4; pos +=  4; }
        if (Value >= 1<< 2) { Value >>=  2; pos +=  2; }
        if (Value >= 1<< 1) {                pos +=  1; }
        return (Value == 0) ? 0 : pos;

        // even faster would be method3 but it can introduce more cache misses and it would need to store the table somewhere
        // 304ms in test data
        /*int LogTable256[256];

        void prep()
        {
            LogTable256[0] = LogTable256[1] = 0;
            for (int i = 2; i < 256; i++)
            {
                LogTable256[i] = 1 + LogTable256[i / 2];
            }
            LogTable256[0] = -1; // if you want log(0) to return -1
        }

        int _forceinline method3(uint32 v)
        {
            int r;     // r will be lg(v)
            uint32 tt; // temporaries

            if ((tt = v >> 24) != 0)
            {
                r = (24 + LogTable256[tt]);
            }
            else if ((tt = v >> 16) != 0)
            {
                r = (16 + LogTable256[tt]);
            }
            else if ((tt = v >> 8 ) != 0)
            {
                r = (8 + LogTable256[tt]);
            }
            else
            {
                r = LogTable256[v];
            }
            return r;
        }*/
    }

    /**
     * Computes the base 2 logarithm for a 64-bit value that is greater than 0.
     * The result is rounded down to the nearest integer.
     *
     * @param Value        The value to compute the log of
     * @return            Log2 of Value. 0 if Value is 0.
     */
    static FORCEINLINE uint64 FloorLog2_64(uint64 Value)
    {
        uint64 pos = 0;
        if (Value >= 1ull<<32) { Value >>= 32; pos += 32; }
        if (Value >= 1ull<<16) { Value >>= 16; pos += 16; }
        if (Value >= 1ull<< 8) { Value >>=  8; pos +=  8; }
        if (Value >= 1ull<< 4) { Value >>=  4; pos +=  4; }
        if (Value >= 1ull<< 2) { Value >>=  2; pos +=  2; }
        if (Value >= 1ull<< 1) {                pos +=  1; }
        return (Value == 0) ? 0 : pos;
    }

    /**
     * Counts the number of leading zeros in the bit representation of the 8-bit value
     *
     * @param Value the value to determine the number of leading zeros for
     *
     * @return the number of zeros before the first "on" bit
     */
    static FORCEINLINE uint8 CountLeadingZeros8(uint8 Value)
    {
        if (Value == 0) return 8;
        return uint8(7 - FloorLog2(uint32(Value)));
    }

    /**
     * Counts the number of leading zeros in the bit representation of the 32-bit value
     *
     * @param Value the value to determine the number of leading zeros for
     *
     * @return the number of zeros before the first "on" bit
     */
    static FORCEINLINE uint32 CountLeadingZeros(uint32 Value)
    {
        if (Value == 0) return 32;
        return 31 - FloorLog2(Value);
    }

    /**
     * Counts the number of leading zeros in the bit representation of the 64-bit value
     *
     * @param Value the value to determine the number of leading zeros for
     *
     * @return the number of zeros before the first "on" bit
     */
    static FORCEINLINE uint64 CountLeadingZeros64(uint64 Value)
    {
        if (Value == 0) return 64;
        return 63 - FloorLog2_64(Value);
    }

    /**
     * Counts the number of trailing zeros in the bit representation of the value
     *
     * @param Value the value to determine the number of trailing zeros for
     *
     * @return the number of zeros after the last "on" bit
     */
    static FORCEINLINE uint32 CountTrailingZeros(uint32 Value)
    {
        if (Value == 0)
        {
            return 32;
        }
        uint32 Result = 0;
        while ((Value & 1) == 0)
        {
            Value >>= 1;
            ++Result;
        }
        return Result;
    }

    /**
     * Counts the number of trailing zeros in the bit representation of the value
     *
     * @param Value the value to determine the number of trailing zeros for
     *
     * @return the number of zeros after the last "on" bit
     */
    static FORCEINLINE uint64 CountTrailingZeros64(uint64 Value)
    {
        if (Value == 0)
        {
            return 64;
        }
        uint64 Result = 0;
        while ((Value & 1) == 0)
        {
            Value >>= 1;
            ++Result;
        }
        return Result;
    }

    /**
     * Returns smallest N such that (1<<N)>=Arg.
     * Note: CeilLogTwo(0)=0 because (1<<0)=1 >= 0.
     */
    static FORCEINLINE uint32 CeilLogTwo( uint32 Arg )
    {
        int32 Bitmask = ((int32)(CountLeadingZeros(Arg) << 26)) >> 31;
        return (32 - CountLeadingZeros(Arg - 1)) & (~Bitmask);
    }

    static FORCEINLINE uint64 CeilLogTwo64( uint64 Arg )
    {
        int64 Bitmask = ((int64)(CountLeadingZeros64(Arg) << 57)) >> 63;
        return (64 - CountLeadingZeros64(Arg - 1)) & (~Bitmask);
    }

    /** @return Rounds the given number up to the next highest power of two. */
    static FORCEINLINE uint32 RoundUpToPowerOfTwo(uint32 Arg)
    {
        return 1 << CeilLogTwo(Arg);
    }

    static FORCEINLINE uint64 RoundUpToPowerOfTwo64(uint64 V)
    {
        return uint64(1) << CeilLogTwo64(V);
    }

    /** Spreads bits to every other. */
    static FORCEINLINE uint32 MortonCode2( uint32 x )
    {
        x &= 0x0000ffff;
        x = (x ^ (x << 8)) & 0x00ff00ff;
        x = (x ^ (x << 4)) & 0x0f0f0f0f;
        x = (x ^ (x << 2)) & 0x33333333;
        x = (x ^ (x << 1)) & 0x55555555;
        return x;
    }

    static FORCEINLINE uint64 MortonCode2_64( uint64 x )
    {
        x &= 0x00000000ffffffff;
        x = (x ^ (x << 16)) & 0x0000ffff0000ffff;
        x = (x ^ (x << 8)) & 0x00ff00ff00ff00ff;
        x = (x ^ (x << 4)) & 0x0f0f0f0f0f0f0f0f;
        x = (x ^ (x << 2)) & 0x3333333333333333;
        x = (x ^ (x << 1)) & 0x5555555555555555;
        return x;
    }

    /** Reverses MortonCode2. Compacts every other bit to the right. */
    static FORCEINLINE uint32 ReverseMortonCode2( uint32 x )
    {
        x &= 0x55555555;
        x = (x ^ (x >> 1)) & 0x33333333;
        x = (x ^ (x >> 2)) & 0x0f0f0f0f;
        x = (x ^ (x >> 4)) & 0x00ff00ff;
        x = (x ^ (x >> 8)) & 0x0000ffff;
        return x;
    }

    static FORCEINLINE uint64 ReverseMortonCode2_64( uint64 x )
    {
        x &= 0x5555555555555555;
        x = (x ^ (x >> 1)) & 0x3333333333333333;
        x = (x ^ (x >> 2)) & 0x0f0f0f0f0f0f0f0f;
        x = (x ^ (x >> 4)) & 0x00ff00ff00ff00ff;
        x = (x ^ (x >> 8)) & 0x0000ffff0000ffff;
        x = (x ^ (x >> 16)) & 0x00000000ffffffff;
        return x;
    }

    /** Spreads bits to every 3rd. */
    static FORCEINLINE uint32 MortonCode3( uint32 x )
    {
        x &= 0x000003ff;
        x = (x ^ (x << 16)) & 0xff0000ff;
        x = (x ^ (x <<  8)) & 0x0300f00f;
        x = (x ^ (x <<  4)) & 0x030c30c3;
        x = (x ^ (x <<  2)) & 0x09249249;
        return x;
    }

    /** Reverses MortonCode3. Compacts every 3rd bit to the right. */
    static FORCEINLINE uint32 ReverseMortonCode3( uint32 x )
    {
        x &= 0x09249249;
        x = (x ^ (x >>  2)) & 0x030c30c3;
        x = (x ^ (x >>  4)) & 0x0300f00f;
        x = (x ^ (x >>  8)) & 0xff0000ff;
        x = (x ^ (x >> 16)) & 0x000003ff;
        return x;
    }

    /**
     * Returns value based on comparand. The main purpose of this function is to avoid
     * branching based on floating point comparison which can be avoided via compiler
     * intrinsics.
     *
     * Please note that we don't define what happens in the case of NaNs as there might
     * be platform specific differences.
     *
     * @param    Comparand        Comparand the results are based on
     * @param    ValueGEZero        Return value if Comparand >= 0
     * @param    ValueLTZero        Return value if Comparand < 0
     *
     * @return    ValueGEZero if Comparand >= 0, ValueLTZero otherwise
     */
    static constexpr FORCEINLINE float FloatSelect( float Comparand, float ValueGEZero, float ValueLTZero )
    {
        return Comparand >= 0.f ? ValueGEZero : ValueLTZero;
    }

    /**
     * Returns value based on comparand. The main purpose of this function is to avoid
     * branching based on floating point comparison which can be avoided via compiler
     * intrinsics.
     *
     * Please note that we don't define what happens in the case of NaNs as there might
     * be platform specific differences.
     *
     * @param    Comparand        Comparand the results are based on
     * @param    ValueGEZero        Return value if Comparand >= 0
     * @param    ValueLTZero        Return value if Comparand < 0
     *
     * @return    ValueGEZero if Comparand >= 0, ValueLTZero otherwise
     */
    static constexpr FORCEINLINE double FloatSelect( double Comparand, double ValueGEZero, double ValueLTZero )
    {
        return Comparand >= 0.f ? ValueGEZero : ValueLTZero;
    }

    /** Computes absolute value in a generic way */
    template< class T >
    static constexpr FORCEINLINE T Abs( const T A )
    {
        return (A>=(T)0) ? A : -A;
    }

    /** Returns 1, 0, or -1 depending on relation of T to 0 */
    template< class T >
    static constexpr FORCEINLINE T Sign( const T A )
    {
        return (A > (T)0) ? (T)1 : ((A < (T)0) ? (T)-1 : (T)0);
    }

    /** Returns higher value in a generic way */
    template< class T >
    static constexpr FORCEINLINE T Max( const T A, const T B )
    {
        return (A>=B) ? A : B;
    }

    /** Returns lower value in a generic way */
    template< class T >
    static constexpr FORCEINLINE T Min( const T A, const T B )
    {
        return (A<=B) ? A : B;
    }

    /**
    * Min of Array
    * @param    Values Array of templated type
    * @param    MinIndex Optional pointer for returning the index of the minimum element, if multiple minimum elements the first index is returned
    * @return    The min value found in the array or default value if the array was empty
    */
    template< class T >
    static FORCEINLINE T Min(const TArray<T>& Values, int32* MinIndex = NULL)
    {
        if (Values.Num() == 0)
        {
            if (MinIndex)
            {
                *MinIndex = -1;
            }
            return T();
        }

        T CurMin = Values[0];
        int32 CurMinIndex = 0;
        for (int32 v = 1; v < Values.Num(); ++v)
        {
            const T Value = Values[v];
            if (Value < CurMin)
            {
                CurMin = Value;
                CurMinIndex = v;
            }
        }

        if (MinIndex)
        {
            *MinIndex = CurMinIndex;
        }
        return CurMin;
    }

    /**
    * Max of Array
    * @param   Values  Array of templated type
    * @param    MaxIndex Optional pointer for returning the index of the maximum element, if multiple maximum elements the first index is returned
    * @return    The max value found in the array or default value if the array was empty
    */
    template< class T >
    static FORCEINLINE T Max(const TArray<T>& Values, int32* MaxIndex = NULL)
    {
        if (Values.Num() == 0)
        {
            if (MaxIndex)
            {
                *MaxIndex = -1;
            }
            return T();
        }

        T CurMax = Values[0];
        int32 CurMaxIndex = 0;
        for (int32 v = 1; v < Values.Num(); ++v)
        {
            const T Value = Values[v];
            if (CurMax < Value)
            {
                CurMax = Value;
                CurMaxIndex = v;
            }
        }

        if (MaxIndex)
        {
            *MaxIndex = CurMaxIndex;
        }
        return CurMax;
    }

    static FORCEINLINE int32 CountBits(uint64 Bits)
    {
        // https://en.wikipedia.org/wiki/Hamming_weight
        Bits -= (Bits >> 1) & 0x5555555555555555ull;
        Bits = (Bits & 0x3333333333333333ull) + ((Bits >> 2) & 0x3333333333333333ull);
        Bits = (Bits + (Bits >> 4)) & 0x0f0f0f0f0f0f0f0full;
        return (Bits * 0x0101010101010101) >> 56;
    }
};

/** Float specialization */
template<>
FORCEINLINE float FGenericPlatformMath::Abs( const float A )
{
    return fabsf( A );
}


/**
 * Clang implementation of math functions
 **/
struct FClangPlatformMath : public FGenericPlatformMath
{
    /**
     * Counts the number of leading zeros in the bit representation of the value
     *
     * @param Value the value to determine the number of leading zeros for
     *
     * @return the number of zeros before the first "on" bit
     */
    static FORCEINLINE uint8 CountLeadingZeros8(uint8 Value)
    {
        return uint8(__builtin_clz((uint32(Value) << 1) | 1) - 23);
    }

    /**
     * Counts the number of leading zeros in the bit representation of the value
     *
     * @param Value the value to determine the number of leading zeros for
     *
     * @return the number of zeros before the first "on" bit
     */
    static FORCEINLINE uint32 CountLeadingZeros(uint32 Value)
    {
        return __builtin_clzll((uint64(Value) << 1) | 1) - 31;
    }

    /**
     * Counts the number of leading zeros in the bit representation of the value
     *
     * @param Value the value to determine the number of leading zeros for
     *
     * @return the number of zeros before the first "on" bit
     */
    static FORCEINLINE uint64 CountLeadingZeros64(uint64 Value)
    {
        if (Value == 0)
        {
            return 64;
        }

        return __builtin_clzll(Value);
    }

    /**
     * Counts the number of trailing zeros in the bit representation of the value
     *
     * @param Value the value to determine the number of trailing zeros for
     *
     * @return the number of zeros after the last "on" bit
     */
    static FORCEINLINE uint32 CountTrailingZeros(uint32 Value)
    {
        if (Value == 0)
        {
            return 32;
        }
    
        return (uint32)__builtin_ctz(Value);
    }
    
    /**
     * Counts the number of trailing zeros in the bit representation of the value
     *
     * @param Value the value to determine the number of trailing zeros for
     *
     * @return the number of zeros after the last "on" bit
     */
    static FORCEINLINE uint64 CountTrailingZeros64(uint64 Value)
    {
        if (Value == 0)
        {
            return 64;
        }
    
        return (uint64)__builtin_ctzll(Value);
    }

    static FORCEINLINE uint32 FloorLog2(uint32 Value)
    {
        int32 Mask = -int32(Value != 0);
        return (31 - __builtin_clz(Value)) & Mask;
    }

    static FORCEINLINE uint64 FloorLog2_64(uint64 Value)
    {
        int64 Mask = -int64(Value != 0);
        return (63 - __builtin_clzll(Value)) & Mask;
    }
};

/**
 * Structure for all math helper functions, inherits from platform math to pick up platform-specific implementations
 * Check GenericPlatformMath.h for additional math functions
 */
struct FMath : public FClangPlatformMath
{
    // Random Number Functions
    
    /** Helper function for rand implementations. Returns a random number in [0..A) */
    static FORCEINLINE int32 RandHelper(int32 A)
    {
        // Note that on some platforms RAND_MAX is a large number so we cannot do ((rand()/(RAND_MAX+1)) * A)
        // or else we may include the upper bound results, which should be excluded.
        return A > 0 ? Min(TruncToInt(FRand() * (float)A), A - 1) : 0;
    }
    
    static FORCEINLINE int64 RandHelper64(int64 A)
    {
        // Note that on some platforms RAND_MAX is a large number so we cannot do ((rand()/(RAND_MAX+1)) * A)
        // or else we may include the upper bound results, which should be excluded.
        return A > 0 ? Min<int64>(TruncToInt(FRand() * (float)A), A - 1) : 0;
    }
    
    /** Helper function for rand implementations. Returns a random number >= Min and <= Max */
    static FORCEINLINE int32 RandRange(int32 Min, int32 Max)
    {
        const int32 Range = (Max - Min) + 1;
        return Min + RandHelper(Range);
    }
    
    static FORCEINLINE int64 RandRange(int64 Min, int64 Max)
    {
        const int64 Range = (Max - Min) + 1;
        return Min + RandHelper64(Range);
    }
    
    /** Util to generate a random number in a range. Overloaded to distinguish from int32 version, where passing a float is typically a mistake. */
    static FORCEINLINE float RandRange(float InMin, float InMax)
    {
        return FRandRange(InMin, InMax);
    }
    
    /** Util to generate a random number in a range. */
    static FORCEINLINE float FRandRange(float InMin, float InMax)
    {
        return InMin + (InMax - InMin) * FRand();
    }
    
    /** Util to generate a random boolean. */
    static FORCEINLINE bool RandBool()
    {
        return (RandRange(0,1) == 1) ? true : false;
    }
    
    /** Checks if value is within a range, exclusive on MaxValue) */
    template< class U >
    static FORCEINLINE bool IsWithin(const U& TestValue, const U& MinValue, const U& MaxValue)
    {
        return ((TestValue >= MinValue) && (TestValue < MaxValue));
    }

    /** Checks if value is within a range, inclusive on MaxValue) */
    template< class U >
    static FORCEINLINE bool IsWithinInclusive(const U& TestValue, const U& MinValue, const U& MaxValue)
    {
        return ((TestValue>=MinValue) && (TestValue <= MaxValue));
    }
    
    /**
     *    Checks if two floating point numbers are nearly equal.
     *    @param A                First number to compare
     *    @param B                Second number to compare
     *    @param ErrorTolerance    Maximum allowed difference for considering them as 'nearly equal'
     *    @return                    true if A and B are nearly equal
     */
    static FORCEINLINE bool IsNearlyEqual(float A, float B, float ErrorTolerance = SMALL_NUMBER)
    {
        return Abs<float>( A - B ) <= ErrorTolerance;
    }

    /**
     *    Checks if two floating point numbers are nearly equal.
     *    @param A                First number to compare
     *    @param B                Second number to compare
     *    @param ErrorTolerance    Maximum allowed difference for considering them as 'nearly equal'
     *    @return                    true if A and B are nearly equal
     */
    static FORCEINLINE bool IsNearlyEqual(double A, double B, double ErrorTolerance = SMALL_NUMBER)
    {
        return Abs<double>( A - B ) <= ErrorTolerance;
    }

    /**
     *    Checks if a floating point number is nearly zero.
     *    @param Value            Number to compare
     *    @param ErrorTolerance    Maximum allowed difference for considering Value as 'nearly zero'
     *    @return                    true if Value is nearly zero
     */
    static FORCEINLINE bool IsNearlyZero(float Value, float ErrorTolerance = SMALL_NUMBER)
    {
        return Abs<float>( Value ) <= ErrorTolerance;
    }

    /**
     *    Checks if a floating point number is nearly zero.
     *    @param Value            Number to compare
     *    @param ErrorTolerance    Maximum allowed difference for considering Value as 'nearly zero'
     *    @return                    true if Value is nearly zero
     */
    static FORCEINLINE bool IsNearlyZero(double Value, double ErrorTolerance = SMALL_NUMBER)
    {
        return Abs<double>( Value ) <= ErrorTolerance;
    }

    /**
     *    Checks whether a number is a power of two.
     *    @param Value    Number to check
     *    @return            true if Value is a power of two
     */
    template <typename T>
    static FORCEINLINE bool IsPowerOfTwo( T Value )
    {
        return ((Value & (Value - 1)) == (T)0);
    }

    /** Converts a float to a nearest less or equal integer. */
    static FORCEINLINE float Floor(float F)
    {
        return FloorToFloat(F);
    }

    /** Converts a double to a nearest less or equal integer. */
    static FORCEINLINE double Floor(double F)
    {
        return FloorToDouble(F);
    }
    
    // Math Operations

    /** Returns highest of 3 values */
    template< class T >
    static FORCEINLINE T Max3( const T A, const T B, const T C )
    {
        return Max ( Max( A, B ), C );
    }

    /** Returns lowest of 3 values */
    template< class T >
    static FORCEINLINE T Min3( const T A, const T B, const T C )
    {
        return Min ( Min( A, B ), C );
    }

    /** Multiples value by itself */
    template< class T >
    static FORCEINLINE T Square( const T A )
    {
        return A*A;
    }

    /** Clamps X to be between Min and Max, inclusive */
    template< class T >
    [[nodiscard]] static FORCEINLINE T Clamp( const T X, const T Min, const T Max )
    {
        return X<Min ? Min : X<Max ? X : Max;
    }

    /** Wraps X to be between Min and Max, inclusive */
    template< class T >
    static FORCEINLINE T Wrap(const T X, const T Min, const T Max)
    {
        T Size = Max - Min;
        T EndVal = X;
        while (EndVal < Min)
        {
            EndVal += Size;
        }

        while (EndVal > Max)
        {
            EndVal -= Size;
        }
        return EndVal;
    }

    /** Snaps a value to the nearest grid multiple */
    template< class T >
    static FORCEINLINE T GridSnap(T Location, T Grid)
    {
        return (Grid == T{}) ? Location : (Floor((Location + (Grid/(T)2)) / Grid) * Grid);
    }

    /** Divides two integers and rounds up */
    template <class T>
    static FORCEINLINE T DivideAndRoundUp(T Dividend, T Divisor)
    {
        return (Dividend + Divisor - 1) / Divisor;
    }

    /** Divides two integers and rounds down */
    template <class T>
    static FORCEINLINE T DivideAndRoundDown(T Dividend, T Divisor)
    {
        return Dividend / Divisor;
    }

    /** Divides two integers and rounds to nearest */
    template <class T>
    static FORCEINLINE T DivideAndRoundNearest(T Dividend, T Divisor)
    {
        return (Dividend >= 0)
            ? (Dividend + Divisor / 2) / Divisor
            : (Dividend - Divisor / 2 + 1) / Divisor;
    }

    /**
     * Computes the base 2 logarithm of the specified value
     *
     * @param Value the value to perform the log on
     *
     * @return the base 2 log of the value
     */
    static FORCEINLINE float Log2(float Value)
    {
        // Cached value for fast conversions
        static const float LogToLog2 = 1.f / Loge(2.f);
        // Do the platform specific log and convert using the cached value
        return Loge(Value) * LogToLog2;
    }

    /**
    * Computes the sine and cosine of a scalar value.
    *
    * @param ScalarSin    Pointer to where the Sin result should be stored
    * @param ScalarCos    Pointer to where the Cos result should be stored
    * @param Value  input angles
    */
    static FORCEINLINE void SinCos( float* ScalarSin, float* ScalarCos, float  Value )
    {
        // Map Value to y in [-pi,pi], x = 2*pi*quotient + remainder.
        float quotient = (INV_PI*0.5f)*Value;
        if (Value >= 0.0f)
        {
            quotient = (float)((int)(quotient + 0.5f));
        }
        else
        {
            quotient = (float)((int)(quotient - 0.5f));
        }
        float y = Value - (2.0f*PI)*quotient;

        // Map y to [-pi/2,pi/2] with sin(y) = sin(Value).
        float sign;
        if (y > HALF_PI)
        {
            y = PI - y;
            sign = -1.0f;
        }
        else if (y < -HALF_PI)
        {
            y = -PI - y;
            sign = -1.0f;
        }
        else
        {
            sign = +1.0f;
        }

        float y2 = y * y;

        // 11-degree minimax approximation
        *ScalarSin = ( ( ( ( (-2.3889859e-08f * y2 + 2.7525562e-06f) * y2 - 0.00019840874f ) * y2 + 0.0083333310f ) * y2 - 0.16666667f ) * y2 + 1.0f ) * y;

        // 10-degree minimax approximation
        float p = ( ( ( ( -2.6051615e-07f * y2 + 2.4760495e-05f ) * y2 - 0.0013888378f ) * y2 + 0.041666638f ) * y2 - 0.5f ) * y2 + 1.0f;
        *ScalarCos = sign*p;
    }


    // Note:  We use FASTASIN_HALF_PI instead of HALF_PI inside of FastASin(), since it was the value that accompanied the minimax coefficients below.
    // It is important to use exactly the same value in all places inside this function to ensure that FastASin(0.0f) == 0.0f.
    // For comparison:
    //        HALF_PI                == 1.57079632679f == 0x3fC90FDB
    //        FASTASIN_HALF_PI    == 1.5707963050f  == 0x3fC90FDA
#define FASTASIN_HALF_PI (1.5707963050f)
    /**
    * Computes the ASin of a scalar value.
    *
    * @param Value  input angle
    * @return ASin of Value
    */
    static FORCEINLINE float FastAsin(float Value)
    {
        // Clamp input to [-1,1].
        bool nonnegative = (Value >= 0.0f);
        float x = FMath::Abs(Value);
        float omx = 1.0f - x;
        if (omx < 0.0f)
        {
            omx = 0.0f;
        }
        float root = FMath::Sqrt(omx);
        // 7-degree minimax approximation
        float result = ((((((-0.0012624911f * x + 0.0066700901f) * x - 0.0170881256f) * x + 0.0308918810f) * x - 0.0501743046f) * x + 0.0889789874f) * x - 0.2145988016f) * x + FASTASIN_HALF_PI;
        result *= root;  // acos(|x|)
        // acos(x) = pi - acos(-x) when x < 0, asin(x) = pi/2 - acos(x)
        return (nonnegative ? FASTASIN_HALF_PI - result : result - FASTASIN_HALF_PI);
    }
#undef FASTASIN_HALF_PI


    // Conversion Functions

    /**
     * Converts radians to degrees.
     * @param    RadVal            Value in radians.
     * @return                    Value in degrees.
     */
    template<class T>
    static FORCEINLINE auto RadiansToDegrees(T const& RadVal) -> decltype(RadVal * (180.f / PI))
    {
        return RadVal * (180.f / PI);
    }

    /**
     * Converts degrees to radians.
     * @param    DegVal            Value in degrees.
     * @return                    Value in radians.
     */
    template<class T>
    static FORCEINLINE auto DegreesToRadians(T const& DegVal) -> decltype(DegVal * (PI / 180.f))
    {
        return DegVal * (PI / 180.f);
    }

    /**
     * Clamps an arbitrary angle to be between the given angles.  Will clamp to nearest boundary.
     *
     * @param MinAngleDegrees    "from" angle that defines the beginning of the range of valid angles (sweeping clockwise)
     * @param MaxAngleDegrees    "to" angle that defines the end of the range of valid angles
     * @return Returns clamped angle in the range -180..180.
     */
    static float ClampAngle(float AngleDegrees, float MinAngleDegrees, float MaxAngleDegrees);

    /** Find the smallest angle between two headings (in degrees) */
    static float FindDeltaAngleDegrees(float A1, float A2)
    {
        // Find the difference
        float Delta = A2 - A1;

        // If change is larger than 180
        if (Delta > 180.0f)
        {
            // Flip to negative equivalent
            Delta = Delta - 360.0f;
        }
        else if (Delta < -180.0f)
        {
            // Otherwise, if change is smaller than -180
            // Flip to positive equivalent
            Delta = Delta + 360.0f;
        }

        // Return delta in [-180,180] range
        return Delta;
    }

    /** Find the smallest angle between two headings (in radians) */
    static float FindDeltaAngleRadians(float A1, float A2)
    {
        // Find the difference
        float Delta = A2 - A1;

        // If change is larger than PI
        if (Delta > PI)
        {
            // Flip to negative equivalent
            Delta = Delta - (PI * 2.0f);
        }
        else if (Delta < -PI)
        {
            // Otherwise, if change is smaller than -PI
            // Flip to positive equivalent
            Delta = Delta + (PI * 2.0f);
        }

        // Return delta in [-PI,PI] range
        return Delta;
    }
    
    static float FindDeltaAngle(float A1, float A2)
    {
        return FindDeltaAngleRadians(A1, A2);
    }

    /** Given a heading which may be outside the +/- PI range, 'unwind' it back into that range. */
    static float UnwindRadians(float A)
    {
        while(A > PI)
        {
            A -= ((float)PI * 2.0f);
        }

        while(A < -PI)
        {
            A += ((float)PI * 2.0f);
        }

        return A;
    }

    /** Utility to ensure angle is between +/- 180 degrees by unwinding. */
    static float UnwindDegrees(float A)
    {
        while(A > 180.f)
        {
            A -= 360.f;
        }

        while(A < -180.f)
        {
            A += 360.f;
        }

        return A;
    }
    
    /** Performs a linear interpolation between two values, Alpha ranges from 0-1 */
    template< class T, class U >
    static FORCEINLINE T Lerp( const T& A, const T& B, const U& Alpha )
    {
        return (T)(A + Alpha * (B-A));
    }

    /** Performs a linear interpolation between two values, Alpha ranges from 0-1. Handles full numeric range of T */
    template< class T >
    static FORCEINLINE T LerpStable( const T& A, const T& B, double Alpha )
    {
        return (T)((A * (1.0 - Alpha)) + (B * Alpha));
    }

    /** Performs a linear interpolation between two values, Alpha ranges from 0-1. Handles full numeric range of T */
    template< class T >
    static FORCEINLINE T LerpStable(const T& A, const T& B, float Alpha)
    {
        return (T)((A * (1.0f - Alpha)) + (B * Alpha));
    }

    /** Performs a 2D linear interpolation between four values values, FracX, FracY ranges from 0-1 */
    template< class T, class U >
    static FORCEINLINE T BiLerp(const T& P00,const T& P10,const T& P01,const T& P11, const U& FracX, const U& FracY)
    {
        return Lerp(
            Lerp(P00,P10,FracX),
            Lerp(P01,P11,FracX),
            FracY
            );
    }

    /**
     * Performs a cubic interpolation
     *
     * @param  P - end points
     * @param  T - tangent directions at end points
     * @param  Alpha - distance along spline
     *
     * @return  Interpolated value
     */
    template< class T, class U >
    static FORCEINLINE T CubicInterp( const T& P0, const T& T0, const T& P1, const T& T1, const U& A )
    {
        const float A2 = A  * A;
        const float A3 = A2 * A;

        return (T)(((2*A3)-(3*A2)+1) * P0) + ((A3-(2*A2)+A) * T0) + ((A3-A2) * T1) + (((-2*A3)+(3*A2)) * P1);
    }

    /**
     * Performs a first derivative cubic interpolation
     *
     * @param  P - end points
     * @param  T - tangent directions at end points
     * @param  Alpha - distance along spline
     *
     * @return  Interpolated value
     */
    template< class T, class U >
    static FORCEINLINE T CubicInterpDerivative( const T& P0, const T& T0, const T& P1, const T& T1, const U& A )
    {
        T a = 6.f*P0 + 3.f*T0 + 3.f*T1 - 6.f*P1;
        T b = -6.f*P0 - 4.f*T0 - 2.f*T1 + 6.f*P1;
        T c = T0;

        const float A2 = A  * A;

        return (a * A2) + (b * A) + c;
    }

    /**
     * Performs a second derivative cubic interpolation
     *
     * @param  P - end points
     * @param  T - tangent directions at end points
     * @param  Alpha - distance along spline
     *
     * @return  Interpolated value
     */
    template< class T, class U >
    static FORCEINLINE T CubicInterpSecondDerivative( const T& P0, const T& T0, const T& P1, const T& T1, const U& A )
    {
        T a = 12.f*P0 + 6.f*T0 + 6.f*T1 - 12.f*P1;
        T b = -6.f*P0 - 4.f*T0 - 2.f*T1 + 6.f*P1;

        return (a * A) + b;
    }

    /** Interpolate between A and B, applying an ease in function.  Exp controls the degree of the curve. */
    template< class T >
    static FORCEINLINE T InterpEaseIn(const T& A, const T& B, float Alpha, float Exp)
    {
        float const ModifiedAlpha = Pow(Alpha, Exp);
        return Lerp<T>(A, B, ModifiedAlpha);
    }

    /** Interpolate between A and B, applying an ease out function.  Exp controls the degree of the curve. */
    template< class T >
    static FORCEINLINE T InterpEaseOut(const T& A, const T& B, float Alpha, float Exp)
    {
        float const ModifiedAlpha = 1.f - Pow(1.f - Alpha, Exp);
        return Lerp<T>(A, B, ModifiedAlpha);
    }

    /** Interpolate between A and B, applying an ease in/out function.  Exp controls the degree of the curve. */
    template< class T >
    static FORCEINLINE T InterpEaseInOut( const T& A, const T& B, float Alpha, float Exp )
    {
        return Lerp<T>(A, B, (Alpha < 0.5f) ?
            InterpEaseIn(0.f, 1.f, Alpha * 2.f, Exp) * 0.5f :
            InterpEaseOut(0.f, 1.f, Alpha * 2.f - 1.f, Exp) * 0.5f + 0.5f);
    }

    /** Interpolation between A and B, applying a step function. */
    template< class T >
    static FORCEINLINE T InterpStep(const T& A, const T& B, float Alpha, int32 Steps)
    {
        if (Steps <= 1 || Alpha <= 0)
        {
            return A;
        }
        else if (Alpha >= 1)
        {
            return B;
        }

        const float StepsAsFloat = static_cast<float>(Steps);
        const float NumIntervals = StepsAsFloat - 1.f;
        float const ModifiedAlpha = FloorToFloat(Alpha * StepsAsFloat) / NumIntervals;
        return Lerp<T>(A, B, ModifiedAlpha);
    }

    /** Interpolation between A and B, applying a sinusoidal in function. */
    template< class T >
    static FORCEINLINE T InterpSinIn(const T& A, const T& B, float Alpha)
    {
        float const ModifiedAlpha = -1.f * Cos(Alpha * HALF_PI) + 1.f;
        return Lerp<T>(A, B, ModifiedAlpha);
    }
    
    /** Interpolation between A and B, applying a sinusoidal out function. */
    template< class T >
    static FORCEINLINE T InterpSinOut(const T& A, const T& B, float Alpha)
    {
        float const ModifiedAlpha = Sin(Alpha * HALF_PI);
        return Lerp<T>(A, B, ModifiedAlpha);
    }

    /** Interpolation between A and B, applying a sinusoidal in/out function. */
    template< class T >
    static FORCEINLINE T InterpSinInOut(const T& A, const T& B, float Alpha)
    {
        return Lerp<T>(A, B, (Alpha < 0.5f) ?
            InterpSinIn(0.f, 1.f, Alpha * 2.f) * 0.5f :
            InterpSinOut(0.f, 1.f, Alpha * 2.f - 1.f) * 0.5f + 0.5f);
    }

    /** Interpolation between A and B, applying an exponential in function. */
    template< class T >
    static FORCEINLINE T InterpExpoIn(const T& A, const T& B, float Alpha)
    {
        float const ModifiedAlpha = (Alpha == 0.f) ? 0.f : Pow(2.f, 10.f * (Alpha - 1.f));
        return Lerp<T>(A, B, ModifiedAlpha);
    }

    /** Interpolation between A and B, applying an exponential out function. */
    template< class T >
    static FORCEINLINE T InterpExpoOut(const T& A, const T& B, float Alpha)
    {
        float const ModifiedAlpha = (Alpha == 1.f) ? 1.f : -Pow(2.f, -10.f * Alpha) + 1.f;
        return Lerp<T>(A, B, ModifiedAlpha);
    }

    /** Interpolation between A and B, applying an exponential in/out function. */
    template< class T >
    static FORCEINLINE T InterpExpoInOut(const T& A, const T& B, float Alpha)
    {
        return Lerp<T>(A, B, (Alpha < 0.5f) ?
            InterpExpoIn(0.f, 1.f, Alpha * 2.f) * 0.5f :
            InterpExpoOut(0.f, 1.f, Alpha * 2.f - 1.f) * 0.5f + 0.5f);
    }

    /** Interpolation between A and B, applying a circular in function. */
    template< class T >
    static FORCEINLINE T InterpCircularIn(const T& A, const T& B, float Alpha)
    {
        float const ModifiedAlpha = -1.f * (Sqrt(1.f - Alpha * Alpha) - 1.f);
        return Lerp<T>(A, B, ModifiedAlpha);
    }

    /** Interpolation between A and B, applying a circular out function. */
    template< class T >
    static FORCEINLINE T InterpCircularOut(const T& A, const T& B, float Alpha)
    {
        Alpha -= 1.f;
        float const ModifiedAlpha = Sqrt(1.f - Alpha  * Alpha);
        return Lerp<T>(A, B, ModifiedAlpha);
    }

    /** Interpolation between A and B, applying a circular in/out function. */
    template< class T >
    static FORCEINLINE T InterpCircularInOut(const T& A, const T& B, float Alpha)
    {
        return Lerp<T>(A, B, (Alpha < 0.5f) ?
            InterpCircularIn(0.f, 1.f, Alpha * 2.f) * 0.5f :
            InterpCircularOut(0.f, 1.f, Alpha * 2.f - 1.f) * 0.5f + 0.5f);
    }

    
    /**
     * Simple function to create a pulsating scalar value
     *
     * @param  InCurrentTime  Current absolute time
     * @param  InPulsesPerSecond  How many full pulses per second?
     * @param  InPhase  Optional phase amount, between 0.0 and 1.0 (to synchronize pulses)
     *
     * @return  Pulsating value (0.0-1.0)
     */
    static float MakePulsatingValue( const double InCurrentTime, const float InPulsesPerSecond, const float InPhase = 0.0f )
    {
        return 0.5f + 0.5f * FMath::Sin( ( ( 0.25f + InPhase ) * (float)PI * 2.0f ) + ( (float)InCurrentTime * (float)PI * 2.0f ) * InPulsesPerSecond );
    }

    static FORCEINLINE float RoundFromZero(float F)
    {
        return (F < 0.0f) ? FloorToFloat(F) : CeilToFloat(F);
    }

    static FORCEINLINE double RoundFromZero(double F)
    {
        return (F < 0.0) ? FloorToDouble(F) : CeilToDouble(F);
    }

    /**
    * Converts a floating point number to an integer which is closer to zero, "smaller" in absolute value: 0.1 becomes 0, -0.1 becomes 0
    * @param F        Floating point value to convert
    * @return        The rounded integer
    */
    static FORCEINLINE float RoundToZero(float F)
    {
        return (F < 0.0f) ? CeilToFloat(F) : FloorToFloat(F);
    }

    static FORCEINLINE double RoundToZero(double F)
    {
        return (F < 0.0) ? CeilToDouble(F) : FloorToDouble(F);
    }

    /**
    * Converts a floating point number to an integer which is more negative: 0.1 becomes 0, -0.1 becomes -1
    * @param F        Floating point value to convert
    * @return        The rounded integer
    */
    static FORCEINLINE float RoundToNegativeInfinity(float F)
    {
        return FloorToFloat(F);
    }

    static FORCEINLINE double RoundToNegativeInfinity(double F)
    {
        return FloorToDouble(F);
    }

    /**
    * Converts a floating point number to an integer which is more positive: 0.1 becomes 1, -0.1 becomes 0
    * @param F        Floating point value to convert
    * @return        The rounded integer
    */
    static FORCEINLINE float RoundToPositiveInfinity(float F)
    {
        return CeilToFloat(F);
    }

    static FORCEINLINE double RoundToPositiveInfinity(double F)
    {
        return CeilToDouble(F);
    }

    /**
     * Get a bit in memory created from bitflags (uint32 Value:1), used for EngineShowFlags,
     * TestBitFieldFunctions() tests the implementation
     */
    static inline bool ExtractBoolFromBitfield(uint8* Ptr, uint32 Index)
    {
        uint8* BytePtr = Ptr + Index / 8;
        uint8 Mask = (uint8)(1 << (Index & 0x7));

        return (*BytePtr & Mask) != 0;
    }

    /**
     * Set a bit in memory created from bitflags (uint32 Value:1), used for EngineShowFlags,
     * TestBitFieldFunctions() tests the implementation
     */
    static inline void SetBoolInBitField(uint8* Ptr, uint32 Index, bool bSet)
    {
        uint8* BytePtr = Ptr + Index / 8;
        uint8 Mask = (uint8)(1 << (Index & 0x7));

        if(bSet)
        {
            *BytePtr |= Mask;
        }
        else
        {
            *BytePtr &= ~Mask;
        }
    }

   
    // @param x assumed to be in this range: 0..1
    // @return 0..255
    static uint8 Quantize8UnsignedByte(float x)
    {
        // 0..1 -> 0..255
        int32 Ret = (int32)(x * 255.999f);


        return (uint8)Ret;
    }
    
    // @param x assumed to be in this range: -1..1
    // @return 0..255
    static uint8 Quantize8SignedByte(float x)
    {
        // -1..1 -> 0..1
        float y = x * 0.5f + 0.5f;

        return Quantize8UnsignedByte(y);
    }

    // Use the Euclidean method to find the GCD
    static int32 GreatestCommonDivisor(int32 a, int32 b)
    {
        while (b != 0)
        {
            int32 t = b;
            b = a % b;
            a = t;
        }
        return a;
    }

    // LCM = a/gcd * b
    // a and b are the number we want to find the lcm
    static int32 LeastCommonMultiplier(int32 a, int32 b)
    {
        int32 CurrentGcd = GreatestCommonDivisor(a, b);
        return CurrentGcd == 0 ? 0 : (a / CurrentGcd) * b;
    }
};
