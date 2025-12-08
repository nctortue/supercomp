#!/usr/bin/env bash
#SBATCH -A your_account
#SBATCH -J fft_omp
#SBATCH -t 00:05:00
#SBATCH -N 1
#SBATCH -c 48
#SBATCH --exclusive

module load gcc/.. openmpi/.. # если нужно
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-48}

srun ./src/c/fft_openmp 1048576