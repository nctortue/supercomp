#!/usr/bin/env bash
# Benchmark C (serial/pthreads/OpenMP/MPI) + Python (любой .py в каталоге)
set -euo pipefail

# --- CONFIG ---
N_LIST=(1048576)            # можно добавить 4194304 и т.п.
THREADS_LIST=(1 2 4 8 16)   # для pthreads/OpenMP
MPI_LIST=(1 2 4 8 16)       # для MPI (C и Python mpi4py)
REPEATS=3

# Путь к Python-скриптам (перекрывается --py-dir)
PY_DIR="/Users/kikita/Desktop/Jeremy/university/maga1/supercomp/main_task/scr/py"

# --- PATHS ---
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_SERIAL="$BASE_DIR/fft_serial"
BIN_PTHREADS="$BASE_DIR/fft_pthreads"
BIN_OPENMP="$BASE_DIR/fft_openmp"
BIN_MPI="$BASE_DIR/fft_mpi"

STAMP=$(date +"%Y%m%d_%H%M%S")
OUT_CSV="$BASE_DIR/bench_results_${STAMP}.csv"

# --- helpers ---
have() { command -v "$1" >/dev/null 2>&1; }
measure_time() { local TIMEFORMAT='%R'; { time "$@" 1>/dev/null; } 2>&1 | tail -n1; }
append_header(){ echo "program,impl,N,workers,unit,run_idx,time_s" > "$OUT_CSV"; }
append_row(){ echo "$1,$2,$3,$4,$5,$6,$7" >> "$OUT_CSV"; }

# --- args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --py-dir) PY_DIR="$2"; shift 2;;
    *) echo "Unknown arg: $1"; exit 2;;
  esac
done

echo "=> Results CSV: $OUT_CSV"
echo "=> PY_DIR: $PY_DIR"
append_header

# ---------- C: serial ----------
if [[ -x "$BIN_SERIAL" ]]; then
  for N in "${N_LIST[@]}"; do
    for r in $(seq 1 "$REPEATS"); do
      t=$(measure_time "$BIN_SERIAL" "$N")
      append_row "fft_serial" "C/serial" "$N" 1 "threads" "$r" "$t"
      echo "C/serial      N=$N run=$r   t=${t}s"
    done
  done
else
  echo "WARN: $BIN_SERIAL not found"
fi

# ---------- C: pthreads ----------
if [[ -x "$BIN_PTHREADS" ]]; then
  for N in "${N_LIST[@]}"; do
    for T in "${THREADS_LIST[@]}"; do
      for r in $(seq 1 "$REPEATS"); do
        t=$(measure_time "$BIN_PTHREADS" "$N" "$T")
        append_row "fft_pthreads" "C/pthreads" "$N" "$T" "threads" "$r" "$t"
        echo "C/pthreads    N=$N T=$T run=$r t=${t}s"
      done
    done
  done
else
  echo "WARN: $BIN_PTHREADS not found"
fi

# ---------- C: OpenMP ----------
if [[ -x "$BIN_OPENMP" ]]; then
  for N in "${N_LIST[@]}"; do
    for T in "${THREADS_LIST[@]}"; do
      for r in $(seq 1 "$REPEATS"); do
        TTIME=$( ( export OMP_NUM_THREADS="$T"; measure_time "$BIN_OPENMP" "$N" ) )
        append_row "fft_openmp" "C/OpenMP" "$N" "$T" "threads" "$r" "$TTIME"
        echo "C/OpenMP      N=$N T=$T run=$r t=${TTIME}s"
      done
    done
  done
else
  echo "WARN: $BIN_OPENMP not found"
fi

# ---------- C: MPI ----------
if [[ -x "$BIN_MPI" ]] && have mpirun; then
  for N in "${N_LIST[@]}"; do
    for P in "${MPI_LIST[@]}"; do
      for r in $(seq 1 "$REPEATS"); do
        t=$(measure_time mpirun -np "$P" "$BIN_MPI" "$N")
        append_row "fft_mpi" "C/MPI" "$N" "$P" "processes" "$r" "$t"
        echo "C/MPI         N=$N P=$P run=$r t=${t}s"
      done
    done
  done
else
  echo "WARN: mpirun or $BIN_MPI not found"
fi

# ---------- PYTHON: авто-обнаружение скриптов ----------
if [[ -d "$PY_DIR" ]] && have python3; then
  echo "Scanning Python dir: $PY_DIR"
  # возьмём все .py, кроме служебных
  mapfile -t PY_SCRIPTS < <(find "$PY_DIR" -maxdepth 1 -type f -name "*.py" ! -name "__init__.py" | sort)
  if [[ ${#PY_SCRIPTS[@]} -eq 0 ]]; then
    echo "INFO: no .py scripts in $PY_DIR"
  else
    for SCRIPT in "${PY_SCRIPTS[@]}"; do
      BASE="$(basename "$SCRIPT")"
      LOWER="${BASE,,}"   # to lowercase
      # эвристика: если в имени есть 'mpi', считаем что это mpi4py-скрипт
      if [[ "$LOWER" == *mpi* ]] && have mpirun; then
        MODE="Python/mpi4py"
        echo "Found Python MPI: $SCRIPT"
        for N in "${N_LIST[@]}"; do
          for P in "${MPI_LIST[@]}"; do
            for r in $(seq 1 "$REPEATS"); do
              t=$(measure_time mpirun -np "$P" python3 "$SCRIPT" "$N")
              append_row "$BASE" "$MODE" "$N" "$P" "processes" "$r" "$t"
              echo "Py/mpi4py     $(printf '%-18s' "$BASE") N=$N P=$P run=$r t=${t}s"
            done
          done
        done
      else
        MODE="Python/serial"
        echo "Found Python serial: $SCRIPT"
        for N in "${N_LIST[@]}"; do
          for r in $(seq 1 "$REPEATS"); do
            t=$(measure_time python3 "$SCRIPT" "$N")
            append_row "$BASE" "$MODE" "$N" 1 "threads" "$r" "$t"
            echo "Py/serial     $(printf '%-18s' "$BASE") N=$N run=$r t=${t}s"
          done
        done
      fi
    done
  fi
else
  echo "INFO: python3 or directory $PY_DIR not available"
fi

echo
echo "✅ Done. CSV -> $OUT_CSV"
