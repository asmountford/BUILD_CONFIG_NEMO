#!/bin/bash

#module load  nco/4.7.9-gcc-4.8.5-hdf5-1.8.18-openmpi-2.0.4

CONFIG="ROSS025"
BDY_DIR="/work/n02/n02/asmou/NEMORC/cfgs/ROSS025_4.2/NEW/BDY"
YEARi=1979
YEARf=1979

#----------------------------------------------------------------------------

for BDY in bdyT_tra bdyU_u3d bdyU_u2d bdyV_u3d bdyV_u2d bdyT_ice bdyT_ssh
#for BDY in bdyU_u3d bdyU_u2d bdyV_u3d bdyV_u2d
do

for YEAR in $(seq $YEARi $YEARf)
do

  ncrcat ${BDY_DIR}/${BDY}_${YEAR}_*_${CONFIG}.nc ${BDY_DIR}/${BDY}_y${YEAR}_${CONFIG}.nc
  if [ -f ${BDY_DIR}/${BDY}_y${YEAR}_${CONFIG}.nc ]; then
    rm -f ${BDY_DIR}/${BDY}_${YEAR}_*_${CONFIG}.nc
    echo "${BDY_DIR}/${BDY}_y${YEAR}_${CONFIG}.nc  [oK]"
  else
    echo "~!@#%^&* ERROR: ${BDY_DIR}/${BDY}_y${YEAR}_${CONFIG}.nc HAS NOT BEEN CREATED   >>>>> STOP !!"
    exit
  fi

done

done
