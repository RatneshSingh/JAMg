/* $Id: compress.h 132144 2014-04-02 16:02:28Z twu $ */
#ifndef COMPRESS_INCLUDED
#define COMPRESS_INCLUDED

#include <stdio.h>
#include "bool.h"
#include "types.h"
#include "genomicpos.h"


/* For genomebits32 format, we had COMPRESS_BLOCKSIZE=4.  We stored
   blocks every 4 uints, so they are on 128-bit boundaries.  This will
   waste one out of every 4 uints, but allows for use of SIMD in
   Compress_shift.  However with genomebits128, we want
   COMPRESS_BLOCKSIZE=12.  If we don't have SSE2, then we can't use
   SIMD in Compress_shift, so COMPRESS_BLOCKSIZE can be 3.  */


#ifdef HAVE_SSE2
#define COMPRESS_BLOCKSIZE 12	/* 12 unsigned ints per block */
#else
#define COMPRESS_BLOCKSIZE 3	/* 3 unsigned ints per block */
#endif


#define T Compress_T
typedef struct T *T;

extern void
Compress_free (T *old);
extern void
Compress_print (T this);
extern int
Compress_nblocks (T this);
extern void
Compress_print_blocks (Genomecomp_T *blocks, int nblocks);
extern T
Compress_new_fwd (char *gbuffer, Chrpos_T length);
extern T
Compress_new_rev (char *gbuffer, Chrpos_T length);
extern Genomecomp_T *
Compress_shift (T this, int nshift);

extern void
Compress_get_16mer_left (UINT4 *high, UINT4 *low, UINT4 *flags, T this, int pos3);
extern void
Compress_get_16mer_right (UINT4 *high, UINT4 *low, UINT4 *flags, T this, int pos5);


#undef T
#endif

