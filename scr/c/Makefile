# --- компиляторы ---
CC        ?= clang                 # serial/pthreads/openmp — Clang
MPICC     ?= mpicc                 # из Homebrew open-mpi

# --- SDK и libomp ---
SDKROOT   ?= $(shell xcrun --sdk macosx --show-sdk-path)
LIBOMP    ?= $(shell brew --prefix libomp)

# --- флаги ---
CFLAGS_BASE = -O3 -Wall -ffast-math -march=native -isysroot $(SDKROOT)
# OpenMP через libomp (для Clang)
CFLAGS_OMP  = -Xpreprocessor -fopenmp -I$(LIBOMP)/include
LDFLAGS_OMP = -L$(LIBOMP)/lib -lomp

all: fft_serial fft_pthreads fft_openmp fft_mpi

fft_serial: fft_serial.c fft_common.h
	$(CC) $(CFLAGS_BASE) -o $@ fft_serial.c -lm

fft_pthreads: fft_pthreads.c fft_common.h
	$(CC) $(CFLAGS_BASE) -o $@ fft_pthreads.c -lpthread -lm

fft_openmp: fft_openmp.c fft_common.h
	$(CC) $(CFLAGS_BASE) $(CFLAGS_OMP) -o $@ fft_openmp.c $(LDFLAGS_OMP) -lm

fft_mpi: fft_mpi.c fft_common.h
	$(MPICC) $(CFLAGS_BASE) -o $@ fft_mpi.c -lm

clean:
	rm -f fft_serial fft_pthreads fft_openmp fft_mpi
