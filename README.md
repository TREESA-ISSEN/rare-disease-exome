🧬 Rare Disease Exome Analysis

This private repository contains workflows, scripts, and notes for Whole Exome Sequencing (WES)–based variant interpretation and ACMG classification of rare disease cohorts analyzed at CSIR–IGIB, New Delhi.

🧪 Cohorts analyzed

Wilson’s Disease

Autism Spectrum Disorder (ASD)

Early Epileptic Encephalopathy (EEP)

Duchenne Muscular Dystrophy (DMD)


🔧 Tools & Technologies Used

BWA-MEM – read alignment

GATK – HaplotypeCaller, BaseRecalibrator, ApplyBQSR

Samtools – BAM processing

Picard – duplicate marking

TrimGalore – adapter trimming

FastQC + MultiQC – QC reporting

Runs on Slurm HPC environment

📁 Repository Structure

rare-disease-exome/
│
├── README.md
├── wes_single_sample_pipeline.sh
├── wes_multi_sample_pipeline.sh
│
└── scripts/
    └── (future helper scripts)

🚀 How to Run

# Single sample WES
sbatch wes_single_sample_pipeline.sh

# Multi-sample WES
sbatch wes_multi_sample_pipeline.sh

🧬 Software Requirements

- BWA ≥ 0.7.17
- Samtools ≥ 1.14
- GATK ≥ 4.2
- Picard ≥ 2.23
- TrimGalore ≥ 0.6.10
- FastQC ≥ 0.11.9
- MultiQC ≥ 1.14

📥 Input Format

FASTQ files should follow:
sample_R1.fastq.gz
sample_R2.fastq.gz

Placed in input folder.

📤 Output Files

- Sorted BAM
- Duplicate-marked BAM
- Recalibrated BAM
- VCF or GVCF
- QC reports (FastQC / MultiQC)


