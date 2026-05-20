# Shiver reference assembly

## Motivation
Shiver is a program which uses hybrid reference sequences to perform reference assembly. These hybrid references are constructed from *de novo* assembled contigs which are aligned with a reference alignment; any gaps in the contig alignment are filled with sequence from the most closely related reference sequence in the alignment. The reads are then aligned to the resulting reference sequence. This approach is useful for getting good assemblies for genomes where there is a lot of diversity and even the closest reference can be too divergent to get good alignments (hence the *de novo*). It was designed for use with HIV (described in [this paper](https://doi.org/10.1093/ve/vey007) and implemented by the authors on [this Github](https://github.com/ChrisHIV/shiver)). It also seems to work well for porcine reproductive and respiratory syndrome virus (PRRSV), which is why this nextflow implementation exists. Here we've removed some of the manual steps, and bundled in the *de novo* assembly. This makes things more user friendly and easier to tack onto Your Favourite Bioformatics Pipeline. However, this comes at a cost: **there may be parameters that are set automatically that you should change for your dataset** as the defaults were chosen for our data -- see below for more details.

## Getting started
No prior installation is required for Nextflow workflows. However, you should have working Nextflow and Singularity installed. The easiest way to do this is by creating a conda environment (i.e. `conda create -n nextflow bioconda:nextflow conda-forge:singularity`) and then using this to run the pipeline (by activating it each time you want to run: `conda activate nextflow`).
It is probably easiest to clone the repo (`git clone mattarnoldbio/Shiver_reference_assembly`) and then run locally (`cd Shiver_reference_assembly; nextflow run workflow.nf`) so you can edit config files etc.

## Usage

### Inputs:
Each of these inputs ***must*** be specified which can be done from the commmandline or in `nextflow.config`, using the argument names in brackets.

- Data directory (`data_dir`):
  - Directory containing the sequencing data to be processed. This should contain one subdirectory per sample, containing paired-end read files named as follows. For sample `x`, raw reads (i.e. straight off the sequencer) should be named `x_raw_R1.fastq` and `x_raw_R1.fastq`; preprocessed reads (assuming you have done some kind of QC, adapter trimming etc - we use [Mark Stenglein's nextflow pipeline](https://github.com/stenglein-lab/read_preprocessing) for this) named `x_R1.fastq` and `x_R2.fastq`. Shiver might work fine with these preprocessed reads, but this requires verification.
  - Tip: if you find your reads are not named this way, the [`rename`](https://man7.org/linux/man-pages/man1/rename.1.html) command may prove useful.
- Sample sheet (`samplesheet`):
  - CSV file with one column called `sample` and containing the sample names. These should be the same as the name of the subdirectories in `data_dir` and the filestring that is the root of read files (see above).
- Adapter sequences used for sequencing (`adapters`):
  - See [`/examples/Twist_adapters.fa`](https://github.com/mattarnoldbio/Shiver_reference_assembly/blob/main/examples/Twist_adapters.fa) for example formatting.
- Reference alignment to use for aligning contigs and raw reads to (`ref_alignment`)
  - See [`examples/PRRSV_ref_genomes.fasta`](https://github.com/mattarnoldbio/Shiver_reference_assembly/blob/main/examples/PRRSV_ref_genomes.fasta) for an example.
  - This alignment should prioritise alignment quality and capturing the total diversity in the background data. Consult the [Shiver docs](https://github.com/ChrisHIV/shiver/blob/master/docs/ShiverManual.pdf) for more detail.
- Exhaustive paramters for Shiver (with explanations) are found in the `shiver_config.sh` file. You should look through this briefly before running to check these are actually set to values that make sense for your data. If you want to create a different version, save it with a different name to avoid it being overwritten if you update your local compy of the pipeline, and edit the `shiver_config` argument in `nextflow.config`.

### Running:
After filling out the `nextflow.config` as described, we recommend running the first half of the pipeline using `nextflow run workflow.nf --stop_after_contig_alignment true` and then checking the alignments to see if the trimmed or raw alignment is better (for more detail on this, see the final section of the [Shiver docs](https://github.com/ChrisHIV/shiver/blob/master/docs/ShiverManual.pdf)).

Once this is done, and you have decided which aligment to use downstream, you can run the second half of the pipeline. 
- If you decide to use the trimmed alignment (default behaviour - for us this usually looks better): `nextflow run workflow.nf -resume`. If you know you want to do this before you start, you can just run the pipeline start to finish skipping this whole palaver.
- If you decide the raw alignment looks better: `nextflow run workflow.nf -resume --use_raw_refs true`

### Updating:
Use `git pull` to update your local copy of the repository.