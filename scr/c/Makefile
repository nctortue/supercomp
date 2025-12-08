# ---------- Linux/HPC Makefile ----------
CC_SERIAL ?= cc
CC_PTHREADS ?= cc
CC_OMP ?= cc
MPICC ?= mpicc

# включаем современный стандарт C, иначе будут C89-ошибки
CSTD = -std=gnu11

CFLAGS = $(CSTD) -O3 -Wall -ffast-math -march=native
OMPFLAGS = -fopenmp

all: fft_serial fft_pthreads fft_openmp fft_mpi

fft_serial: fft_serial.c fft_common.h
	$(CC_SERIAL) $(CFLAGS) -o $@ fft_serial.c -lm

fft_pthreads: fft_pthreads.c fft_common.h
	$(CC_PTHREADS) $(CFLAGS) -o $@ fft_pthreads.c -lpthread -lm

fft_openmp: fft_openmp.c fft_common.h
	$(CC_OMP) $(CFLAGS) $(OMPFLAGS) -o $@ fft_openmp.c -lm

fft_mpi: fft_mpi.c fft_common.h
	$(MPICC) $(CFLAGS) -o $@ fft_mpi.c -lm

clean:
	rm -f fft_serial fft_pthreads fft_openmp fft_mpi
