# Change directory to the folder with the seq_data
#brew install brewsci/bio/shovill
#conda install -c bioconda quast
# conda install -c conda-forge -c bioconda -c defaults prokka


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
/usr/bin/time -l -o benchmarking.log \
	quast shovill_out/contigs.fasta -o quast_out \
	> quast_output.log 2>&1

# Step 4: annotate genes
prokka --outdir prokka_out --prefix sample shovill_out/contigs.fasta
