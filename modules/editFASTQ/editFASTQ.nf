process editFASTQheaders {
    tag "$sample"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'oras://community.wave.seqera.io/library/coreutils:9.12--34be2b55ff8e6687' :
    'community.wave.seqera.io/library/coreutils:9.12--83081953909e2904' }"

    input: 
    tuple val(sample), path(r1), path(r2)

    output:
    tuple val(sample), path("${sample}_R1_amended.fastq"), path("${sample}_R2_amended.fastq"), emit: amended_reads

    script:
    template 'editFASTQheader.sh'
}