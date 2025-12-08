#!/bin/bash
# Бенчмарки FFT на tornado: C + OpenMP + pthreads + MPI (C и Python)
# Ожидается, что:
#   1) ты уже на вычислительном узле (n01p0xx), а не login1
#   2) загружены модули:
#        module purge
#        module load compiler/gcc/11
#        module load mpi/openmpi/4.1.6/gcc/11
#        module load python
#   3) ты находишься в каталоге ~/supercomp/scr/c
#
# Важно: Python/MPI ограничим и обернём в timeout, чтобы не вешать весь шаг.

set -u  # не set -e, чтобы скрипт не падал из-за одного фейла

N=${N:-1048576}
REPEATS=3

# Диапазоны
THREADS="1 2 4 8 16 32 48"     # для pthreads и OpenMP
MPI_PROCS="1 2 4 8 16 32"      # для C/MPI
MPI_PROCS_PY="1 2 4 8"         # для Python/MPI (чуть осторожнее)

# mpirun для C и для Python
OMPI_RUN=/opt/software/openmpi/4.1.6/gcc11/bin/mpirun
IMPI_RUN=/opt/software/intel/intelpython3/bin/mpirun
PY=python3
TIMEOUT=timeout                 # если timeout вдруг не найден -> закомментируй его в вызове ниже

OUT="bench_results_$(date +%Y%m%d_%H%M%S).csv"

echo "Запускаю бенчмарки, результаты -> $OUT"

echo "program,impl,N,workers,unit,run_idx,time_s" > "$OUT"

# ---------- Функция измерения времени ----------
measure() {
    # Используем /usr/bin/time и временный файл, чтобы получить число в секундах
    local tmp
    tmp=$(mktemp)
    /usr/bin/time -f "%e" -o "$tmp" "$@" >/dev/null 2>&1
    local t
    t=$(cat "$tmp" 2>/dev/null || echo "nan")
    rm -f "$tmp"
    echo "$t"
}

##### 1. C: последовательная версия #####
echo "== C serial =="
for r in $(seq 1 $REPEATS); do
    t=$(measure ./fft_serial "$N")
    printf "fft_serial,C/serial,%d,1,threads,%d,%.6f\n" "$N" "$r" "$t" >> "$OUT"
    echo "C/serial      N=$N run=$r   t=${t}s"
done

##### 2. C: pthreads #####
echo "== C pthreads =="
for T in $THREADS; do
    for r in $(seq 1 $REPEATS); do
        t=$(measure ./fft_pthreads "$N" "$T")
        printf "fft_pthreads,C/pthreads,%d,%d,threads,%d,%.6f\n" "$N" "$T" "$r" "$t" >> "$OUT"
        echo "C/pthreads   N=$N T=$T run=$r t=${t}s"
    done
done

##### 3. C: OpenMP #####
echo "== C OpenMP =="
for T in $THREADS; do
    export OMP_NUM_THREADS=$T
    for r in $(seq 1 $REPEATS); do
        t=$(measure ./fft_openmp "$N")
        printf "fft_openmp,C/openmp,%d,%d,threads,%d,%.6f\n" "$N" "$T" "$r" "$t" >> "$OUT"
        echo "C/OpenMP     N=$N T=$T run=$r t=${t}s"
    done
done

##### 4. C: MPI (OpenMPI) #####
echo "== C MPI (OpenMPI) =="
for P in $MPI_PROCS; do
    for r in $(seq 1 $REPEATS); do
        t=$(measure "$OMPI_RUN" -np "$P" ./fft_mpi "$N")
        printf "fft_mpi,C/mpi,%d,%d,processes,%d,%.6f\n" "$N" "$P" "$r" "$t" >> "$OUT"
        echo "C/MPI        N=$N P=$P run=$r t=${t}s"
    done
done

##### 5. Python: MPI (mpi4py + Intel MPI) #####
echo "== Python MPI (mpi4py, Intel mpirun) =="

# Проверяем один раз, что mpi4py импортируется
$PY -c "from mpi4py import MPI; print('mpi4py OK')" || {
    echo "WARNING: mpi4py не импортируется в $PY. Блок Python/MPI пропущен." >&2
    echo "Готово (без Python/MPI). CSV: $OUT"
    exit 0
}

for P in $MPI_PROCS_PY; do
    for r in $(seq 1 $REPEATS); do
        # Timeout, чтобы не повиснуть навсегда (120 секунд на один запуск)
        t=$(measure "$TIMEOUT" 120s "$IMPI_RUN" -n "$P" "$PY" fft_mpi.py "$N")
        printf "fft_mpi,Py/mpi,%d,%d,processes,%d,%.6f\n" "$N" "$P" "$r" "$t" >> "$OUT"
        echo "Py/MPI       N=$N P=$P run=$r t=${t}s"
    done
done

echo
echo "Готово. CSV: $OUT"
