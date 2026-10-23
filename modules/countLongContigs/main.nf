process countLongContigs {
    tag "$sample"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'oras://community.wave.seqera.io/library/coreutils:9.12--34be2b55ff8e6687' :
    'community.wave.seqera.io/library/coreutils:9.12--83081953909e2904' }"

    input: 
    tuple val(sample), path(contigs)
    val min_length
    val assembler

    output:
    tuple val(sample), path("${sample}_long_contig_counts.txt"), emit: long_contig_counts

    when:
    task.ext.when == null || task.ext.when

    script:
    // template 'editFASTQheader.sh'
    """
    if [ "${assembler}" == "spades" ]; then
        grep ">" ${contigs} | cut -d"_" -f4 |sort -n | awk -v n="$min_length" '\$1 > n' | wc -l > ${sample}_long_contig_counts.txt
    elif [ "${assembler}" == "megahit" ]; then
        grep ">" ${contigs} | cut -d"=" -f3 |sort -n | awk -v n="$min_length" '\$1 > n' | wc -l > ${sample}_long_contig_counts.txt
    else
        echo "Unknown assembler: ${assembler}"
        exit 1
    fi

    """
}