process buildShiverConfig{
    input: 
    path ''

    script:
    """
    """

    output:
    path ''
}

process runShiverContigsAlign{
    conda 'bioconda::shiver'
    //container   "docker://community.wave.seqera.io/library/shiver:1.7.3--cd324db821908ee2"

    input: 
    tuple val(sample), path(contigs)
    path shiver_init_dir //, stageAs: 'shiver_init_dir', type: 'dir'

    output:
    tuple val(sample), path("${sample}_raw_wRefs.fasta"), path("${sample}_cut_wRefs.fasta"), path("${sample}.blast"), emit: shiver_contig_alignment

    script:
    """
    shiver_align_contigs.sh \\
        ${shiver_init_dir}\\
        ${shiver_init_dir}/PRRSV_shiver_config.sh \\
        '${contigs}' \\
        '${sample}'
    """

}

process runShiverReadsAlign{
    input: 
    path ''

    script:
    """
    """

    output:
    path ''
}