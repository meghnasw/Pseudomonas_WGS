#!/bin/bash

# Change directory to the folder with the seq_data
#brew install brewsci/bio/shovill
#conda install -c bioconda quast
# conda install -c conda-forge -c bioconda -c defaults prokka

set -eo pipefail

echo "Starting WGS Pipeline for multiple samples"
echo "Order: Shovill (per sample) -> QUAST (all) -> Prokka (per sample)"
echo "================================================================="

mkdir -p results/assemblies_for_qc

########################################
# 1) Shovill per sample
########################################

for R1 in data/*_1_trimmed.fastq.gz
do
    sample=$(basename "$R1" | sed 's/_1_trimmed.fastq.gz//')
    R2="data/${sample}_2_trimmed.fastq.gz"

    echo
    echo "############################################"
    echo "Running Shovill for sample: $sample"
    echo "############################################"
    echo "[##--------] 20%  (Shovill running)"

    mkdir -p results/${sample}

    /usr/bin/time -l -o results/${sample}/benchmarking_shovill.log \
        shovill --outdir results/${sample}/shovill_out \
                --R1 "$R1" \
                --R2 "$R2" \
        > results/${sample}/shovill_output.log 2>&1

    # Copy contigs for multi-sample QC
    if [ -f "results/${sample}/shovill_out/contigs.fa" ]; then
        cp "results/${sample}/shovill_out/contigs.fa" "results/assemblies_for_qc/${sample}.fasta"
    else
        echo "WARNING: No contigs file found for ${sample}"
    fi
done

########################################
# 2) QUAST on all samples together
########################################
echo
echo "############################################"
echo "Running QUAST on all assemblies"
echo "############################################"
echo "[######----] 60%  (Running QUAST on all samples)"

mkdir -p results/quast_multi

/usr/bin/time -l -o benchmarking_quast_multi.log \
  quast results/assemblies_for_qc/*.fasta -o results/quast_multi \
  > quast_multi_output.log 2>&1

echo "[########--] 80%  (QUAST complete for all samples)"

########################################
# 3) Prokka per sample
########################################
for sample in "${samples[@]}"; do
    echo
    echo "############################################"
    echo "Running Prokka for sample: $sample"
    echo "############################################"
    echo "[#########-] 90%  (Running Prokka for $sample)"

    CONTIGS="results/assemblies_for_qc/${sample}.fasta"

    mkdir -p "results/${sample}/prokka_out"

    /usr/bin/time -l -o "results/${sample}/benchmarking_prokka.log" \
      prokka --outdir "results/${sample}/prokka_out" \
             --prefix "$sample" \
             "$CONTIGS" \
      > "results/${sample}/prokka_output.log" 2>&1

    echo "[##########] 100%  (Prokka complete for $sample)"
done

########################################
# 4) Combined benchmarking log
########################################
echo
echo "======================================"
echo "   Benchmarking summary (all steps)"
echo "======================================"

for sample in "${samples[@]}"; do
  {
    echo "======================================"
    echo "Benchmarking summary for $sample"
    echo "======================================"
    echo "--- Shovill ---"
    cat "results/${sample}/benchmarking_shovill.log"
    echo
    echo "--- Prokka ---"
    cat "results/${sample}/benchmarking_prokka.log"
    echo
    echo
  } >> benchmarking_all_steps.log
done

{
  echo "======================================"
  echo "Benchmarking summary for QUAST (all samples)"
  echo "======================================"
  cat benchmarking_quast_multi.log
  echo
} >> benchmarking_all_steps.log

cat benchmarking_all_steps.log

echo
echo "================================================================="
echo " All samples processed!"
echo " Combined benchmarking summary -> benchmarking_all_steps.log"
echo " Multi-sample QUAST report     -> results/quast_multi/"
echo " Per-sample Prokka output      -> results/<sample>/prokka_out/"
echo " Assemblies for QC             -> results/assemblies_for_qc/"
echo "================================================================="
