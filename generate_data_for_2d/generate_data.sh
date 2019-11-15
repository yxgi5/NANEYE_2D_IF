#!/bin/bash

rm tmp.txt
rm frames.txt
for ((i=0; i<250; ++i))
do  
    echo $i
    cat 252PPsingleLine.txt >> tmp.txt
done

cat 251PPlastLine.txt >> tmp.txt

cat 4PPEnd_of_Frame.txt >> tmp.txt

cat 505PPConfig_phase.txt >> tmp.txt

cat 250PPTraining.txt >> tmp.txt

for ((i=0; i<10; ++i))
do  
    echo "frame "$i
    cat tmp.txt >> frames.txt
done

mv frames.txt ../data.dat
rm tmp.txt

echo "10 frames done!"
