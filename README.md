# 🧬 Rare Disease Exome Analysis

Whole Exome Sequencing (WES)-based variant interpretation and ACMG classification of rare disease cohorts analyzed at **CSIR-IGIB, New Delhi**.

---

## 📌 Cohorts Analyzed

- Wilson’s Disease  
- Autism Spectrum Disorder (ASD)  
- Early Epileptic Encephalopathy (EEP)  
- Duchenne Muscular Dystrophy (DMD)

---

## 🔧 Tools & Technologies Used

| Step | Tool |
|------|------|
| Read Alignment | **BWA-MEM** |
| BAM Processing | **Samtools** |
| Mark Duplicates | **Picard** |
| Variant Calling & BQSR | **GATK** |
| Adapter Trimming | **TrimGalore** |
| FASTQ QC | **FastQC** |
| Multi-sample QC | **MultiQC** |

Tested on SLURM HPC environment.

---

## ⚙ Software Requirements

- BWA ≥ 0.7.17  
- Samtools ≥ 1.14  
- GATK ≥ 4.2  
- Picard ≥ 2.23  
- FastQC ≥ 0.11.9  
- TrimGalore ≥ 0.6.10  
- MultiQC ≥ 1.14  

---

## 📁 Repository Structure

```
rare-disease-exome/
│
├── README.md
│
├── wes_single_sample_pipeline.sh
├── wes_multi_sample_pipeline.sh
│
└── scripts/        (future helper scripts)
```

---

## 🚀 How to Run

### 1️⃣ Single Sample WES
Script:
```
wes_single_sample_pipeline.sh
```

Example:
```bash
sbatch wes_single_sample_pipeline.sh \
 --input sample_R1.fastq.gz \
 --input sample_R2.fastq.gz \
 --sample SAMPLE_ID
```

---

### 2️⃣ Multi-sample WES
Script:
```
multi_sample_wes_pipeline.sh
```

Example:
```bash
sbatch wes_multi_sample_pipeline.sh \
 --samples samples.txt \
 --reference hg38.fa
```

---

## 📥 Input Format

Paired FASTQ files, named:

```
sample_R1.fastq.gz
sample_R2.fastq.gz
```

---

## 📤 Output Files

- Sorted BAM  
- Duplicate-marked BAM  
- Recalibrated BAM  
- GVCF / VCF  
- FastQC + MultiQC reports

---

## 🧬 Pipeline Workflow

1. FASTQ QC — FastQC  
2. Adapter trimming — TrimGalore  
3. Alignment — BWA-MEM  
4. Sorting & Indexing — Samtools  
5. Mark Duplicates — Picard  
6. Base Quality Recalibration — GATK  
7. Variant Calling (HaplotypeCaller) — GATK  
8. QC Summary — MultiQC  

---

## 📝 Notes

- Follows GATK Best Practices  
- Uses SLURM job submission  
- Optimized for hg38  
- ACMG variant classification applied afterward  

