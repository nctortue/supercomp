#!/usr/bin/env bash
set -euo pipefail
N=${1:-1048576} # 1<<20
T=${2:-8}

pushd src/c
make -j
./fft_serial $N > /dev/null
./fft_pthreads $N $T > /dev/null
OMP_NUM_THREADS=$T ./fft_openmp $N > /dev/null
mpirun -np $T ./fft_mpi $N > /dev/null
popd