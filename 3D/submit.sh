#!/bin/bash
#SBATCH --partition=rack4               # -p, first available from the list of partitions
#SBATCH --time=08:00:00                 # -t, time (hh:mm:ss or dd-hh:mm:ss)
#SBATCH --nodes=1                       # -N, total number of machines
#SBATCH --ntasks=1                      # -n, 64 MPI ranks per Opteron machine
#SBATCH --cpus-per-task=10               # threads per MPI rank
#SBATCH --job-name=nu-1_0_r2_cutoff-20                 # -J, for your records
#SBATCH --chdir=/working/wd15/active-learning/3D   # -D, full path to an existing directory
#SBATCH --qos=test
#SBATCH --mem=0G
#SBATCH --output=log/slurm-%j.out

job_name="job_2023-09-12_id-${SLURM_JOB_ID}_nu-1_0_r2_cutoff-20_v001"
reason="run with nu=1.0 and cutoff of 20"
nu=1.0
cutoff=20

~/bin/nix-root nix develop ../flake.nix --command bash -c "snakemake \
  --nolock \
  --cores 10 \
  --config \
  job_name=$job_name \
  n_iterations=20 \
  n_query=400 \
  nu=$nu \
  scoring=r2 \
  cutoff=$cutoff \
  reason=\"$reason\" \
"


	
