#!/usr/bin/env bash
#SBATCH -A your_account
#SBATCH -J fft_mpi
#SBATCH -t 00:10:00
#SBATCH -N 3
#SBATCH --ntasks=96
#SBATCH --cpus-per-task=1
#SBATCH --exclusive

module load gcc/.. openmpi/..

srun ./src/c/fft_mpi 1048576