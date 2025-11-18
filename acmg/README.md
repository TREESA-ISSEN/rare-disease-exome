# ACMG Variant Classification Rules

This folder documents my implementation of the ACMG/AMP guidelines (Richards et al. 2015) for variant interpretation in rare disease whole-exome sequencing (WES) workflows. It includes population frequency filters, in-silico prediction logic, rule guidance, and a Python automation script for an online ACMG classifier.



## Population Allele Frequency Rules (1000G, ESP6500, ExAC, gnomAD)

✔ BA1: AF > 0.05  
✔ BS1: AF between 0.01 and 0.05  
✔ BS2: AF > 0.01 (in-house database)  
✔ PM2: AF 0 or < 0.0005  

---

## Computational (SIFT, PolyPhen, CADD)

✔ PP3: 2/3 tools predict pathogenic  
✔ BP4: 2/3 tools predict benign  

ClinVar & Pfam:
✔ PP5: Pathogenic in ClinVar  
✔ BP6: Benign in ClinVar  
✔ PM1: Variant in Pfam functional domain  

---

## Literature & Functional Studies

Functional Studies:  
✔ PS3: Pathogenic effect  
✔ BS3: No effect  

Case-Control Studies:  
✔ PS4: Odds ratio > 5  
✔ BP5: Present in healthy controls  

Segregation Data:  
✔ PP1: Segregation observed  
✔ BS4: No segregation  
✔ PS2: De Novo confirmed  
✔ PM6: De Novo assumed  
✔ PP4: Segregation in large pedigree  

---

## Variant-Type Based ACMG Rules

✔ PVS1: Nonsense, frameshift, splice site, LOF mechanism  
✔ BP7: Synonymous variant  

Nonsynonymous variants:  
✔ PP2: Missense pathogenic in >50% ClinVar  
✔ BP1: Nonsense benign in >50% ClinVar  

Novel variants:  
✔ PS1: Same amino acid + position  
✔ PM5: Same position, different amino acid  

Compound heterozygous:  
✔ PM3: Trans  
✔ BP2: Cis  

Indels in repeats:  
✔ PM4: Not in repeat  
✔ BP3: In repeat  

---

## Google Sheets Calculation Formulas

Convert "." to zero:
=IF(ISNUMBER(A2), A2, VALUE(SUBSTITUTE(A2,".",0)))

PM2 (All DB < 0.0005):
=IF(AND(T2 < 0.0005, U2 < 0.0005, V2 < 0.0005), "PM2", "")  OR =IF(AND(ARRAYFORMULA(T2:V2 < 0.0005)), "PM2", "")

BA1 > 0.05:
=IF(MAX(T2:V2) >= 0.05, "BA1", "")

BS1 between 0.01–0.05:
=IF(AND(MAX(V2:X2) <= 0.05, OR(V2 >= 0.01, W2 >= 0.01, X2 >= 0.01)), "BS1", "")

PP3: ≥2/3 tools pathogenic:
=ARRAYFORMULA(IF((COUNTIFS(X2,"D") + IF(Y2="P",1,0) + IF(Y2="D",1,0) + COUNTIFS(Z2,">=15"))>=2,"PP3",""))

BP4: ≥2/3 tools benign:
=ARRAYFORMULA(IF((COUNTIFS(X2,"T") + COUNTIFS(Y2,"B") + COUNTIFS(Z2,"<15"))>=2,"BP4",""))

---

## ACMG Evaluation Flow

Population Frequency → Computational Tools → Functional & Clinical Evidence → Segregation → Variant Type Rules
  

## Notes

✔ Use UCSC RepeatMasker for PM4 / BP3  
✔ ClinVar frequency filters needed for PP2 / BP1  
✔ De Novo must match phenotype for PS2 / PM6  
✔ LOF must be known mechanism for PVS1  

---

## Intended Use

This ACMG rulebook supports:

- Rare disease WES interpretation
- Google Sheets–based ACMG scoring
- Clinical variant interpretation workflows

---

## 🧰 Automatic ACMG Classification via UMD Tool

I created a script that automates the use of the "Genetic Variant Interpretation Tool", developed by the University of Maryland School of Medicine:

🔗 https://www.medschool.umaryland.edu/genetic_variant_interpretation_tool1.html/

This site:

- Lets you check ACMG evidence boxes for a variant,
- Automatically applies ACMG logic,
- Shows final classification,
- Allows downloading a report table of multiple variants.

> ⚠️ Disclaimer: This tool is unofficial and not endorsed by ACMG/AMP. Use for documentation and research assistance.

---

### 🐍 Automation Script — `acmg_web_tool_automation.py`

```bash
pip install selenium
```

Place a file called `attributes.txt` in the same folder:

Example `attributes.txt`:

```
PVS1,PM2,PP3
PM2,PP3,BP4
BA1
PP3,PP2,PM1
```

Run the script:

```bash
python acmg_web_tool_automation.py
```

Features:

- Opens Chrome
- Selects ACMG buttons for each attribute
- Reads the assigned classification
- Clicks "Add Variant"
- Downloads final results as CSV to:

```
./output_folder/
```

---

## Reference

Richards et al., 2015 — ACMG-AMP Standards  
