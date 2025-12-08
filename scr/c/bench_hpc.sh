#!/bin/bash
set -euo pipefail

N=${1:-1048576}
REPEATS=3

THREAD_LIST="1 2 4 8 16 32 48"
MPI_PROCS="1 2 4 8 16 32"    # Только делители N

CSV="bench_results_$(date +%Y%m%d_%H%M%S).csv"
echo "program,impl,N,workers,unit,run_idx,time_s" > "$CSV"

measure_time() {
    local cmd="$1"
    /usr/bin/time -f "%e" -o .time.tmp bash -c "$cmd" >/dev/null 2>&1
    cat .time.tmp
}

########################################
# 1) SERIAL
########################################
for run in $(seq 1 $REPEATS); do
    t=$(measure_time "./fft_serial $N")
    echo "fft_serial,C/serial,$N,1,threads,$run,$t" >> "$CSV"
done

########################################
# 2) PTHREADS
########################################
for T in $THREAD_LIST; do
    for run in $(seq 1 $REPEATS); do
        t=$(measure_time "./fft_pthreads $N $T")
        echo "fft_pthreads,C/pthreads,$N,$T,threads,$run,$t" >> "$CSV"
    done
done

########################################
# 3) OPENMP
########################################
for T in $THREAD_LIST; do
    export OMP_NUM_THREADS=$T
    for run in $(seq 1 $REPEATS); do
        t=$(measure_time "./fft_openmp $N")
        echo "fft_openmp,C/openmp,$N,$T,threads,$run,$t" >> "$CSV"
    done
done
unset OMP_NUM_THREADS

########################################
# 4) MPI C
########################################
for P in $MPI_PROCS; do
    for run in $(seq 1 $REPEATS); do
        t=$(measure_time "mpirun --mca btl ^openib -np $P ./fft_mpi $N")
        echo "fft_mpi,C/mpi,$N,$P,processes,$run,$t" >> "$CSV"
    done
done

########################################
# 5) MPI Python
########################################
for P in $MPI_PROCS; do
    for run in $(seq 1 $REPEATS); do
        t=$(measure_time "mpirun --mca btl ^openib -np $P python3 fft_mpi.py $N")
        echo "fft_mpi_py,Python/mpi,$N,$P,processes,$run,$t" >> "$CSV"
    done
done

echo "DONE. CSV: $CSV"
