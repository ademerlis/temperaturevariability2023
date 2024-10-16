# Bioinformatics pipelines for *A.cervicornis* and *P.clivosa* samples

Script written by: DeMerlis 

Last updated: 20230808

Note: the file/folder hierarchies and names may have changed since uploading this, as I seem to keep editing the hierarchy (even while scripts are running and then they fail!!). 

For each step of this analysis, I followed the pipelines of [Jill Ashey](https://github.com/JillAshey/SedimentStress/blob/master/Bioinf/RNASeq_pipeline_FL.md?plain=1), [Dr. Ariana Huffmyer](https://github.com/AHuffmyer/EarlyLifeHistory_Energetics/blob/master/Mcap2020/Scripts/TagSeq/Genome_V3/TagSeq_BioInf_genomeV3.md), [Dr. Sam Gurr](https://github.com/SamGurr/SamGurr.github.io/blob/master/_posts/2021-01-07-Geoduck-TagSeq-Pipeline.md), and [Zoe Dellaert](https://github.com/imkristenbrown/Heron-Pdam-gene-expression/blob/master/BioInf/ZD_Heron-Pdam-gene-expression.md). All code was adapted from them. 

**A.cervicornis**: [FastQC](https://github.com/ademerlis/temperaturevariability2023/tree/main/gene_expression/bioinformatics#2-qc-raw-reads) -> [Fastp](https://github.com/ademerlis/temperaturevariability2023/tree/main/gene_expression/bioinformatics#3-trim-files-using-fastp) -> [FastQC](https://github.com/ademerlis/temperaturevariability2023/tree/main/gene_expression/bioinformatics#4-qc-trimmed-reads) -> [HISAT2](https://github.com/ademerlis/temperaturevariability2023/tree/main/gene_expression/bioinformatics#4-index-acer-genome--align-experiment-reads-to-indexed-genome-using-hisat2) -> [StringTie](https://github.com/ademerlis/temperaturevariability2023/tree/main/gene_expression/bioinformatics#6-perform-gene-counts-with-stringtie) -> [DESeq2]()

**P.clivosa**: [FastQC](https://github.com/ademerlis/temperaturevariability2023/tree/main/gene_expression/bioinformatics#2-qc-raw-reads) -> [Fastp](https://github.com/ademerlis/temperaturevariability2023/tree/main/gene_expression/bioinformatics#3-trim-files-using-fastp) -> [FastQC](https://github.com/ademerlis/temperaturevariability2023/tree/main/gene_expression/bioinformatics#4-qc-trimmed-reads) -> [Salmon](https://github.com/ademerlis/temperaturevariability2023/blob/main/gene_expression/bioinformatics/README.md#9-salmon-index--quant-for-p-clivosa) -> [Tximport](https://github.com/ademerlis/temperaturevariability2023/blob/main/gene_expression/bioinformatics/Pcli/5_Pcli_txtimport.Rmd) -> ??????????


## 1) Download Data

I downloaded the BaseSpace GUI and downloaded the .fastq files for Acer and Pcli onto an external hard drive. Then, I uploaded them to the UM HPC Pegasus using 'scp'. 

## 2) QC Raw Reads

Can run FastQC module from Pegasus (version 0.10.1). 

```{bash}
#!/bin/bash
#BSUB -J fastqc
#BSUB -q bigmem
#BSUB -n 8
#BSUB -P and_transcriptomics
#BSUB -o fastqc_%J.out
#BSUB -e fastqc_%J.err
#BSUB -u allyson.demerlis@earth.miami.edu
#BSUB -N

and="/scratch/projects/and_transcriptomics"

module load fastqc/0.10.1

cd ${and}/Ch2_temperaturevariability2023/1_fastq_rawreads/

fastqc *.fastq.gz --outdir ${and}/Ch2_temperaturevariability2023/1_fastq_rawreads/fastqc_files_rawsequences
```

Install multiqc locally:
```{bash}
module load py-pip/20.2
pip install multiqc

nano ~/.bash_profile
export PATH=$PATH:/nethome/and128/.local/bin

#then save it and exit nano

source .bash_profile
#this runs the bash profile to update the paths
```

Then cd into fastqc_files_rawsequences and run `multiqc .`

I will transfer the multiqc_report.html to my local drive so I can open it and view it.

this code worked from transferring from pegasus to local (first navigated on local to the folder i wanted the report to go in):
```{bash}
Allysons-MacBook-Pro-2: allysondemerlis$ scp and128@pegasus.ccs.miami.edu:/scratch/projects/and_transcriptomics/multiqc_report.html .
```

## 3) Trim Files Using Fastp

First, install Fastp locally:
```{bash}
cd programs
# download the latest build
wget http://opengene.org/fastp/fastp
chmod a+x ./fastp
```

Then, run script to trim fastq.gz files and rename to "clean.{sample}.fastq.gz". 

"This script uses fastp to: 
- remove TagSeq-specific adapter sequences (--adapter_sequence=AGATCGGAAGAGCACACGTCTGAACTCCAGTCA)
- enable polyX trimming on 3' end at length of 6 (--trim_poly_x 6)
- filter by minimum phred quality score of >30  (-q 30)
- enable low complexity filter (-y)
- set complexity filter threshold of 50% required (-Y 50)" (explained by Dr. Sam Gurr)

Before submitting the job, make the following subdirectories for the output files:

```{bash}
mkdir ${and}/Ch2_temperaturevariability2023/fastp_processed/
mkdir ${and}/Ch2_temperaturevariability2023/trimmed_qc/
```

Then, create a script that creates a job for each sample (so they effectively run in parallel on the bigmem queue instead of one at a time -- runs way faster theoretically).

```{bash}
#BSUB -u and128@miami.edu

and="/scratch/projects/and_transcriptomics"
cd "/scratch/projects/and_transcriptomics/Ch2_temperaturevariability2023/1_fastq_rawreads"

data=($(ls *.gz))

for sample in ${data[@]} ;
do \
echo '#!/bin/bash' > "${and}"/Ch2_temperaturevariability2023/2_trimmed_reads/"${sample}"_fastp.job
echo '#BSUB -q bigmem' >> "${and}"/Ch2_temperaturevariability2023/2_trimmed_reads/"${sample}"_fastp.job
echo '#BSUB -J '"${sample}"_fastp'' >> "${and}"/Ch2_temperaturevariability2023/2_trimmed_reads/"${sample}"_fastp.job
echo '#BSUB -o '"${and}"/Ch2_temperaturevariability2023/2_trimmed_reads/"$sample"_fastp%J.out'' >> "${and}"/Ch2_temperaturevariability2023/2_trimmed_reads/"${sample}"_fastp.job
echo '#BSUB -e '"${and}"/Ch2_temperaturevariability2023/2_trimmed_reads/"$sample"_fastp%J.err'' >> "${and}"/Ch2_temperaturevariability2023/2_trimmed_reads/"${sample}"_fastp.job
echo '#BSUB -n 8' >> "${and}"/Ch2_temperaturevariability2023/2_trimmed_reads/"${sample}"_fastp.job
echo '#BSUB -N' >> "${and}"/Ch2_temperaturevariability2023/2_trimmed_reads/"${sample}"_fastp.job
echo 'module load fastqc/0.10.1' >> "${and}"/Ch2_temperaturevariability2023/2_trimmed_reads/"${sample}"_fastp.job
echo '/scratch/projects/and_transcriptomics/programs/fastp '--in1 "${sample}" --out1 "${and}"/Ch2_temperaturevariability2023/fastp_processed/clean."${sample}" -h report_"${sample}".html -j "${sample}"_fastp.json --adapter_sequence=AGATCGGAAGAGCACACGTCTGAACTCCAGTCA --trim_poly_x 6 -q 30 -y -Y 50'' >> "${and}"/Ch2_temperaturevariability2023/2_trimmed_reads/"${sample}"_fastp.job
echo 'fastqc '"${and}"/Ch2_temperaturevariability2023/fastp_processed/clean."${sample}" -o "${and}"/Ch2_temperaturevariability2023/trimmed_qc_files/'' >> "${and}"/Ch2_temperaturevariability2023/2_trimmed_reads/"${sample}"_fastp.job
bsub < "${and}"/Ch2_temperaturevariability2023/2_trimmed_reads/"${sample}"_fastp.job ; \
done
```

## 4) QC Trimmed Reads

I added the fastqc part to the trimming script above. So I just ran `multiqc .` in the directory where those fastqc files were generated.

 (installed it locally on Pegasus scratch space and to PATH variable)

MultiQC reports can be found in the [QC folder](https://github.com/ademerlis/temperaturevariability2023/tree/main/gene_expression/bioinformatics/QC). 

## 3) Download Genome [*Acropora cervicornis*](https://usegalaxy.org/u/skitch/h/acervicornis-genome) 

Obtained from [Baums lab](http://baumslab.org/research/data/) with permission from Dr. Sheila Kitchen. Using Version v1.0_171209

Genome file: `Acerv_assembly_v1.0_171209.fasta`

GFF file: `Acerv_assembly_v1.0.gff3`

Protein file: `Acerv_assembly_v1.0.protein.fa`

Transcript file: `Acerv_assembly_v1.0.mRNA.fa`

## 4) Index Acer Genome + Align Experiment Reads to Indexed Genome Using HISAT2 

Install HISAT2 locally (version 2.2.1)
```{bash}
cd programs
# download the latest build
wget https://cloud.biohpc.swmed.edu/index.php/s/fE9QCsX3NH4QwBi/download
cd hisat2-2.2.1/
make .
# also add it to your ~/.bash_profile PATH
```

Then submit this job to Pegasus.

```{bash}
#!/bin/bash
#BSUB -J HISAT2
#BSUB -q bigmem
#BSUB -n 16
#BSUB -P and_transcriptomics
#BSUB -o HISAT2%J.out
#BSUB -e HISAT2%J.err
#BSUB -u and128@miami.edu
#BSUB -N

and="/scratch/projects/and_transcriptomics"

module load samtools/1.3
module load python/3.8.7

/scratch/projects/and_transcriptomics/programs/hisat2-2.2.1/hisat2-build -f ${and}/genomes/Acer/Acerv_assembly_v1.0_171209.fasta ${and}/genomes/Acer/Acer_reference_genome_hisat2
echo "Reference genome indexed. Starting alignment" $(date)

cd /scratch/projects/and_transcriptomics/Ch2_temperaturevariability2023/2_trimmed_reads/Acer_fastq_files
array=($(ls *.fastq.gz))
for i in ${array[@]};
 do \
        sample_name=`echo $i| awk -F [.] '{print $2}'`
	/scratch/projects/and_transcriptomics/programs/hisat2-2.2.1/hisat2 -p 8 --dta -x ${and}/genomes/Acer/Acer_reference_genome_hisat2 -U ${i} -S ${sample_name}.sam
        samtools sort -@ 8 -o ${sample_name}.bam ${sample_name}.sam
    		echo "${i} bam-ified!"
        rm ${sample_name}.sam ; 
done
```

To obtain mapping percentages (percent alignment):
```{bash}
module load samtools/1.3

for i in *.bam; do
    echo "${i}" >> mapped_reads_counts_Acer
    samtools flagstat ${i} | grep "mapped (" >> mapped_reads_counts_Acer
done
```

Manually copied these percentages into the [RNA extraction and sequencing results csv](https://github.com/ademerlis/temperaturevariability2023/blob/main/gene_expression/RNA%20_extraction_sequencing_data.csv).

## 5) Update .gff3 File for StringTie

I had to manually edit the .gff3 file to make sure the Transcript_ID and Parent_ID were labelled correctly so the IDs match up to the alignment files. R code to edit gff3 file:

```{r}
# Title: A. cervicornis GFF adjustments
# Project: Sedimentation RNA-Seq / Mcap 2020
# Author: J. Ashey / A. Huffmyer -> Allyson DeMerlis
# Date: 06/28/2023

# Need to do some acerv gff adjustments so it can run properly for alignment.

#Load libraries
library(tidyverse)

#Load  gene gff
Acerv.gff <- read.csv(file="Downloads/Galaxy1-[Acerv_assembly_v1.0.gff3].gff3", header=FALSE, sep="\t", skip=1) 

#rename columns
colnames(Acerv.gff) <- c("scaffold", "Gene.Predict", "id", "gene.start","gene.stop", "pos1", "pos2","pos3", "gene")
head(Acerv.gff)

# Creating transcript id
Acerv.gff$transcript_id <- sub(";.*", "", Acerv.gff$gene)
Acerv.gff$transcript_id <- gsub("ID=", "", Acerv.gff$transcript_id) #remove ID= 
Acerv.gff$transcript_id <- gsub("Parent=", "", Acerv.gff$transcript_id) #remove Parent=
head(Acerv.gff)

# Create Parent ID 
Acerv.gff$parent_id <- sub(".*Parent=", "", Acerv.gff$gene)
Acerv.gff$parent_id <- sub(";.*", "", Acerv.gff$parent_id)
Acerv.gff$parent_id <- gsub("ID=", "", Acerv.gff$parent_id) #remove ID= 
head(Acerv.gff)

Acerv.gff <- Acerv.gff %>% 
  mutate(gene = ifelse(id != "gene", paste0(gene, ";transcript_id=", Acerv.gff$transcript_id, ";gene_id=", Acerv.gff$parent_id),  paste0(gene)))
head(Acerv.gff)

Acerv.gff<-Acerv.gff %>%
  select(!transcript_id)%>%
  select(!parent_id)

#save file
write.table(Acerv.gff, file="~/Downloads/Acerv.GFFannotations.fixed_transcript_take3.gff3", sep="\t", col.names = FALSE, row.names=FALSE, quote=FALSE)
```

## 6) Perform Gene Counts with StringTie 

Install Stringtie (version X) and gffcompare (version X) locally onto Pegasus scratch space.

```{bash}
wget http://ccb.jhu.edu/software/stringtie/dl/stringtie-2.2.1.tar.gz
tar xvfz stringtie-2.2.1.tar.gz
cd stringtie-2.2.1
make release

wget http://ccb.jhu.edu/software/stringtie/dl/gffcompare-0.12.6.Linux_x86_64.tar.gz
tar xvfz gffcompare-0.12.6.Linux_x86_64.tar.gz

```

Then, assemble and estimate reads using aligned .bam files and updated .gff3 file.

```{bash}
#!/bin/bash
#BSUB -J stringtie2_postHISAT2
#BSUB -q general
#BSUB -P and_transcriptomics
#BSUB -o stringtie2_postHISAT2%J.out
#BSUB -e stringtie2_postHISAT2%J.err
#BSUB -u and128@miami.edu
#BSUB -N

module load python/3.8.7

and="/scratch/projects/and_transcriptomics"

cd "/scratch/projects/and_transcriptomics/Ch2_temperaturevariability2023/3_Acer_specific/Acer_aligned_bam_files"

data=($(ls *.bam))

for i in ${data[@]} ;

do \
/scratch/projects/and_transcriptomics/programs/stringtie-2.2.1/stringtie -p 8 -e -B -G /scratch/projects/and_transcriptomics/genomes/Acer/Acerv.GFFannotations.fixed_transcript_take3.gff3 -A ${i}.gene_abund.tab -o ${i}.gtf ${i}
echo "StringTie assembly for seq file ${i}" $(date) ; \
done
echo "StringTie assembly COMPLETE, starting assembly analysis" $(date)
```

Then, merge StringTie results and obtain gene counts matrix. 

```{bash}
#!/bin/bash
#BSUB -J stringtie_mergegtf
#BSUB -q general
#BSUB -P and_transcriptomics
#BSUB -o stringtie_mergegtf%J.out
#BSUB -e stringtie_mergegtf%J.err
#BSUB -u and128@miami.edu
#BSUB -N

module load python/3.8.7

and="/scratch/projects/and_transcriptomics"

cd "/scratch/projects/and_transcriptomics/Ch2_temperaturevariability2023/3_Acer_specific/Acer_aligned_bam_files"

ls *.gtf > gtf_list.txt

${and}/programs/stringtie-2.2.1/stringtie --merge -e -p 8 -G ${and}/genomes/Acer/Acerv.GFFannotations.fixed_transcript_take3.gff3 -o stringtie_acerv_merged.gtf gtf_list.txt
echo "Stringtie merge complete" $(date)

/scratch/projects/and_transcriptomics/programs/gffcompare-0.12.6.Linux_x86_64/gffcompare -r ${and}/genomes/Acer/Acerv.GFFannotations.fixed_transcript_take3.gff3 -G -o merged stringtie_acerv_merged.gtf
echo "GFFcompare complete, Starting gene count matrix assembly..." $(date)

for filename in *bam.gtf; do echo $filename $PWD/$filename; done > listGTF.txt

python ${and}/programs/stringtie-2.2.1/prepDE.py -g gene_count_acerv_matrix.csv -i listGTF.txt 

echo "Gene count matrix compiled." $(date)
```

## 7) Obtain *P. clivosa* Transcriptome

The transcriptome was generated by [Avila-Magana et al. 2021](https://www.nature.com/articles/s41467-021-25950-4) using Trinity and assembled *de novo* as a meta-transcriptome (with all the host + symbiont associations sequenced in one). 

From their [Dryad repository page](https://datadryad.org/stash/dataset/doi:10.5061/dryad.k3j9kd57b), I downloaded the files "Dip_Host.fna.gz" and "Dip_Host.fna.emapper.annotations.bz2".

## 8) Editing Fasta file

I had to edit the Dip_Host.fna.gz file because when it was assembled in Trinity, it added Trinity-specific things that we don't need for pseudoalignment (len= and path=). See [my blog post](https://github.com/ademerlis/ademerlis.github.io/blob/master/_posts/2023-07-25_usingPcli_transcriptome.md) for details. 

I ran this code:

```{bash}
gunzip Dip_Host.fna.gz
sed '/^>/ s/ len=[0-9]* path=\[[^]]*\]//' Dip_Host.fna > clean_transcriptome.fasta
sed '/^>/ s/ \[.*\]//' clean_Pcli_transcriptome.fasta > clean_Pcli_transcriptome_final.fasta
```

It went from looking like this to this:
![image](https://github.com/ademerlis/temperaturevariability2023/assets/56000927/101f1e8b-bedb-4e19-9abd-70e87383c817)

![image](https://github.com/ademerlis/temperaturevariability2023/assets/56000927/e83f101e-a0a1-475e-baab-fe157c081822)

## 9) Salmon Index + Quant for *P. clivosa* 

So I installed Salmon locally onto my scratch space by downloading the Linux binary package:

```{bash}
wget https://github.com/COMBINE-lab/salmon/releases/download/v1.5.2/salmon-1.5.2_linux_x86_64.tar.gz
tar -xzvf salmon-1.5.2_linux_x86_64.tar.gz
cd salmon-1.5.2_linux_x86_64/bin/
#salmon is green so that means it is already compiled
#add to PATH
nano ~/.bash_profile
source ~/.bash_profile
#check it works:
salmon-1.5.2_linux_x86_64/bin/salmon --verson
```

Then ran this for indexing the transcriptome:

```{bash}
#!/bin/bash
#BSUB -J Pcli_transcriptome_salmon_index
#BSUB -q general
#BSUB -P and_transcriptomics
#BSUB -n 8
#BSUB -o Pcli_transcriptome_salmon_index%J.out
#BSUB -e Pcli_transcriptome_salmon_index%J.err
#BSUB -u and128@miami.edu
#BSUB -N

and="/scratch/projects/and_transcriptomics"

${and}/programs/salmon-1.5.2_linux_x86_64/bin/salmon index -t ${and}/genomes/Pcli/clean_Pcli_transcriptome_final.fasta -i ${and}/genomes/Pcli/Pcli_transcriptome_index
```

Then I ran the salmon quant step as a loop, so that each sample got it's own job submitted (and it ran much faster):

```{bash}
#BSUB -u and128@miami.edu

#specify variables and paths

and="/scratch/projects/and_transcriptomics"

cd "/scratch/projects/and_transcriptomics/Ch2_temperaturevariability2023/AS_pipeline/3_trimmed_fastq_files/Pcli_fastq_files"

data=($(ls *.gz))

for sample in ${data[@]} ;

do \
echo "Aligning ${sample}"

echo '#!/bin/bash' > "${and}"/Ch2_temperaturevariability2023/AS_pipeline/4_Pcli_specific/scripts/"${sample}"_salmonquant.job
echo '#BSUB -q bigmem' >> "${and}"/Ch2_temperaturevariability2023/AS_pipeline/4_Pcli_specific/scripts/"${sample}"_salmonquant.job
echo '#BSUB -J '"${sample}"_salmonquant'' >> "${and}"/Ch2_temperaturevariability2023/AS_pipeline/4_Pcli_specific/scripts/"${sample}"_salmonquant.job
echo '#BSUB -o '"${and}"/Ch2_temperaturevariability2023/AS_pipeline/4_Pcli_specific/scripts/"$sample"_salmonquant%J.out'' >> "${and}"/Ch2_temperaturevariability2023/AS_pipeline/4_Pcli_specific/scripts/"${sample}"_salmonquant.job
echo '#BSUB -e '"${and}"/Ch2_temperaturevariability2023/AS_pipeline/4_Pcli_specific/scripts/"$sample"_salmonquant%J.err'' >> "${and}"/Ch2_temperaturevariability2023/AS_pipeline/4_Pcli_specific/scripts/"${sample}"_salmonquant.job
echo '#BSUB -n 8' >> "${and}"/Ch2_temperaturevariability2023/AS_pipeline/4_Pcli_specific/scripts/"${sample}"_salmonquant.job
echo '#BSUB -N' >> "${and}"/Ch2_temperaturevariability2023/AS_pipeline/4_Pcli_specific/scripts/"${sample}"_salmonquant.job

echo ${and}/programs/salmon-1.5.2_linux_x86_64/bin/salmon quant -i \ ${and}/genomes/Pcli/Pcli_transcriptome_index -l U -r ${sample} \
--validateMappings \
-o ${and}/Ch2_temperaturevariability2023/AS_pipeline/4_Pcli_specific/salmon_quant_files/"${sample}"_salmonquant >> "${and}"/Ch2_temperaturevariability2023/AS_pipeline/4_Pcli_specific/scripts/"${sample}"_salmonquant.job

echo 'echo' "Salmon quantification of $sample complete"'' >> "${and}"/Ch2_temperaturevariability2023/AS_pipeline/4_Pcli_specific/scripts/"${sample}"_salmonquant.job
echo "Salmon quantification script of $sample submitted"
bsub < "${and}"/Ch2_temperaturevariability2023/AS_pipeline/4_Pcli_specific/scripts/"${sample}"_salmonquant.job ; \
done
```
