# Bioinformatics pipelines for *A.cervicornis*

To do: add scripts from [Michael's Tag-based_RNAseq pipeline](https://github.com/mstudiva/tag-based_RNAseq/blob/master/tagSeq_processing_README.txt)  that he ran in his HPC.

## Results

Code to create these graphs is from [this R file](https://github.com/ademerlis/temperaturevariability2023/blob/main/gene_expression/MS_bioinformatics/Acer_Rmd/Acer_deseq2.R). 

`dds = DESeqDataSetFromMatrix(countData=countData, colData=design, design=~ group + Genotype)`

countData pre-filtered to remove low-count genes:

```{r}
# how many genes we have total?
nrow(counts) #57358
ncol(counts) #48 samples

# filtering out low-count genes
keep <- rowSums(counts) >= 10
countData <- counts[keep,]
nrow(countData) #47882
ncol(countData) #48
```

the "group" variable for the design contains both "Treatment" (control vs. variable) and "time_point" (Day_0 vs. Day_29).

```{r}
design$Genotype <- as.factor(design$Genotype)
design$Treatment <- as.factor(design$Treatment)
design %>% 
  mutate(time_point = case_when(Experiment.phase == "Pre-treatment" ~ "Day_0",
                                Experiment.phase == "last day of treatment" ~ "Day_29")) -> design
column_to_rownames(design, var="Sample_ID") -> design
design$group <- factor(paste0(design$Treatment, "_", design$time_point))
# reorders fate factor according to "control" vs "treatment" levels
dds$group <- factor(dds$group, levels = c("control_Day_0","control_Day_29","variable_Day_0","variable_Day_29"))
```

First, the package arrayQualityMetrics was used to identify outliers. It generates a report called "index.html", where you can visualize which samples exceed a certain threshold. Then, those are removed from downstream analyses.

```{r}
library(Biobase)
e=ExpressionSet(assay(Vsd), AnnotatedDataFrame(as.data.frame(colData(Vsd))))

# running outlier detection
arrayQualityMetrics(e,intgroup=c("group"),force=T)
```

Genotype is not included in the intgroup for outliers because it is not the main factor of interest (see [this example](https://github.com/mstudiva/SCTLD-intervention-transcriptomics/blob/main/code/transmission/deseq2_transmission_mcav_host.R)). 

<img width="649" alt="Screen Shot 2023-08-24 at 10 41 55 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/bba2faff-6237-4f13-b4ab-c411f8a11f5f">

So because of this, three outliers are removed.

```{r}
outs=c(20,22,28) #these numbers were taken from the index.html report from arrayQualityMetrics Figure 2 "Outlier detection"
countData=countData[,-outs]
Vsd=Vsd[,-outs]
counts4wgcna=counts4wgcna[,-outs]
design=design[-outs,]
```

Then dds model is remade without those outliers. 
```{r}
# remaking model with outliers removed from dataset
dds = DESeqDataSetFromMatrix(countData=countData, colData=design, design=~ group + Genotype)
dds$group <- factor(dds$group, levels = c("control_Day_0","control_Day_29","variable_Day_0","variable_Day_29"))
```

### 1) Heatmap
To see similarity of samples

<img width="692" alt="Screen Shot 2023-08-24 at 10 45 03 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/11a824df-3d22-4704-a79a-95affcb2b657">

### 2) PCoA
How many good PCs are there? Look for the number of black points above the line of red crosses (random model). 

<img width="667" alt="Screen Shot 2023-08-24 at 10 46 52 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/184913c8-3b42-42d3-a090-f6d857f8138c">

Now plot the PCoA by treatment and time point.

<img width="701" alt="Screen Shot 2023-08-24 at 10 47 46 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/b2a85929-dcc6-4f1d-852f-8518a511ab2a">

Neighbor-joining tree of samples (based on significant PCoA's).

<img width="636" alt="Screen Shot 2023-08-24 at 10 48 34 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/a9d877ab-7bc1-4515-8ef5-2b60d0dca33f">

### 3) PERMANOVA for variance in distance matrices

```{r}
ad=adonis2(t(vsd)~time_point*Treatment + Genotype,data=conditions,method="manhattan",permutations=1e6)
ad
summary(ad)
```
<img width="735" alt="Screen Shot 2023-08-24 at 10 51 22 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/c665756c-7148-4cf0-9d4b-22d8bae042f9">

Pie chart to show proportion of R2 values per factor driving variance

<img width="423" alt="Screen Shot 2023-08-24 at 10 52 07 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/637c63d6-590c-42f2-8b70-b66cacf82618">

### 4) DESeq2

```{r}
# Running full model for contrast statements
dds=DESeq(dds, parallel=TRUE)
# treatment
treatment_time=results(dds) 
summary(treatment_time) 
degs_treatment_time=row.names(treatment_time)[treatment_time$padj<0.1 & !(is.na(treatment_time$padj))]
resultsNames(dds)
```

<img width="348" alt="Screen Shot 2023-08-24 at 10 55 33 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/e90ca043-d909-4b34-905b-2d7af2d8e141">

<img width="565" alt="Screen Shot 2023-08-24 at 10 56 15 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/41649c31-9fec-4aea-83d6-804a22bb7a7e">

Specific contrasts:

<img width="604" alt="Screen Shot 2023-08-24 at 10 56 43 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/7724d025-2ef0-46d3-aa50-846624cff017">

<img width="567" alt="Screen Shot 2023-08-24 at 10 56 59 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/82877abf-8087-4386-aad5-8d0235f03618">

<img width="608" alt="Screen Shot 2023-08-24 at 10 57 15 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/3907df8b-38f3-4399-9d20-c6833099e85d">

<img width="592" alt="Screen Shot 2023-08-24 at 10 57 30 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/a79caefe-0f16-4e58-9b67-a4b1b1039e8e">

### 5) Density plot for DEGs

<img width="462" alt="Screen Shot 2023-08-24 at 10 58 13 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/664f279e-f805-479c-8998-62c8774bd7f8">

### 6) Venn diagram for DEGs

<img width="573" alt="Screen Shot 2023-08-24 at 10 58 58 AM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/50f945b9-0b34-4601-afe3-c7adac07bb01">

### 7) PCA

<img width="625" alt="Screen Shot 2023-08-24 at 2 39 15 PM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/7d7729dc-09a2-4271-a42d-f3576d63de99">

<img width="628" alt="Screen Shot 2023-08-24 at 2 39 44 PM" src="https://github.com/ademerlis/temperaturevariability2023/assets/56000927/9f8b6e55-a573-4252-9c6d-84ddddc1710f">





