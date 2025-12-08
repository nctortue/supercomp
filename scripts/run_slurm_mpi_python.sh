#!/usr/bin/env bash
#SBATCH -A your_account
#SBATCH -J fft_py_mpi
#SBATCH -t 00:05:00
#SBATCH -N 3
#SBATCH --ntasks=96

module load python/.. mpi4py/..

srun python3 ./src/py/fft_mpi.py 1048576