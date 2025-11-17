#!/bin/bash
#
# Whole Exome Sequencing (WES) pipeline: FastQC → Trim Galore → BWA-MEM →
# MarkDuplicates → BQSR → HaplotypeCaller → (optional) CombineGVCFs
#
# Original pipeline: Mukesh Kumar, PhD (CSIR-IGIB, Binukumar lab)
# Cleaned and formatted by: Treesa K Issen
#

#SBATCH -N 1
#SBATCH -n 40
#SBATCH -c 1
#SBATCH -p compute
#SBATCH -J ALN_GATK_BWA
#SBATCH --output=BWA_ALN_%j_out.log
#SBATCH --error=BWA_ALN_%j_err.log


set -euo pipefail

### ------------------------------------------------------------------------
### 1. Define paths
### ------------------------------------------------------------------------

# Input FASTQ directory and main output directory
input_dir="/home/binukumar/storage300tb/run_analysis/run08072024/fastq_files"   # FASTQ files
result="/home/binukumar/storage300tb/run_analysis/run08072024"

# Create output directories
mkdir -p \
  "$result/pretrim_fastqc" \
  "$result/TrimGalore" \
  "$result/post_trim" \
  "$result/bwa" \
  "$result/vcf"

pretrim_fastqc="$result/pretrim_fastqc"
trim_dir="$result/TrimGalore"
post_trim="$result/post_trim"
bwa_dir="$result/bwa"
vcf_dir="$result/vcf"

# Reference and known-sites files
reference_genome="/lustre/binukumar/tools/ref_files/Dragen_hg38/hg38_dragen.fa"
dbsnp_vcf="/lustre/binukumar/tools/ref_files/Dragen_hg38/hsa_hg38.dbsnp138.vcf"
indel_1kgp="/lustre/binukumar/tools/ref_files/Dragen_hg38/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz"

# (Optional) tools
trimmomatic="/lustre/binukumar/tools/trimmomatic-0.39.jar"
# picard="/lustre/binukumar/tools/picard.jar"

threads="-t 40"

### ------------------------------------------------------------------------
### 2. Build list of samples based on *_R2.fastq.gz
### ------------------------------------------------------------------------

extension="_R2.fastq.gz"
samples=()

for file in "$input_dir"/*_R2.fastq.gz; do
    filename=$(basename "$file")
    sample_name="${filename%"$extension"}"   # remove suffix
    samples+=("$sample_name")
done

num_samples=${#samples[@]}
echo "Samples to be processed (${num_samples} samples):"
for sample in "${samples[@]}"; do
    echo " - $sample"
done

### ------------------------------------------------------------------------
### 3. FastQC before trimming
### ------------------------------------------------------------------------

echo "Running pre-trim FastQC..."
for fq in "$input_dir"/*.fastq.gz; do
    fastqc --outdir "$pretrim_fastqc" $threads "$fq"
done

multiqc -o "$pretrim_fastqc" "$pretrim_fastqc"

### ------------------------------------------------------------------------
### 4. Trim Galore
### ------------------------------------------------------------------------

echo "Running Trim Galore..."
trim_galore_options="--paired --quality 30 --phred33 --length 36 --stringency 2"

for input_r1_file in "$input_dir"/*_R1.fastq.gz; do
    input_r2_file="${input_r1_file/_R1.fastq.gz/_R2.fastq.gz}"

    if [[ -e "$input_r2_file" ]]; then
        sample_name=$(basename "$input_r1_file" "_R1.fastq.gz")
        echo "  Trimming sample: $sample_name"

        trim_galore $trim_galore_options \
            -o "$trim_dir" \
            "$input_r1_file" "$input_r2_file"
    else
        echo "  WARNING: No matching R2 for $input_r1_file, skipping."
    fi
done

### ------------------------------------------------------------------------
### 5. FastQC after trimming
### ------------------------------------------------------------------------

echo "Running post-trim FastQC..."
for fq in "$trim_dir"/*.fq.gz; do
    fastqc --outdir "$post_trim" $threads "$fq"
done

multiqc -o "$post_trim" "$post_trim"

### ------------------------------------------------------------------------
### 6. Alignment with BWA-MEM
### ------------------------------------------------------------------------

echo "Preparing trimmed sample list for BWA..."
trim_extension="_R2_val_2.fq.gz"
samples=()

for file in "$trim_dir"/*"$trim_extension"; do
    filename=$(basename "$file")
    sample_name="${filename%"$trim_extension"}"
    samples+=("$sample_name")
done

if [[ ! -d "$trim_dir" ]]; then
    echo "ERROR: Input directory does not exist: $trim_dir"
    exit 1
fi

if [[ ! -d "$bwa_dir" ]]; then
    echo "ERROR: Output directory does not exist: $bwa_dir"
    exit 1
fi

echo "Running BWA-MEM alignment..."
for sample_name in "${samples[@]}"; do
    forward_read="${sample_name}_R1_val_1.fq.gz"
    reverse_read="${sample_name}_R2_val_2.fq.gz"

    if [[ ! -e "$trim_dir/$forward_read" || ! -e "$trim_dir/$reverse_read" ]]; then
        echo "  WARNING: Read files missing for $sample_name, skipping."
        continue
    fi

    read_group="@RG\tID:${sample_name}\tSM:${sample_name}\tPL:medgenome"

    bwa mem -t 40 -R "$read_group" "$reference_genome" \
        "$trim_dir/$forward_read" "$trim_dir/$reverse_read" \
        | samtools view -bhSS - > "$bwa_dir/${sample_name}_aligned.bam"
done

### ------------------------------------------------------------------------
### 7. Sort BAM files
### ------------------------------------------------------------------------

echo "Sorting BAM files..."
for sample_name in "${samples[@]}"; do
    input_aligned_bam="$bwa_dir/${sample_name}_aligned.bam"
    output_sorted_bam="$bwa_dir/${sample_name}_sorted.bam"

    echo "  Sorting: $input_aligned_bam"
    samtools sort -@ 20 "$input_aligned_bam" > "$output_sorted_bam"
done

### ------------------------------------------------------------------------
### 8. Mark duplicates
### ------------------------------------------------------------------------

echo "Marking duplicates..."
for sample_name in "${samples[@]}"; do
    input_sorted_bam="$bwa_dir/${sample_name}_sorted.bam"
    output_sorted_MD_bam="$bwa_dir/${sample_name}_sorted_MD.bam"
    picard_info="$bwa_dir/${sample_name}_picard.info"

    picard MarkDuplicates \
        -I "$input_sorted_bam" \
        -O "$output_sorted_MD_bam" \
        -M "$picard_info" \
        --REMOVE_DUPLICATES true \
        -AS true
done

### ------------------------------------------------------------------------
### 9. Base recalibration (BQSR)
### ------------------------------------------------------------------------

echo "Running BaseRecalibrator and ApplyBQSR..."
mkdir -p "$bwa_dir/base_recalib"
base_recalib="$bwa_dir/base_recalib"

# Generate recalibration tables
for sample_name in "${samples[@]}"; do
    input_sorted_MD_bam="$bwa_dir/${sample_name}_sorted_MD.bam"
    recal_table="$base_recalib/${sample_name}_recalibration.table"

    gatk --java-options "-Xmx54g" BaseRecalibrator \
        -R "$reference_genome" \
        -I "$input_sorted_MD_bam" \
        --known-sites "$dbsnp_vcf" \
        --known-sites "$indel_1kgp" \
        -O "$recal_table"
done

# Optional: GatherBQSRReports (for combined report)
input_tables=()
for sample_name in "${samples[@]}"; do
    input_tables+=("-I" "$base_recalib/${sample_name}_recalibration.table")
done

output_recalibration="$base_recalib/all_recalibration.table"
gatk GatherBQSRReports "${input_tables[@]}" -O "$output_recalibration"

# Apply BQSR per sample
for sample_name in "${samples[@]}"; do
    input_bam="$bwa_dir/${sample_name}_sorted_MD.bam"
    output_bam="$bwa_dir/${sample_name}_sorted_MD_recalib.bam"

    gatk --java-options "-Xmx54g" ApplyBQSR \
        -R "$reference_genome" \
        -I "$input_bam" \
        --bqsr-recal-file "$base_recalib/${sample_name}_recalibration.table" \
        -O "$output_bam"
done

### ------------------------------------------------------------------------
### 10. Index recalibrated BAMs
### ------------------------------------------------------------------------

echo "Indexing BAM files..."
for sample_name in "${samples[@]}"; do
    input_bam="$bwa_dir/${sample_name}_sorted_MD_recalib.bam"
    samtools index -@ 16 -b "$input_bam"
done

### ------------------------------------------------------------------------
### 11. Variant calling (HaplotypeCaller)
### ------------------------------------------------------------------------

echo "Running HaplotypeCaller..."
for sample_name in "${samples[@]}"; do
    input_bam="$bwa_dir/${sample_name}_sorted_MD_recalib.bam"
    output_vcf="$vcf_dir/${sample_name}.vcf.gz"

    gatk --java-options "-Xmx54g" HaplotypeCaller \
        -R "$reference_genome" \
        -I "$input_bam" \
        -O "$output_vcf" \
        --dragen-mode true
done

### ------------------------------------------------------------------------
### 12. (Optional) CombineGVCFs – if running HaplotypeCaller in GVCF mode
### ------------------------------------------------------------------------

# Uncomment and modify if you switch HaplotypeCaller to -ERC GVCF mode.
# echo "Combining GVCFs..."
# input_gvcf=()
# for sample_name in "${samples[@]}"; do
#     input_gvcf+=("-V" "$vcf_dir/${sample_name}.g.vcf")
# done
#
# gatk --java-options "-Xmx54g" CombineGVCFs \
#     -R "$reference_genome" \
#     "${input_gvcf[@]}" \
#     -O "$vcf_dir/dystonia_cohort.g.vcf"

echo "Pipeline completed successfully."
