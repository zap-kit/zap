/* The x86 SIMD intrinsics the Benchmarks Game programs here use (SSE2, SSE4.1 and the AVX ones on
   4 doubles), written over NEON so that the same algorithm runs on AArch64. Each function does
   what its x86 namesake does, bit for bit, except _mm_rcp_ps and _mm_rsqrt_ps, which are as
   accurate as x86's (about 12 bits; the programs refine them). Included only where __aarch64__. */
#ifndef X86_ON_NEON_H
#define X86_ON_NEON_H

#include <arm_neon.h>
#include <stdint.h>

#define X86_NEON_INLINE static inline __attribute__((always_inline))

/* may_alias as x86's: programs read a vector through a char array */
typedef int8x16_t __m128i __attribute__((__may_alias__));
typedef float64x2_t __m128d __attribute__((__may_alias__));
typedef float32x4_t __m128 __attribute__((__may_alias__));
typedef struct { float64x2_t lo, hi; } __m256d;   /* lanes 0 and 1, lanes 2 and 3 */

/* ---------- 16 bytes ---------- */

X86_NEON_INLINE __m128i _mm_setr_epi8(int e0, int e1, int e2, int e3, int e4, int e5, int e6, int e7,
                                      int e8, int e9, int e10, int e11, int e12, int e13, int e14, int e15) {
  const int8_t lanes[16] = {(int8_t)e0, (int8_t)e1, (int8_t)e2, (int8_t)e3, (int8_t)e4, (int8_t)e5,
                            (int8_t)e6, (int8_t)e7, (int8_t)e8, (int8_t)e9, (int8_t)e10, (int8_t)e11,
                            (int8_t)e12, (int8_t)e13, (int8_t)e14, (int8_t)e15};
  return vld1q_s8(lanes);
}
X86_NEON_INLINE __m128i _mm_setzero_si128(void) { return vdupq_n_s8(0); }
X86_NEON_INLINE __m128i _mm_set1_epi8(int e) { return vdupq_n_s8((int8_t)e); }
X86_NEON_INLINE __m128i _mm_load_si128(const __m128i *p) { return vld1q_s8((const int8_t *)p); }
X86_NEON_INLINE __m128i _mm_add_epi8(__m128i a, __m128i b) { return vaddq_s8(a, b); }
X86_NEON_INLINE __m128i _mm_sub_epi8(__m128i a, __m128i b) { return vsubq_s8(a, b); }
X86_NEON_INLINE __m128i _mm_andnot_si128(__m128i a, __m128i b) { return vbicq_s8(b, a); }
X86_NEON_INLINE __m128i _mm_cmpeq_epi8(__m128i a, __m128i b) { return vreinterpretq_s8_u8(vceqq_s8(a, b)); }
X86_NEON_INLINE __m128i _mm_cmpgt_epi8(__m128i a, __m128i b) { return vreinterpretq_s8_u8(vcgtq_s8(a, b)); }

/* the byte of b where the mask's byte has its top bit set, else a's */
X86_NEON_INLINE __m128i _mm_blendv_epi8(__m128i a, __m128i b, __m128i mask) {
  return vbslq_s8(vreinterpretq_u8_s8(vshrq_n_s8(mask, 7)), b, a);
}

/* a's bytes picked by b's: the low 4 bits of an index, or zero when its top bit is set */
X86_NEON_INLINE __m128i _mm_shuffle_epi8(__m128i a, __m128i b) {
  return vqtbl1q_s8(a, vandq_u8(vreinterpretq_u8_s8(b), vdupq_n_u8(0x8F)));
}

/* the top bit of each byte as one bit of an int */
X86_NEON_INLINE int _mm_movemask_epi8(__m128i a) {
  const uint8_t weights[16] = {1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128};
  uint8x16_t bits = vandq_u8(vreinterpretq_u8_s8(vshrq_n_s8(a, 7)), vld1q_u8(weights));
  bits = vpaddq_u8(bits, bits);
  bits = vpaddq_u8(bits, bits);
  bits = vpaddq_u8(bits, bits);
  return vgetq_lane_u16(vreinterpretq_u16_u8(bits), 0);
}

X86_NEON_INLINE int _mm_cvtsi128_si32(__m128i a) { return vgetq_lane_s32(vreinterpretq_s32_s8(a), 0); }

/* the 32 bytes a (high) over b (low) shifted right by n bytes, the low 16 of them */
#define _mm_alignr_epi8(a, b, n) vextq_s8((b), (a), (n))
/* a shifted right by n bytes, zeros coming in */
#define _mm_bsrli_si128(a, n) vextq_s8((a), vdupq_n_s8(0), (n))
/* byte n of a, as an unsigned value */
#define _mm_extract_epi8(a, n) ((int)(uint8_t)vgetq_lane_s8((a), (n)))

/* ---------- 4 int32 ---------- */

X86_NEON_INLINE __m128i _mm_set1_epi32(int e) { return vreinterpretq_s8_s32(vdupq_n_s32(e)); }
X86_NEON_INLINE __m128i _mm_setr_epi32(int e0, int e1, int e2, int e3) {
  const int32_t lanes[4] = {e0, e1, e2, e3};
  return vreinterpretq_s8_s32(vld1q_s32(lanes));
}
X86_NEON_INLINE __m128i _mm_add_epi32(__m128i a, __m128i b) {
  return vreinterpretq_s8_s32(vaddq_s32(vreinterpretq_s32_s8(a), vreinterpretq_s32_s8(b)));
}
X86_NEON_INLINE __m128i _mm_mullo_epi32(__m128i a, __m128i b) {
  return vreinterpretq_s8_s32(vmulq_s32(vreinterpretq_s32_s8(a), vreinterpretq_s32_s8(b)));
}
#define _mm_srli_epi32(a, n) vreinterpretq_s8_u32(vshrq_n_u32(vreinterpretq_u32_s8(a), (n)))

/* ---------- 4 floats ---------- */

/* the estimates of 1/x and 1/sqrt(x) to about 12 bits, as x86's: NEON's own are 8 bits, so one
   Newton step follows */
X86_NEON_INLINE __m128 _mm_rcp_ps(__m128 a) {
  __m128 r = vrecpeq_f32(a);
  return vmulq_f32(r, vrecpsq_f32(a, r));
}
X86_NEON_INLINE __m128 _mm_rsqrt_ps(__m128 a) {
  __m128 r = vrsqrteq_f32(a);
  return vmulq_f32(r, vrsqrtsq_f32(vmulq_f32(a, r), r));
}

/* ---------- 2 doubles ---------- */

X86_NEON_INLINE __m128d _mm_set_pd(double e1, double e0) {
  const double lanes[2] = {e0, e1};
  return vld1q_f64(lanes);
}
X86_NEON_INLINE __m128d _mm_set1_pd(double e) { return vdupq_n_f64(e); }
X86_NEON_INLINE void _mm_storeu_pd(double *p, __m128d a) { vst1q_f64(p, a); }
X86_NEON_INLINE __m128d _mm_add_pd(__m128d a, __m128d b) { return vaddq_f64(a, b); }
X86_NEON_INLINE __m128d _mm_sqrt_pd(__m128d a) { return vsqrtq_f64(a); }
X86_NEON_INLINE void _mm_store_pd(double *p, __m128d a) { vst1q_f64(p, a); }

/* ---------- 4 doubles ---------- */

X86_NEON_INLINE __m256d x86_neon_join(float64x2_t lo, float64x2_t hi) {
  __m256d r;
  r.lo = lo;
  r.hi = hi;
  return r;
}

X86_NEON_INLINE __m256d _mm256_set1_pd(double e) { return x86_neon_join(vdupq_n_f64(e), vdupq_n_f64(e)); }
X86_NEON_INLINE __m256d _mm256_setr_pd(double e0, double e1, double e2, double e3) {
  const double lanes[4] = {e0, e1, e2, e3};
  return x86_neon_join(vld1q_f64(lanes), vld1q_f64(lanes + 2));
}
X86_NEON_INLINE __m256d _mm256_load_pd(const double *p) { return x86_neon_join(vld1q_f64(p), vld1q_f64(p + 2)); }
X86_NEON_INLINE void _mm256_store_pd(double *p, __m256d a) {
  vst1q_f64(p, a.lo);
  vst1q_f64(p + 2, a.hi);
}
X86_NEON_INLINE double _mm256_cvtsd_f64(__m256d a) { return vgetq_lane_f64(a.lo, 0); }

X86_NEON_INLINE __m256d _mm256_add_pd(__m256d a, __m256d b) {
  return x86_neon_join(vaddq_f64(a.lo, b.lo), vaddq_f64(a.hi, b.hi));
}
X86_NEON_INLINE __m256d _mm256_sub_pd(__m256d a, __m256d b) {
  return x86_neon_join(vsubq_f64(a.lo, b.lo), vsubq_f64(a.hi, b.hi));
}
X86_NEON_INLINE __m256d _mm256_mul_pd(__m256d a, __m256d b) {
  return x86_neon_join(vmulq_f64(a.lo, b.lo), vmulq_f64(a.hi, b.hi));
}

/* [a0+a1, b0+b1, a2+a3, b2+b3] */
X86_NEON_INLINE __m256d _mm256_hadd_pd(__m256d a, __m256d b) {
  return x86_neon_join(vpaddq_f64(a.lo, b.lo), vpaddq_f64(a.hi, b.hi));
}
/* [a0, b0, a2, b2] and [a1, b1, a3, b3] */
X86_NEON_INLINE __m256d _mm256_unpacklo_pd(__m256d a, __m256d b) {
  return x86_neon_join(vzip1q_f64(a.lo, b.lo), vzip1q_f64(a.hi, b.hi));
}
X86_NEON_INLINE __m256d _mm256_unpackhi_pd(__m256d a, __m256d b) {
  return x86_neon_join(vzip2q_f64(a.lo, b.lo), vzip2q_f64(a.hi, b.hi));
}

/* the half selected by two bits of imm: 0 a.lo, 1 a.hi, 2 b.lo, 3 b.hi (the immediates are
   constants after inlining) */
X86_NEON_INLINE float64x2_t x86_neon_half(__m256d a, __m256d b, int select) {
  return select == 0 ? a.lo : select == 1 ? a.hi : select == 2 ? b.lo : b.hi;
}
X86_NEON_INLINE __m256d _mm256_permute2f128_pd(__m256d a, __m256d b, const int imm) {
  return x86_neon_join(x86_neon_half(a, b, imm & 3), x86_neon_half(a, b, (imm >> 4) & 3));
}

/* lane i of the result is b's where bit i of imm is set, else a's */
X86_NEON_INLINE float64x2_t x86_neon_blend2(float64x2_t a, float64x2_t b, int bits) {
  switch (bits) {
    case 0: return a;
    case 1: return vcopyq_laneq_f64(a, 0, b, 0);
    case 2: return vcopyq_laneq_f64(a, 1, b, 1);
    default: return b;
  }
}
X86_NEON_INLINE __m256d _mm256_blend_pd(__m256d a, __m256d b, const int imm) {
  return x86_neon_join(x86_neon_blend2(a.lo, b.lo, imm & 3), x86_neon_blend2(a.hi, b.hi, (imm >> 2) & 3));
}

/* within each half, lane i of the result is the lane of a that bit i of imm names */
X86_NEON_INLINE float64x2_t x86_neon_permute2(float64x2_t a, int bits) {
  switch (bits) {
    case 0: return vdupq_laneq_f64(a, 0);
    case 1: return vextq_f64(a, a, 1);
    case 2: return a;
    default: return vdupq_laneq_f64(a, 1);
  }
}
X86_NEON_INLINE __m256d _mm256_permute_pd(__m256d a, const int imm) {
  return x86_neon_join(x86_neon_permute2(a.lo, imm & 3), x86_neon_permute2(a.hi, (imm >> 2) & 3));
}

#define _mm256_extractf128_pd(a, n) ((n) ? (a).hi : (a).lo)

X86_NEON_INLINE __m128 _mm256_cvtpd_ps(__m256d a) {
  return vcombine_f32(vcvt_f32_f64(a.lo), vcvt_f32_f64(a.hi));
}
X86_NEON_INLINE __m256d _mm256_cvtps_pd(__m128 a) {
  return x86_neon_join(vcvt_f64_f32(vget_low_f32(a)), vcvt_high_f64_f32(a));
}
X86_NEON_INLINE __m256d _mm256_cvtepi32_pd(__m128i a) {
  int32x4_t ints = vreinterpretq_s32_s8(a);
  return x86_neon_join(vcvtq_f64_s64(vmovl_s32(vget_low_s32(ints))), vcvtq_f64_s64(vmovl_high_s32(ints)));
}

#endif
