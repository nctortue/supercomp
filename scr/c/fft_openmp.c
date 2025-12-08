#include "fft_common.h"
#include <omp.h>

static void fft_openmp_impl(cd *x, size_t n){
    unsigned log2n = 0; while ((1u<<log2n) < n) log2n++;

    #pragma omp parallel for schedule(static)
    for (long long i = 0; i < (long long)n; i++) {
        size_t r = bitrev((size_t)i, log2n);
        if (r > (size_t)i) {
            cd tmp = x[i]; x[i] = x[r]; x[r] = tmp;
        }
    }

    for (unsigned s = 1; s <= log2n; s++) {
        size_t m = 1ull << s, mh = m >> 1;
        cd *W = (cd*)malloc(sizeof(cd)*mh);
        twiddles(W, m);
        #pragma omp parallel for schedule(static)
        for (long long k = 0; k < (long long)n; k += (long long)m) {
            for (size_t j = 0; j < mh; j++) {
                cd u = x[k + j];
                cd v = W[j] * x[k + j + mh];
                x[k + j] = u + v;
                x[k + j + mh] = u - v;
            }
        }
        free(W);
    }
}

int main(int argc, char **argv){
    size_t n = (argc > 1) ? strtoull(argv[1], NULL, 10) : (1ull << 20);
    if (!is_pow2(n)) { fprintf(stderr, "N must be power of two\n"); return 1; }

    cd *x = (cd*)malloc(sizeof(cd)*n);
    for (size_t i = 0; i < n; i++) {
        double a = 2 * M_PI * (i % 16) / (double)n;
        x[i] = cos(a) + I * sin(a);
    }

    fft_openmp_impl(x, n);

    double norm2 = 0.0;
    for (size_t i = 0; i < n; i++)
        norm2 += creal(x[i]) * creal(x[i]) + cimag(x[i]) * cimag(x[i]);
    printf("norm2=%e\n", norm2);

    free(x);
    return 0;
}
