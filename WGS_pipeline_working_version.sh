# Cluster:
# Data: running the scripts and storing intermediate files
# RK server: storing data actually (long term)

# Change directory to the folder with the seq_data

# Step 1: quality check of raw reads
fastqc data/*.fastq.gz -o results/

# Step 2: trim and filter low-quality bases - DONE by MicrobesNG
fastp -i data/sample_R1.fastq.gz -I data/sample_R2.fastq.gz \
      -o results/sample_R1.trim.fastq.gz -O results/sample_R2.trim.fastq.gz \
      -h results/sample_fastp.html -j results/sample_fastp.json

# Step 3: assemble genome
spades.py -1 results/sample_R1.trim.fastq.gz -2 results/sample_R2.trim.fastq.gz \
          -o results/spades_out -t 8

# Step 4: check assembly quality
quast results/spades_out/contigs.fasta -o results/quast_out

# Step 5: annotate genes
prokka --outdir results/prokka_out --prefix sample results/spades_out/contigs.fasta

#QUAST → assembly metrics

#CheckM → completeness & contamination

#BUSCO → ortholog completeness

#Kraken2/Bracken → taxonomic contamination

#BlobTools → visualize contaminant contigs

#Pilon (optional) → polishing