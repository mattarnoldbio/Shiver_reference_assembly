process buildShiverConfig{
    //conda 'bioconda::shiver'
    container   "community.wave.seqera.io/library/shiver:1.7.3--467ff1f7b70c9248"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ? 
    'oras://community.wave.seqera.io/library/shiver:1.7.3--de2515f22b38f4d1' :
    'community.wave.seqera.io/library/shiver:1.7.3--467ff1f7b70c9248' }"

    input: 
    path shiver_config 
    path ref_alignment
    path adapters

    output:
    path "shiver_init" , emit: shiver_init_dir

    script:
    """
    touch dummy_primers.fa
    
    shiver_init.sh \\
        shiver_init \\
        ${shiver_config} \\
        ${ref_alignment} \\
        ${adapters} \\
        dummy_primers.fa 
    
    cp ${shiver_config} shiver_init/shiver_config.sh
    """
}

process runShiverContigsAlign{
    tag "$sample"
    label 'process_low'

    //conda 'bioconda::shiver'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ? 
    'oras://community.wave.seqera.io/library/shiver:1.7.3--de2515f22b38f4d1' :
    'community.wave.seqera.io/library/shiver:1.7.3--467ff1f7b70c9248' }"

    errorStrategy 'ignore'

    input: 
    tuple val(sample), path(contigs)
    path shiver_init_dir 

    output:
    tuple val(sample), path("${sample}_raw_wRefs.fasta"), path("${sample}_cut_wRefs.fasta"), path("${sample}.blast"), emit: shiver_contig_alignment

    script:
    """
    shiver_align_contigs.sh \\
        ${shiver_init_dir}\\
        ${shiver_init_dir}/shiver_config.sh \\
        '${contigs}' \\
        '${sample}'
    """

}

process runShiverReadsAlign{
    tag "$sample"
    label 'process_low'

    //conda 'bioconda::shiver'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ? 
    'oras://community.wave.seqera.io/library/shiver:1.7.3--de2515f22b38f4d1' :
    'community.wave.seqera.io/library/shiver:1.7.3--467ff1f7b70c9248' }"


    input: 
    tuple val(sample), path(r1), path(r2), path(contigs), path(cut_wRefs), path(raw_wRefs), path(blast)
    path shiver_init_dir

    output:
    tuple val(sample), path("${sample}*"), emit: shiver_reads_alignment

    //TODO:     - Remove explicit reference to config.sh
    //          - Autogenerate config.sh with reproducible name/location 
    //          - Allow selection of raw vs cut
    //          - separate blast output from contigs

    script:
    def refs = params.use_raw_refs ? raw_wRefs : cut_wRefs
    """
    shiver_map_reads.sh \\
        ${shiver_init_dir} \\
        ${shiver_init_dir}/shiver_config.sh \\
        ${contigs} \\
        ${sample} \\
        ${blast} \\
        ${refs} \\
        ${r1} \\
        ${r2}
    """
}