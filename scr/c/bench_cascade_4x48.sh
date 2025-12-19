#!/usr/bin/env bash
set -euo pipefail

N="${1:-1048576}"
REPEATS="${REPEATS:-3}"
OUT="bench_results_$(date +%Y%m%d_%H%M%S)_cascade4x48.csv"

OMPI_RUN="/opt/software/openmpi/4.1.6/gcc11/bin/mpirun"
IMPI_RUN="/opt/software/intel/intelpython3/bin/mpirun"

echo "program,impl,N,workers,unit,run_idx,time_s" > "$OUT"

run_timed() {
  local cmd="$1"
  local t0 t1
  t0=$(python3 - <<'PY'
import time; print(time.time())
PY
)
  eval "$cmd" >/dev/null
  t1=$(python3 - <<'PY'
import time; print(time.time())
PY
)
  python3 - <<PY
print("{:.6f}".format(float("$t1")-float("$t0")))
PY
}

append() { echo "$1,$2,$3,$4,$5,$6,$7" >> "$OUT"; }

echo "== C serial =="
for r in $(seq 1 "$REPEATS"); do
  t=$(run_timed "./fft_serial $N")
  echo "serial r=$r t=$t"
  append "fft_serial" "C/serial" "$N" 1 "threads" "$r" "$t"
done

echo "== C pthreads T=1..48 =="
for T in $(seq 1 48); do
  for r in $(seq 1 "$REPEATS"); do
    t=$(run_timed "./fft_pthreads $N $T")
    echo "pthreads T=$T r=$r t=$t"
    append "fft_pthreads" "C/pthreads" "$N" "$T" "threads" "$r" "$t"
  done
done

echo "== C OpenMP T=1..48 =="
for T in $(seq 1 48); do
  export OMP_NUM_THREADS="$T"
  for r in $(seq 1 "$REPEATS"); do
    t=$(run_timed "./fft_openmp $N")
    echo "openmp T=$T r=$r t=$t"
    append "fft_openmp" "C/openmp" "$N" "$T" "threads" "$r" "$t"
  done
done
unset OMP_NUM_THREADS

echo "== C MPI fixed P=4, PE=48 =="
for r in $(seq 1 "$REPEATS"); do
  t=$(run_timed "$OMPI_RUN --mca btl ^openib -np 4 --bind-to core --map-by ppr:1:node:PE=48 ./fft_mpi $N")
  echo "C/MPI P=4 r=$r t=$t"
  append "fft_mpi" "C/mpi" "$N" 4 "processes" "$r" "$t"
done

echo "== Python MPI fixed P=4 =="
for r in $(seq 1 "$REPEATS"); do
  t=$(run_timed "$IMPI_RUN -n 4 python3 ./fft_mpi.py $N")
  echo "Py/MPI P=4 r=$r t=$t"
  append "fft_mpi" "Py/mpi" "$N" 4 "processes" "$r" "$t"
done

echo "DONE -> $OUT"
EOF

chmod +x bench_cascade_4x48.sh
