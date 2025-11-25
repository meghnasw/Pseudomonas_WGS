#!/bin/bash

# Change directory to the folder with the seq_data
#brew install brewsci/bio/shovill
#conda install -c bioconda quast
# conda install -c conda-forge -c bioconda -c defaults prokka

#!/bin/bash

set -euo pipefail

echo "Starting WGS Pipeline for multiple samples"
echo "Order: Shovill (per sample) -> QUAST (all) -> BUSCO (all) -> CheckM (all) -> Prokka (per sample)"
echo "==============================================================================================="

# Folder to collect all assemblies for QUAST/BUSCO/CheckM
mkdir -p results/assemblies_for_qc

########################################
# 1) Shovill per sample
########################################
for sample in "${samples[@]}"; do
    echo
    echo "############################################"
    echo "Running Shovill for sample: $sample"
    echo "############################################"
    echo "[##--------] 20%  (Running Shovill for $sample)"

    R1="data/${sample}_1_trimmed.fastq.gz"
    R2="data/${sample}_2_trimmed.fastq.gz"

    # Create separate result directory for each sample
    mkdir -p "results/${sample}"

    /usr/bin/time -l -o "results/${sample}/benchmarking_shovill.log" \
      shovill --outdir "results/${sample}/shovill_out" \
              --R1 "$R1" \
              --R2 "$R2" \
      > "results/${sample}/shovill_output.log" 2>&1

    echo "[####------] 40%  (Shovill complete for $sample)"

    # Copy/rename contigs for common QC folder
    # Adjust extension here if needed (contigs.fasta vs contigs.fa)
    if [ -f "results/${sample}/shovill_out/contigs.fa" ]; then
        cp "results/${sample}/shovill_out/contigs.fa" "results/assemblies_for_qc/${sample}.fasta"
    else
        echo "WARNING: No contigs file found for ${sample} (expected contigs.fasta or contigs.fa)"
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
# 3) BUSCO on all samples (batch mode)
########################################
echo
echo "############################################"
echo "Running BUSCO (batch) on all assemblies"
echo "############################################"
echo "[########--] 80%  (Running BUSCO on all samples)"

# Change this lineage to what fits your organisms best, e.g.:
#  - bacteria_odb10
#  - gammaproteobacteria_odb10
BUSCO_LINEAGE="bacteria_odb10"

mkdir -p results/busco_batch

/usr/bin/time -l -o benchmarking_busco.log \
  busco \
    -i results/assemblies_for_qc \
    -o busco_batch \
    -l "$BUSCO_LINEAGE" \
    -m genome \
    --out_path results/busco_batch \
  > busco_output.log 2>&1

echo "[##########] 90%  (BUSCO complete for all samples)"

########################################
# 4) CheckM on all samples
########################################
echo
echo "############################################"
echo "Running CheckM on all assemblies"
echo "############################################"
echo "[##########] 95%  (Running CheckM on all samples)"

mkdir -p results/checkm_out

/usr/bin/time -l -o benchmarking_checkm.log \
  checkm lineage_wf \
    -x fasta \
    results/assemblies_for_qc \
    results/checkm_out \
  > checkm_output.log 2>&1

echo "[##########] 97%  (CheckM complete for all samples)"

########################################
# 5) Prokka per sample
########################################
for sample in "${samples[@]}"; do
    echo
    echo "############################################"
    echo "Running Prokka for sample: $sample"
    echo "############################################"
    echo "[#########-] 98%  (Running Prokka for $sample)"

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
# 6) Final combined benchmarking log
########################################
echo
echo "======================================"
echo "   Benchmarking summary (all steps)"
echo "======================================"

# Per-sample Shovill + Prokka
for sample in "${samples[@]}"; do
  if [ -f "results/${sample}/benchmarking_shovill.log" ]; then
    {
      echo "======================================"
      echo "Benchmarking summary for $sample"
      echo "======================================"
      echo "--- Shovill ---"
      cat "results/${sample}/benchmarking_shovill.log"
      echo
      if [ -f "results/${sample}/benchmarking_prokka.log" ]; then
        echo "--- Prokka ---"
        cat "results/${sample}/benchmarking_prokka.log"
        echo
      fi
      echo
    } >> benchmarking_all_steps.log
  fi
done

# Multi-sample tools: QUAST, BUSCO, CheckM
{
  echo "======================================"
  echo "Benchmarking summary for QUAST (all samples)"
  echo "======================================"
  cat benchmarking_quast_multi.log
  echo
  echo "======================================"
  echo "Benchmarking summary for BUSCO (all samples)"
  echo "======================================"
  cat benchmarking_busco.log
  echo
  echo "======================================"
  echo "Benchmarking summary for CheckM (all samples)"
  echo "======================================"
  cat benchmarking_checkm.log
  echo
} >> benchmarking_all_steps.log

# Show combined log on screen
cat benchmarking_all_steps.log

echo
echo "==============================================================================================="
echo " All samples processed!"
echo " Combined benchmarking summary -> benchmarking_all_steps.log"
echo " Multi-sample QUAST report     -> results/quast_multi/"
echo " BUSCO batch output            -> results/busco_batch/"
echo " CheckM output                 -> results/checkm_out/"
echo " Per-sample results            -> results/<sample>/"
echo " Assemblies for QC             -> results/assemblies_for_qc/"
echo "==============================================================================================="
