#include "fft_common.h"
#include <mpi.h>

void fft_mpi_block(cd *x_local, size_t n, int rank, int P){
unsigned log2n=0; while((1u<<log2n) < n) log2n++;
size_t nloc = n / P; // предполагаем n % P == 0

// Локальная битразворотка в пределах блока — ок для первых стадий
// (полная битразворотка глобально не требуется при Stockham, но мы используем перестановки)

for(unsigned s=1; s<=log2n; s++){
size_t m = 1ull<<s, mh=m>>1;
if(m <= nloc){
// чисто локальные бабочки
cd *W = (cd*)malloc(sizeof(cd)*mh);
twiddles(W, m);
for(size_t k=0;k<nloc;k+=m){
for(size_t j=0;j<mh;j++){
cd u=x_local[k+j]; cd v=W[j]*x_local[k+j+mh];
x_local[k+j]=u+v; x_local[k+j+mh]=u-v;
}
}
free(W);
} else {
// требуется обмен: разбить x на парные половины и выполнить all-to-all
// Упрощенно: собрать полный вектор (для маленьких P) -> выполнить серийную стадию -> разослать обратно
// (при больших n реализуйте MPI_Alltoallv с парной коммутацией)
cd *x_full = NULL;
if(rank==0) x_full = (cd*)malloc(sizeof(cd)*n);
MPI_Gather(x_local, (int)nloc*2, MPI_DOUBLE, // комплекс как два double
x_full, (int)nloc*2, MPI_DOUBLE, 0, MPI_COMM_WORLD);
if(rank==0){
cd *W = (cd*)malloc(sizeof(cd)*mh);
twiddles(W, m);
for(size_t k=0;k<n;k+=m){
for(size_t j=0;j<mh;j++){
cd u=x_full[k+j]; cd v=W[j]*x_full[k+j+mh];
x_full[k+j]=u+v; x_full[k+j+mh]=u-v;
}
}
free(W);
}
MPI_Scatter(x_full, (int)nloc*2, MPI_DOUBLE,
x_local, (int)nloc*2, MPI_DOUBLE, 0, MPI_COMM_WORLD);
if(rank==0) free(x_full);
}
}
}

int main(int argc, char **argv){
MPI_Init(&argc, &argv);
int rank, P; MPI_Comm_rank(MPI_COMM_WORLD,&rank); MPI_Comm_size(MPI_COMM_WORLD,&P);
size_t n = (argc>1)? strtoull(argv[1],NULL,10) : (1ull<<20);
size_t nloc = n / P;
cd *x = (cd*)malloc(sizeof(cd)*nloc);
// инициализация детерминированным тестом, например комплексный тон
for(size_t i=0;i<nloc;i++){ size_t g = i + (size_t)rank*nloc; double a=2*M_PI*(g%16)/(double)n; x[i]=cos(a)+I*sin(a); }
fft_mpi_block(x, n, rank, P);
// опционально: валидация/вывод нормы
double local_norm=0.0; for(size_t i=0;i<nloc;i++){ local_norm += creal(x[i])*creal(x[i]) + cimag(x[i])*cimag(x[i]); }
double global_norm=0.0; MPI_Reduce(&local_norm,&global_norm,1,MPI_DOUBLE,MPI_SUM,0,MPI_COMM_WORLD);
if(rank==0) printf("norm2=%e\n", global_norm);
free(x); MPI_Finalize(); return 0;
}