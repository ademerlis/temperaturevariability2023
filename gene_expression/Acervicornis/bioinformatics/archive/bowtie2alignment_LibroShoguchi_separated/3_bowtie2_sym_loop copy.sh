#! /usr/bin/env bash

#define variables for directories and files
and="/scratch/projects/and_transcriptomics"
project="and_transcriptomics"
projdir="/scratch/projects/and_transcriptomics/Ch2_temperaturevariability2023/2_trimmed_reads/take_4/trimmed_files/Acer"

cd "/scratch/projects/and_transcriptomics/Ch2_temperaturevariability2023/2_trimmed_reads/take_4/trimmed_files/Acer"

data=($(ls *.trim))

for samp in "${data[@]}" ; do \

#build script
echo "making bowtie2-align script for ${samp}..."
echo "
#! /usr/bin/env bash
#BSUB -P ${project}
#BSUB -J ${samp}_align_Sym
#BSUB -e ${projdir}/logs/${samp}_align_Sym.err
#BSUB -o ${projdir}/logs/${samp}_align_Sym.out
#BSUB -W 12:00
#BSUB -n 8
#BSUB -q general

cd \"/scratch/projects/and_transcriptomics/Ch2_temperaturevariability2023/2_trimmed_reads/take_4/trimmed_files/Acer\"

bowtie2 --local -U ${samp} -x Syma_index -S ${samp}.sam --no-hd --no-sq --no-unal --al symbionts/${samp}.fastq.sym --un ./${samp}.fastq.host

" > ${projdir}/${samp}_align_Symb.job

bsub < ${projdir}/${samp}_align_Symb.job

done