#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   srun -p cascade -N 4 -n 4 --cpus-per-task=48 --pty bash -i
#   cd ~/supercomp/scr/c
#   ./bench_cascade_4x48.sh [N]
#
# Notes:
# - This script assumes you already are inside an allocated Slurm job on cascade.
# - We run MPI from inside the allocation (no nested srun).
# - For MPI parts, we sweep P=1..4 and PE(=cores per rank)=1..48.

N="${1:-1048576}"
REPEATS="${REPEATS:-3}"
OUT="bench_results_$(date +%Y%m%d_%H%M%S)_cascade_P1-4_T1-48.csv"

OMPI_RUN="/opt/software/openmpi/4.1.6/gcc11/bin/mpirun"
IMPI_RUN="/opt/software/intel/intelpython3/bin/mpirun"

MPI_PROCS="${MPI_PROCS:-"1 2 3 4"}"
THREADS="${THREADS:-$(seq 1 48)}"

echo "program,impl,N,workers,pe_threads,unit,run_idx,time_s" > "$OUT"

run_timed() {
  local cmd="$1"
  local t0 t1
  t0=$(python3 - <<'PY'
import time; print(time.time())
PY
)
  # IMPORTANT: capture all output to avoid hanging from full buffers
  eval "$cmd" >/dev/null 2>&1
  t1=$(python3 - <<'PY'
import time; print(time.time())
PY
)
  python3 - <<PY
print("{:.6f}".format(float("$t1")-float("$t0")))
PY
}

append() {
  # program,impl,N,workers,pe_threads,unit,run_idx,time_s
  echo "$1,$2,$3,$4,$5,$6,$7,$8" >> "$OUT"
}

echo "== C serial =="
for r in $(seq 1 "$REPEATS"); do
  t=$(run_timed "./fft_serial $N")
  echo "serial r=$r t=$t"
  append "fft_serial" "C/serial" "$N" 1 1 "threads" "$r" "$t"
done

echo "== C pthreads T=1..48 =="
for T in $THREADS; do
  for r in $(seq 1 "$REPEATS"); do
    t=$(run_timed "./fft_pthreads $N $T")
    echo "pthreads T=$T r=$r t=$t"
    append "fft_pthreads" "C/pthreads" "$N" "$T" "$T" "threads" "$r" "$t"
  done
done

echo "== C OpenMP T=1..48 =="
for T in $THREADS; do
  export OMP_NUM_THREADS="$T"
  for r in $(seq 1 "$REPEATS"); do
    t=$(run_timed "./fft_openmp $N")
    echo "openmp T=$T r=$r t=$t"
    append "fft_openmp" "C/openmp" "$N" "$T" "$T" "threads" "$r" "$t"
  done
done
unset OMP_NUM_THREADS

echo "== C MPI sweep: P=1..4, PE=T=1..48 (OpenMPI) =="
for P in $MPI_PROCS; do
  for T in $THREADS; do
    for r in $(seq 1 "$REPEATS"); do
      # map 1 rank per node, each rank gets PE=T cores
      cmd="$OMPI_RUN --mca btl ^openib -np $P --bind-to core --map-by ppr:1:node:PE=$T ./fft_mpi $N"
      t=$(run_timed "$cmd")
      echo "C/MPI P=$P PE=$T r=$r t=$t"
      append "fft_mpi" "C/mpi" "$N" "$P" "$T" "processes" "$r" "$t"
    done
  done
done

echo "== Python MPI sweep: P=1..4, PE=T=1..48 (Intel mpirun) =="
for P in $MPI_PROCS; do
  for T in $THREADS; do
    # if numpy/MKL is used inside, this matters; otherwise harmless
    export OMP_NUM_THREADS="$T"
    export MKL_NUM_THREADS="$T"
    export OPENBLAS_NUM_THREADS="$T"
    export NUMEXPR_NUM_THREADS="$T"

    for r in $(seq 1 "$REPEATS"); do
      cmd="$IMPI_RUN -n $P python3 ./fft_mpi.py $N"
      t=$(run_timed "$cmd")
      echo "Py/MPI P=$P PE=$T r=$r t=$t"
      append "fft_mpi" "Py/mpi" "$N" "$P" "$T" "processes" "$r" "$t"
    done
  done
done
unset OMP_NUM_THREADS MKL_NUM_THREADS OPENBLAS_NUM_THREADS NUMEXPR_NUM_THREADS

echo "DONE -> $OUT"
