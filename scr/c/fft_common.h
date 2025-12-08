#pragma once
#include <math.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <complex.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

typedef double complex cd;

static inline int is_pow2(size_t n){ return n && ((n & (n-1))==0); }

static inline size_t bitrev(size_t x, unsigned log2n){
    size_t y = 0;
    for(unsigned i=0;i<log2n;i++){ y = (y<<1) | (x & 1); x >>= 1; }
    return y;
}

static inline void twiddles(cd *W, size_t m){
    const double ang = -2.0 * M_PI / (double)m;
    for(size_t j=0;j<m/2;j++){
        double a = ang * (double)j;
        W[j] = cos(a) + I*sin(a);
    }
}

static inline void fft_serial_impl(cd *x, size_t n){
    unsigned log2n = 0; while((1u<<log2n) < n) log2n++;
    for(size_t i=0;i<n;i++){
        size_t r = bitrev(i, log2n);
        if(r>i){ cd tmp=x[i]; x[i]=x[r]; x[r]=tmp; }
    }
    for(unsigned s=1;s<=log2n;s++){
        size_t m = 1ull<<s, mh=m>>1;
        cd *W = (cd*)malloc(sizeof(cd)*mh);
        twiddles(W, m);
        for(size_t k=0;k<n;k+=m){
            for(size_t j=0;j<mh;j++){
                cd t = W[j] * x[k+j+mh];
                cd u = x[k+j];
                x[k+j] = u + t;
                x[k+j+mh] = u - t;
            }
        }
        free(W);
    }
}
