#!/bin/bash
#SBATCH --job-name=bdy_T
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=24
#SBATCH --account=n02-TiPACCs
#SBATCH --partition=standard
#SBATCH --qos=standard
# Created by: mkslurm -S 0 -s 0 -m 2 -C  24 -c  2 -t 00:10:00 -a n01 -j nemo_test

export OMP_NUM_THREADS=1
#
cat > myscript_wrapper2.sh << EOFB
#!/bin/ksh
#
set -A map ./xios_server.exe ./extract_bdy_gridT
# change script name above
exec_map=( 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 )
#
exec \${map[\${exec_map[\$SLURM_PROCID]}]} 
##
EOFB
chmod u+x ./myscript_wrapper2.sh
#
srun --mem-bind=local --cpu-bind=v,map_cpu:00,0x2,0x4,0x6,0x8,0xa,0xc,0xe,0x10,0x12,0x14,0x16,0x18,0x1a,0x1c,0x1e,0x20,0x22,0x24,0x26,0x28,0x2a,0x2c,0x2e, ./myscript_wrapper2.sh
