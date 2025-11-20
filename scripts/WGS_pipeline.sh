# Change directory to the folder with the seq_data

# Step 1: quality check of raw reads
fastqc data/*.fastq.gz -o results/
multiqc .

# Step 2: assemble genome
/usr/bin/time -l -o benchmarking.log \
  shovill --outdir shovill_out \
          --R1 data/233090_3A06_1_trimmed.fastq.gz \
          --R2 data/233090_3A06_2_trimmed.fastq.gz \
  > shovill_output.log 2>&1

# Step 3: check assembly quality
quast results/spades_out/contigs.fasta -o results/quast_out

# Step 4: annotate genes
prokka --outdir results/prokka_out --prefix sample results/spades_out/contigs.fasta
