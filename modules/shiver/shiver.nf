process buildShiverConfig{
    //conda 'bioconda::shiver'
    container   "community.wave.seqera.io/library/shiver:1.7.3--467ff1f7b70c9248"
    label 'process_low'

    // container 'ghcr.io/mattarnoldbio/shiver:1.7.0-mt.1@sha256:a0cf5d9d17d286815a798f868a1c43e54ac1572a3fe2c3e1fb9fab5052fb853f'  // MINE
    // container   "community.wave.seqera.io/library/shiver:1.7.3--467ff1f7b70c9248"                                                // SEQERA - shiver only
    container  "community.wave.seqera.io/library/picard_shiver:c2e2da40c7f510d6"                                                    // SEQERA - shiver + picard

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
    // container 'ghcr.io/mattarnoldbio/shiver:1.7.0-mt.1@sha256:a0cf5d9d17d286815a798f868a1c43e54ac1572a3fe2c3e1fb9fab5052fb853f'  // MINE
    // container   "community.wave.seqera.io/library/shiver:1.7.3--467ff1f7b70c9248"                                                // SEQERA - shiver only
    container  "community.wave.seqera.io/library/picard_shiver:c2e2da40c7f510d6"                                                    // SEQERA - shiver + picard

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

    // container 'ghcr.io/mattarnoldbio/shiver:1.7.0-mt.1@sha256:a0cf5d9d17d286815a798f868a1c43e54ac1572a3fe2c3e1fb9fab5052fb853f'  // MINE
    // container   "community.wave.seqera.io/library/shiver:1.7.3--467ff1f7b70c9248"                                                // SEQERA - shiver only
    container  "community.wave.seqera.io/library/picard_shiver:c2e2da40c7f510d6"                                                    // SEQERA - shiver + picard

    input: 
    tuple val(sample), path(r1), path(r2), path(contigs), path(raw_wRefs), path(cut_wRefs),  path(blast)
    path shiver_init_dir
    path dedup_wrapper

    output:
    tuple val(sample), path("${sample}.bam"), emit: bam
    tuple val(sample), path("${sample}.bam.bai"), emit: bam_index
    tuple val(sample), path("${sample}_PreDedup.bam"), emit: bam_pre_dedup
    tuple val(sample), path("${sample}_ref.fasta"), emit: reference
    tuple val(sample), path("${sample}_ref.fasta.fai"), emit: reference_index
    tuple val(sample), path("${sample}_consensus_MinCov_*_*.fasta"), emit: consensus_fastas
    tuple val(sample), path("${sample}_BaseFreqs.csv"), emit: base_frequencies
    tuple val(sample), path("${sample}_BaseFreqs_ForGlobalAln.csv"), emit: base_frequencies_global_alignment
    tuple val(sample), path("${sample}_BaseFreqs_WithHXB2.csv"), emit: base_frequencies_hxb2
    tuple val(sample), path("${sample}_coords.csv"), emit: coordinates
    tuple val(sample), path("${sample}_InsertSizeCounts.csv"), emit: insert_size_counts
    tuple val(sample), path("${sample}_DedupStats.txt"), emit: deduplication_metrics
    tuple val(sample), path("${sample}_remap.bam"), emit: remap_bam
    tuple val(sample), path("${sample}_remap.bam.bai"), emit: remap_bam_index
    tuple val(sample), path("${sample}_remap_PreDedup.bam"), emit: remap_bam_pre_dedup
    tuple val(sample), path("${sample}_remap_ref.fasta"), emit: remap_reference
    tuple val(sample), path("${sample}_remap_ref.fasta.fai"), emit: remap_reference_index
    tuple val(sample), path("${sample}_remap_consensus_MinCov_*_*.fasta"), emit: remap_consensus_fastas
    tuple val(sample), path("${sample}_remap_BaseFreqs.csv"), emit: remap_base_frequencies
    tuple val(sample), path("${sample}_remap_BaseFreqs_WithHXB2.csv"), emit: remap_base_frequencies_hxb2
    tuple val(sample), path("${sample}_remap_InsertSizeCounts.csv"), emit: remap_insert_size_counts
    tuple val(sample), path("${sample}_remap_DedupStats.txt"), emit: remap_deduplication_metrics

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