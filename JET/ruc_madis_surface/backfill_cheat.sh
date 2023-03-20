#!/bin/bash

#usage: $1 is model, $2 is hours_ago_start, $3 is hours_ago_end

i=$2

while [ $i -ge $3 ]
do
echo "--------------------------------------------------------"
echo "Executing surface_driver_q1.pl $1 -$i 0 METAR"
$HOME/ruc_madis_surface/surface_driver_q1.pl $1 -$i 1 METAR
i=$[$i-1]
done

echo "backfill script completed"
