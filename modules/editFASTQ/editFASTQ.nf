process editFASTQheaders {
    tag "$sample"
    label 'process_single'

    container 'community.wave.seqera.io/library/picard_shiver:c2e2da40c7f510d6'

    input: 
    tuple val(sample), path(r1), path(r2)

    output:
    tuple val(sample), path("${sample}_R1_amended.fastq"), path("${sample}_R2_amended.fastq"), emit: amended_reads

    script:
    template 'editFASTQheader.sh'
}