process editFASTQheaders {
    input: 
    tuple val(sample), path(r1), path(r2)

    output:
    tuple val(sample), path("${sample}_R1_amended.fastq"), path("${sample}_R2_amended.fastq"), emit: amended_reads

    script:
    template 'editFASTQheader.sh'
}