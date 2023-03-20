#!/bin/tcsh
# 
#PBS -N lfs1_transition
#PBS -M Jeffrey.A.Hamilton@noaa.gov
#PBS -m a
#PBS -A amb-verif
#PBS -l procs=1
#PBS -l partition=tjet:ujet:sjet:vjet:xjet
#PBS -q service
#PBS -l walltime=07:59:00
#PBS -l vmem=2G
#PBS -d .
#PBS -e tmp/
#PBS -o tmp/

echo "START:"
date
rsync -auv /lfs3/projects/amb-verif/realtime/cref /lfs1/projects/amb-verif/realtime
echo "Done with cref:"
date
rsync -auv /lfs3/projects/amb-verif/realtime/etp /lfs1/projects/amb-verif/realtime
echo "Done with etp:"
date
rsync -auv /lfs3/projects/amb-verif/realtime/precip /lfs1/projects/amb-verif/realtime
echo "Done with precip:"
date
rsync -auv /lfs3/projects/amb-verif/realtime/prob /lfs1/projects/amb-verif/realtime
echo "Done with prob:"
date
rsync -auv /lfs3/projects/amb-verif/realtime/surface /lfs1/projects/amb-verif/realtime
echo "Done with surface:"
date
rsync -auv /lfs3/projects/amb-verif/realtime/test /lfs1/projects/amb-verif/realtime
echo "Done with test:"
date
rsync -auv /lfs3/projects/amb-verif/realtime/vil /lfs1/projects/amb-verif/realtime
echo "Done with vil:"
date
rsync -auv /lfs3/projects/amb-verif/realtime/web /lfs1/projects/amb-verif/realtime
echo "Done with web:"
echo "END:"
date

