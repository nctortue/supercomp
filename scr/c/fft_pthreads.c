#include "fft_common.h"
#include <pthread.h>

typedef struct {
    cd *x;
    size_t n;
    unsigned s;
    size_t k_begin;
    size_t k_end;
} task_t;

static void *stage_worker(void *arg){
    task_t *t = (task_t*)arg;
    size_t m = 1ull << t->s, mh = m >> 1;
    cd *W = (cd*)malloc(sizeof(cd)*mh);
    twiddles(W, m);
    for (size_t k = t->k_begin; k < t->k_end; k += m) {
        for (size_t j = 0; j < mh; j++) {
            cd u = t->x[k + j];
            cd v = W[j] * t->x[k + j + mh];
            t->x[k + j] = u + v;
            t->x[k + j + mh] = u - v;
        }
    }
    free(W);
    return NULL;
}

static void fft_pthreads_impl(cd *x, size_t n, int nthreads){
    unsigned log2n = 0; while ((1u<<log2n) < n) log2n++;

    for (size_t i = 0; i < n; i++) {
        size_t r = bitrev(i, log2n);
        if (r > i) { cd tmp = x[i]; x[i] = x[r]; x[r] = tmp; }
    }

    for (unsigned s = 1; s <= log2n; s++) {
        size_t m = 1ull << s;
        size_t blocks = n / m;
        int T = (nthreads < (int)blocks) ? nthreads : (int)blocks;

        pthread_t *th = (pthread_t*)malloc(sizeof(pthread_t)*T);
        task_t *tasks = (task_t*)malloc(sizeof(task_t)*T);

        size_t blk_per_thr = blocks / T;
        size_t rem = blocks % T;
        size_t k = 0;

        for (int t = 0; t < T; t++) {
            size_t take = blk_per_thr + (t < (int)rem);
            tasks[t] = (task_t){ x, n, s, k * m, (k + take) * m };
            pthread_create(&th[t], NULL, stage_worker, &tasks[t]);
            k += take;
        }
        for (int t = 0; t < T; t++) pthread_join(th[t], NULL);

        free(tasks); free(th);
    }
}

int main(int argc, char **argv){
    size_t n = (argc > 1) ? strtoull(argv[1], NULL, 10) : (1ull << 20);
    int nthreads = (argc > 2) ? atoi(argv[2]) : 8;
    if (!is_pow2(n)) { fprintf(stderr, "N must be power of two\n"); return 1; }

    cd *x = (cd*)malloc(sizeof(cd)*n);
    for (size_t i = 0; i < n; i++) {
        double a = 2 * M_PI * (i % 16) / (double)n;
        x[i] = cos(a) + I * sin(a);
    }

    fft_pthreads_impl(x, n, nthreads);

    double norm2 = 0.0;
    for (size_t i = 0; i < n; i++)
        norm2 += creal(x[i]) * creal(x[i]) + cimag(x[i]) * cimag(x[i]);
    printf("norm2=%e\n", norm2);

    free(x);
    return 0;
}
