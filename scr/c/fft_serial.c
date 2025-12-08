#include "fft_common.h"

int main(int argc, char **argv) {
    size_t n = (argc > 1) ? strtoull(argv[1], NULL, 10) : (1ull << 20);
    if (!is_pow2(n)) { fprintf(stderr, "N must be power of two\n"); return 1; }

    cd *x = (cd*)malloc(sizeof(cd) * n);
    for (size_t i = 0; i < n; i++) {
        double a = 2 * M_PI * (i % 16) / (double)n;
        x[i] = cos(a) + I * sin(a);
    }

    fft_serial_impl(x, n);

    double norm2 = 0.0;
    for (size_t i = 0; i < n; i++)
        norm2 += creal(x[i]) * creal(x[i]) + cimag(x[i]) * cimag(x[i]);

    printf("norm2=%e\n", norm2);
    free(x);
    return 0;
}
