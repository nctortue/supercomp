#!/usr/bin/env bash
set -euo pipefail

# ================== настройки ==================
N="${1:-1048576}"
REPEATS="${REPEATS:-3}"
OUT="bench_results_$(date +%Y%m%d_%H%M%S)_1to48.csv"

# бинари/пути
C_SERIAL="./fft_serial"
C_PTH="./fft_pthreads"
C_OMP="./fft_openmp"
C_MPI="./fft_mpi"
PY_MPI="python3 ./fft_mpi.py"

# mpirun
OMPI_RUN="/opt/software/openmpi/4.1.6/gcc11/bin/mpirun"
IMPI_RUN="/opt/software/intel/intelpython3/bin/mpirun"

# MPI привязки (как у тебя, 1 процесс на узел, каждому процессу 48 CPU)
OMPI_BIND_ARGS=(--mca btl ^openib -np 1 --bind-to core --map-by ppr:1:node:PE=48)
# ^ np заменим на нужное ниже

# список потоков/процессов 1..48
SEQ_1_48=$(seq 1 48)

# ================== helpers ==================
now_sec() { python3 - <<'PY'
import time
print("{:.6f}".format(time.time()))
PY
}

run_timed() {
  # usage: run_timed "<cmd...>"
  local cmd="$1"
  local t0 t1 dt
  t0=$(python3 - <<'PY'
import time
print(time.time())
PY
)
  # shellcheck disable=SC2086
  eval "$cmd" >/dev/null
  t1=$(python3 - <<'PY'
import time
print(time.time())
PY
)
  dt=$(python3 - <<PY
t0=float("$t0"); t1=float("$t1")
print("{:.6f}".format(t1-t0))
PY
)
  echo "$dt"
}

append_csv() {
  # program,impl,N,workers,unit,run_idx,time_s
  echo "$1,$2,$3,$4,$5,$6,$7" >> "$OUT"
}

# ================== header ==================
echo "program,impl,N,workers,unit,run_idx,time_s" > "$OUT"
echo "Запускаю бенчмарки, результаты -> $OUT"
echo "N=$N repeats=$REPEATS"

# ================== проверки ==================
for f in "$C_SERIAL" "$C_PTH" "$C_OMP" "$C_MPI" "fft_mpi.py"; do
  [[ -e "$f" ]] || { echo "Нет файла: $f (запусти make)"; exit 1; }
done

# ================== C serial ==================
echo "== C serial =="
for r in $(seq 1 "$REPEATS"); do
  t=$(run_timed "$C_SERIAL $N")
  echo "C/serial      N=$N run=$r t=${t}s"
  append_csv "fft_serial" "C/serial" "$N" 1 "threads" "$r" "$t"
done

# ================== C pthreads ==================
echo "== C pthreads (1..48) =="
for T in $SEQ_1_48; do
  for r in $(seq 1 "$REPEATS"); do
    t=$(run_timed "$C_PTH $N $T")
    echo "C/pthreads   N=$N T=$T run=$r t=${t}s"
    append_csv "fft_pthreads" "C/pthreads" "$N" "$T" "threads" "$r" "$t"
  done
done

# ================== C OpenMP ==================
echo "== C OpenMP (1..48) =="
for T in $SEQ_1_48; do
  export OMP_NUM_THREADS="$T"
  for r in $(seq 1 "$REPEATS"); do
    t=$(run_timed "$C_OMP $N")
    echo "C/openmp     N=$N T=$T run=$r t=${t}s"
    append_csv "fft_openmp" "C/openmp" "$N" "$T" "threads" "$r" "$t"
  done
done
unset OMP_NUM_THREADS

# ================== C MPI (OpenMPI) ==================
echo "== C MPI (OpenMPI) (1..48) =="
for P in $SEQ_1_48; do
  for r in $(seq 1 "$REPEATS"); do
    # ppr:1:node => нужно минимум P узлов; если у тебя меньше узлов в job — упадёт.
    cmd="$OMPI_RUN --mca btl ^openib -np $P --bind-to core --map-by ppr:1:node:PE=48 $C_MPI $N"
    t=$(run_timed "$cmd")
    echo "C/mpi        N=$N P=$P run=$r t=${t}s"
    append_csv "fft_mpi" "C/mpi" "$N" "$P" "processes" "$r" "$t"
  done
done

# ================== Python MPI (mpi4py, Intel mpirun) ==================
echo "== Python MPI (Intel mpirun) (1..48) =="
for P in $SEQ_1_48; do
  for r in $(seq 1 "$REPEATS"); do
    cmd="$IMPI_RUN -n $P $PY_MPI $N"
    t=$(run_timed "$cmd")
    echo "Py/mpi       N=$N P=$P run=$r t=${t}s"
    append_csv "fft_mpi" "Py/mpi" "$N" "$P" "processes" "$r" "$t"
  done
done

echo "Готово: $OUT"
