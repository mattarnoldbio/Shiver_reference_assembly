process buildShiverConfig{
    //conda 'bioconda::shiver'
    container   "community.wave.seqera.io/library/shiver:1.7.3--467ff1f7b70c9248"
    label 'process_low'

    container 'ghcr.io/mattarnoldbio/shiver:1.7.0-mt.1@sha256:a0cf5d9d17d286815a798f868a1c43e54ac1572a3fe2c3e1fb9fab5052fb853f'

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
    container 'ghcr.io/mattarnoldbio/shiver:1.7.0-mt.1@sha256:a0cf5d9d17d286815a798f868a1c43e54ac1572a3fe2c3e1fb9fab5052fb853f'

    errorStrategy {
        if (task.exitStatus == 3) {
            log.warn "Shiver contig alignment failed for sample $sample, continuing with next sample. \n Check results/shiver/contig_alignments for details. \n This sample will be excluded from downstream analysis."
            return 'ignore'
        }
        if (task.exitStatus in 137..140) {
            return task.attempt <= 2 ? 'retry' : 'error'
        }
        return 'error'
    }

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
    container 'ghcr.io/mattarnoldbio/shiver:1.7.0-mt.1@sha256:a0cf5d9d17d286815a798f868a1c43e54ac1572a3fe2c3e1fb9fab5052fb853f'

    input: 
    tuple val(sample), path(r1), path(r2), path(contigs), path(raw_wRefs), path(cut_wRefs),  path(blast)
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