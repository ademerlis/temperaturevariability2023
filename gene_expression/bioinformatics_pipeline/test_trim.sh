#!/bin/bash
#BSUB -J trim
#BSUB -q bigmem
#BSUB -P and_transcriptomics
#BSUB -n 16
#BSUB -W 120:00
#BSUB -o trim.out
#BSUB -e trim.err
#BSUB -u and128@miami.edu
#BSUB -N

and="/scratch/projects/and_transcriptomics"

cd "/scratch/projects/and_transcriptomics/Ch2_temperaturevariability2023/1_fastq_rawreads"

fq="$1"

if [ -z "$fq" ]; then
    echo "$usage" >&2
    exit 1
fi

# Check if the Fastq file is gzipped and gunzip it if needed
if [[ "$fq" == *.gz ]]; then
    gunzip -c "$fq" > temp.fastq
    fq="temp.fastq"
fi

lead="${2:-[ATGC]?[ATGC][AC][AT][AT][AC][AT][ACT]GGG+|[ATGC]?[ATGC][AC][AT]GGG+|[ATGC]?[ATGC]TGC[AC][AT]GGG+|[ATGC]?[ATGC]GC[AT]TC[ACT][AC][AT]GGG+}"

trim=0
name=""
name2=""
seq=""
qua=""
declare -A seen
ll=3
nohead=0
dups=0
ntag=0
tot=0
goods=0

while IFS= read -r line; do
    if [ "$ll" -eq 3 ] && [[ "$line" =~ ^@(.+)$ ]]; then
        tot=$((tot + 1))
        name2="${BASH_REMATCH[1]}"
        if [[ "$seq" =~ ^($lead)(.+) ]]; then
            start="${BASH_REMATCH[2]:0:20}"
            idtag="${BASH_REMATCH[1]}$start"
            if [ -z "${seen[$idtag]}" ] && [[ "$idtag" != *N* ]]; then
                seen["$idtag"]=1
                trim="${#BASH_REMATCH[1]}"
                echo "$name"
                echo "${BASH_REMATCH[2]}"
                echo "+"
                echo "${qua:trim}"
                goods=$((goods + 1))
            elif [ -n "${seen[$idtag]}" ]; then
                dups=$((dups + 1))
            else
                ntag=$((ntag + 1))
            fi
        elif [ "$tot" -gt 1 ]; then
            nohead=$((nohead + 1))
        fi
        seq=""
        ll=0
        qua=""
        name="$name2"
    elif [ "$ll" -eq 0 ]; then
        seq="$line"
        ll=1
    elif [ "$ll" -eq 2 ]; then
        qua="$line"
        ll=3
    else
        ll=2
    fi
done < "$fq"

if [[ "$seq" =~ ^($lead)(.+) ]]; then
    start="${BASH_REMATCH[2]:0:20}"
    idtag="${BASH_REMATCH[1]}$start"
    if [ -z "${seen[$idtag]}" ] && [[ "$idtag" != *N* ]]; then
        seen["$idtag"]=1
        trim="${#BASH_REMATCH[1]}"
        echo "$name"
        echo "${BASH_REMATCH[2]}"
        echo "+"
        echo "${qua:trim}"
        goods=$((goods + 1))
    elif [ -n "${seen[$idtag]}" ]; then
        dups=$((dups + 1))
    else
        ntag=$((ntag + 1))
    fi
elif [ "$tot" -gt 1 ]; then
    nohead=$((nohead + 1))
fi

echo "$fq	total:$tot	goods:$goods	dups:$dups	noheader:$nohead	N.in.header:$ntag"