######
# title: "WGS Pipeline metrics"
# author: "Meghna Swayambhu"
# date: "27/11/2025"
######

#clear the env
rm(list=ls())

library(tidyverse)
require(rstudioapi)

# --- absolute path to the 'results' folder on the SERVER as seen from your Mac ---
results_root <- "/Volumes/sgr_rk/2_Sequencing_Projects/2_001_Sequences_Natural_Pseudomonas_Isolates/Pseudomonas_seq_pipeline/Test/results"  

# 2) QUAST
quast_path <- file.path(results_root, "quast_multi", "report.tsv")
quast <- read_tsv(quast_path, show_col_types = FALSE)
head(quast)
quast_long <- quast %>%
  # keep only the metrics we care about
  filter(Assembly %in% c("# contigs (>= 0 bp)", "N50")) %>%
  # go from columns = samples to rows = samples
  pivot_longer(
    cols = -Assembly,
    names_to = "sample",
    values_to = "value"
  ) %>%
  # map QUAST's metric names to nice column names
  mutate(
    metric = dplyr::recode(
      Assembly,
      "# contigs (>= 0 bp)" = "contigs",
      "N50"                 = "n50"
    )
  ) %>%
  select(sample, metric, value) %>%
  # finally: one row per sample with columns contigs, n50
  pivot_wider(
    names_from = metric,
    values_from = value
  )

quast_summary <- quast_long

# 3) Prokka (gene counts)
# assume each sample is a subfolder of results_root: results_root/<sample>/prokka_out/<sample>.tsv

sample_dirs <- list.dirs(results_root, full.names = TRUE, recursive = FALSE)
ignore <- c("assemblies_for_qc", "fastqc_multiqc", "quast_multi")
sample_dirs <- sample_dirs[!basename(sample_dirs) %in% ignore]

prokka_summary <- purrr::map_dfr(sample_dirs, function(d) {
  s <- basename(d)
  prokka_dir <- file.path(d, "prokka_out")
  if (!dir.exists(prokka_dir)) return(NULL)
  
  tsv_files <- list.files(prokka_dir, pattern = "\\.tsv$", full.names = TRUE)
  if (length(tsv_files) == 0) return(NULL)
  
  ann <- readr::read_tsv(tsv_files[1], show_col_types = FALSE)
  tibble::tibble(sample = s, gene_count = nrow(ann))
})

# 4) Combine and write CSV *locally*
combined <- quast_summary %>%
  left_join(prokka_summary, by = "sample") %>%
  arrange(sample)

write_csv(combined, "combined_metrics.csv")

