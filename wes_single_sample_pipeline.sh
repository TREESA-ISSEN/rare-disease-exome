# Whole Exome Sequencing Pipeline (BWA + GATK)
# Original script: Mukesh Kumar, PhD, CSIR-IGIB
# Maintained by: Treesa K Issen
# Description: Automated workflow for WES analysis including
# FastQC, Trim Galore, BWA alignment, Picard duplicate removal,
# GATK BaseRecalibrator, and HaplotypeCaller.

#!/bin/bash

#SBATCH -N 1
#SBATCH -n 40
#SBATCH -c 1
#SBATCH -p compute
#SBATCH -J ALN_GATK_BWA
#SBATCH --output=BWA_ALN_%j_out.log
#SBATCH --error=BWA_ALN_%j_err.log


# --- Configuration ---

sample_name="SAMPLE123"  # <-- Change to your actual sample name

input_dir="/home/binukumar/storage300tb/run_analysis/run08072024/fastq_files"
result="/home/binukumar/storage300tb/run_analysis/run08072024"
reference_genome="/lustre/binukumar/tools/ref_files/Dragen_hg38/hg38_dragen.fa"
dbsnp_vcf="/lustre/binukumar/tools/ref_files/Dragen_hg38/hsa_hg38.dbsnp138.vcf"
indel_1kgp="/lustre/binukumar/tools/ref_files/Dragen_hg38/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz"

# Output directories
pretrim_fastqc="$result/pretrim_fastqc"
trimmed="$result/TrimGalore"
post_trim="$result/post_trim"
bwa_out="$result/bwa"
vcf_out="$result/vcf"
recalib_out="$bwa_out/base_recalib"

mkdir -p "$pretrim_fastqc" "$trimmed" "$post_trim" "$bwa_out" "$vcf_out" "$recalib_out"

# Input FASTQ files
r1="$input_dir/${sample_name}_R1.fastq.gz"
r2="$input_dir/${sample_name}_R2.fastq.gz"

# --- Pipeline ---

## Step 1: FastQC before trimming
fastqc -t 40 -o "$pretrim_fastqc" "$r1" "$r2"

## Step 2: Trim Galore
trim_galore --paired --quality 30 --phred33 --length 36 --stringency 2 -o "$trimmed" "$r1" "$r2"

## Step 3: FastQC after trimming
r1_trimmed="${trimmed}/${sample_name}_R1_val_1.fq.gz"
r2_trimmed="${trimmed}/${sample_name}_R2_val_2.fq.gz"
fastqc -t 40 -o "$post_trim" "$r1_trimmed" "$r2_trimmed"
multiqc -o "$post_trim" "$post_trim"

## Step 4: Alignment using BWA
read_group="@RG\tID:$sample_name\tSM:$sample_name\tPL:medgenome"
aligned_bam="$bwa_out/${sample_name}_aligned.bam"
bwa mem -t 40 -R "$read_group" "$reference_genome" "$r1_trimmed" "$r2_trimmed" | samtools view -bhS - > "$aligned_bam"

## Step 5: Sort BAM
sorted_bam="$bwa_out/${sample_name}_sorted.bam"
samtools sort -@ 20 "$aligned_bam" > "$sorted_bam"

## Step 6: Mark duplicates
dedup_bam="$bwa_out/${sample_name}_sorted_MD.bam"
metrics_file="$bwa_out/${sample_name}_picard.info"
picard MarkDuplicates -I "$sorted_bam" -O "$dedup_bam" -M "$metrics_file" --REMOVE_DUPLICATES true -AS true

## Step 7: Base Recalibration
recal_table="$recalib_out/${sample_name}_recal.table"
gatk --java-options "-Xmx54g" BaseRecalibrator -R "$reference_genome" -I "$dedup_bam" --known-sites "$dbsnp_vcf" --known-sites "$indel_1kgp" -O "$recal_table"

## Step 8: Apply BQSR
recalib_bam="$bwa_out/${sample_name}_sorted_MD_recalib.bam"
gatk --java-options "-Xmx54g" ApplyBQSR -R "$reference_genome" -I "$dedup_bam" --bqsr-recal-file "$recal_table" -O "$recalib_bam"

## Step 9: Index BAM
samtools index -@ 16 -b "$recalib_bam"

## Step 10: Variant Calling
gatk --java-options "-Xmx54g" HaplotypeCaller -R "$reference_genome" -I "$recalib_bam" -O "$vcf_out/${sample_name}.vcf.gz" --dragen-mode true
