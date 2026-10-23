include { runSpadesAssembly }                                               from './modules/deNovo/Spades.nf'
include { runMegahitAssembly }                                              from './modules/deNovo/Megahit.nf'
include { countLongContigs }                                                from './modules/countLongContigs/main.nf'
include { buildShiverConfig; runShiverContigsAlign; runShiverReadsAlign  }  from './modules/shiver/shiver.nf'
include { editFASTQheaders }                                                from './modules/editFASTQ/editFASTQ.nf'
include { BCFTOOLS_MPILEUP }                                                from './modules/nf-core/bcftools/mpileup/main.nf'
include { BCFTOOLS_QUERY }                                                  from './modules/nf-core/bcftools/query/main.nf'
include { calculateSummaryStats }                                           from './modules/summaryStats/main.nf'

workflow {

    main:

    def resolveReadFile = { sample, readSet, mate ->
        def basename = "${sample}${readSet}_${mate}.fastq"
        def pattern = "${params.data_dir}/${sample}/${basename}*"
        def matches = file(pattern, glob: true, checkIfExists: false)
        if (!(matches instanceof List)) {
            matches = [matches]
        }
        matches = matches.findAll { candidate ->
            candidate.toFile().isFile() && (candidate.name == basename || candidate.name == "${basename}.gz")
        }

        if (matches.size() != 1) {
            throw new IllegalStateException(
                "Expected exactly one of ${basename} or ${basename}.gz for sample ${sample}; found ${matches.size()}"
            )
        }

        matches[0]
    }

    buildShiverConfig(
        file(params.shiver_config),
        file(params.ref_alignment),
        file(params.adapters)
        ) 

    preprocessed_sample_ch = channel.fromPath(params.samplesheet)
                       .splitCsv(header: true)
                       .map { row ->
                           def r1 = resolveReadFile(row.sample, '', 'R1')
                           def r2 = resolveReadFile(row.sample, '', 'R2')
                           tuple(row.sample, r1, r2)
                       }
                       // .view()

    if (params.assembler == 'megahit') {
        runDeNovoAssembly = runMegahitAssembly(preprocessed_sample_ch)
    } else if (params.assembler == 'spades') {
        runDeNovoAssembly = runSpadesAssembly(preprocessed_sample_ch)
    } else {
        log.error "Invalid assembly tool specified: ${params.assembler}. Please choose either 'megahit' or 'spades'."
        System.exit(1)
    }

    countLongContigs(
        runDeNovoAssembly.contigs,
        params.min_contig_length,
        params.assembler
        )

    runShiverContigsAlign(
        runDeNovoAssembly.contigs, 
        buildShiverConfig.out.shiver_init_dir
        )

    raw_sample_ch = channel.fromPath(params.samplesheet)
                       .splitCsv(header: true)
                       .map { row ->
                           def r1 = resolveReadFile(row.sample, '_raw', 'R1')
                           def r2 = resolveReadFile(row.sample, '_raw', 'R2')
                           tuple(row.sample, r1, r2)
                       }

    if (!params.stop_after_contig_alignment) {
        editFASTQheaders(raw_sample_ch)

        ch_reads_and_contigs = editFASTQheaders.out.amended_reads
                            .join(runDeNovoAssembly.contigs)
                            .join(runShiverContigsAlign.out.shiver_contig_alignment)
                            // .view()

        runShiverReadsAlign(
            ch_reads_and_contigs,
            buildShiverConfig.out.shiver_init_dir,
            file("${projectDir}/modules/shiver/picard_add_rg_mark_duplicates.sh")
            )
    }else{
        log.info "Stopping after contig alignments - check results/shiver/contig_alignments"
    }

    ch_consensus = runShiverReadsAlign.out.consensus_fastas.map { sample, files ->
        def prefix = "${sample}_consensus_MinCov_"
        def matches = files.findAll { consensusFile ->
            consensusFile.name.startsWith(prefix) && consensusFile.name.endsWith(".fasta") && !consensusFile.name.endsWith("_ForGlobalAln.fasta")
        }
        if (matches.size() != 1) {
            throw new IllegalStateException("Expected one consensus FASTA for ${sample}, found ${matches.size()}")
        }
        tuple(sample, matches[0])
    }

    ch_consensus_global_alignment = runShiverReadsAlign.out.consensus_fastas.map { sample, files ->
        def prefix = "${sample}_consensus_MinCov_"
        def matches = files.findAll { consensusFile ->
            consensusFile.name.startsWith(prefix) && consensusFile.name.endsWith("_ForGlobalAln.fasta")
        }
        if (matches.size() != 1) {
            throw new IllegalStateException("Expected one global-alignment consensus FASTA for ${sample}, found ${matches.size()}")
        }
        tuple(sample, matches[0])
    }

    ch_remap_consensus = runShiverReadsAlign.out.remap_consensus_fastas.map { sample, files ->
        def prefix = "${sample}_remap_consensus_MinCov_"
        def matches = files.findAll { consensusFile ->
            consensusFile.name.startsWith(prefix) && consensusFile.name.endsWith(".fasta")
        }
        if (matches.size() != 1) {
            throw new IllegalStateException("Expected one remap consensus FASTA for ${sample}, found ${matches.size()}")
        }
        tuple(sample, matches[0])
    }

    ch_variant_calling_bam = runShiverReadsAlign.out.remap_bam.map { sample, bamFile ->
        def interval_mpileup = []
        def intervals_call = []
        tuple(sample, bamFile, interval_mpileup, intervals_call)
        }

    ch_variant_calling_ref = runShiverReadsAlign.out.remap_reference
                                .join(runShiverReadsAlign.out.remap_reference_index)

    ch_variant_calling = ch_variant_calling_bam
                            .join(ch_variant_calling_ref)
                            .multiMap{ sample, bamFile, interval_mpileup, intervals_call, refFile, refIndex ->
                                def meta = [id: sample]
                                bam: tuple(meta, bamFile, interval_mpileup, intervals_call)
                                ref: tuple(meta, refFile, refIndex)
                            }

    BCFTOOLS_MPILEUP(ch_variant_calling.bam, ch_variant_calling.ref, true)

    ch_called_variants = BCFTOOLS_MPILEUP.out.vcf
                        .map { meta, vcfFile ->
                            def indexFile = []
                            tuple(meta, vcfFile, indexFile)
                        }

    BCFTOOLS_QUERY(ch_called_variants, [], [], [] )

    ch_summary_stats = raw_sample_ch
                    .join(runShiverReadsAlign.out.deduplication_metrics)
                    .map { sample, r1, _r2, dedupMetrics ->
                        tuple(sample, r1, dedupMetrics)
                    }

    calculateSummaryStats(ch_summary_stats)


    publish:
    contigs                 = runDeNovoAssembly.contigs
    long_contig_counts      = countLongContigs.out.long_contig_counts
    shiver_contig_alignment = runShiverContigsAlign.out.shiver_contig_alignment
    shiver_bam = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.bam
    shiver_bam_index = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.bam_index
    shiver_bam_pre_dedup = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.bam_pre_dedup
    shiver_reference = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.reference
    shiver_reference_index = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.reference_index
    shiver_consensus = params.stop_after_contig_alignment ? channel.empty() : ch_consensus
    shiver_consensus_global_alignment = params.stop_after_contig_alignment ? channel.empty() : ch_consensus_global_alignment
    shiver_base_frequencies = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.base_frequencies
    shiver_base_frequencies_global_alignment = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.base_frequencies_global_alignment
    shiver_base_frequencies_hxb2 = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.base_frequencies_hxb2
    shiver_coordinates = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.coordinates
    shiver_insert_size_counts = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.insert_size_counts
    shiver_deduplication_metrics = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.deduplication_metrics
    shiver_remap_bam = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.remap_bam
    shiver_remap_bam_index = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.remap_bam_index
    shiver_remap_bam_pre_dedup = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.remap_bam_pre_dedup
    shiver_remap_reference = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.remap_reference
    shiver_remap_reference_index = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.remap_reference_index
    shiver_remap_consensus = params.stop_after_contig_alignment ? channel.empty() : ch_remap_consensus
    shiver_remap_base_frequencies = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.remap_base_frequencies
    shiver_remap_base_frequencies_hxb2 = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.remap_base_frequencies_hxb2
    shiver_remap_insert_size_counts = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.remap_insert_size_counts
    shiver_remap_deduplication_metrics = params.stop_after_contig_alignment ? channel.empty() : runShiverReadsAlign.out.remap_deduplication_metrics
    vcf = params.stop_after_contig_alignment ? channel.empty() : BCFTOOLS_MPILEUP.out.vcf
    index = params.stop_after_contig_alignment ? channel.empty() : BCFTOOLS_MPILEUP.out.index
    stats = params.stop_after_contig_alignment ? channel.empty() : BCFTOOLS_MPILEUP.out.stats
    called_variants = params.stop_after_contig_alignment ? channel.empty() : BCFTOOLS_QUERY.out.output
    read_counts = params.stop_after_contig_alignment ? channel.empty() : calculateSummaryStats.out.read_counts

}

output {
    contigs {
        mode 'copy'
        path { sample -> "./contigs/${sample[0]}" }
    }
    long_contig_counts {
        mode 'copy'
        path { sample -> "./contigs/${sample[0]}" }
    }
    shiver_contig_alignment {
        mode 'copy'
        path { sample -> "./shiver/contig_alignments/${sample[0]}" }
    }
    shiver_bam {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_bam_index {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_bam_pre_dedup {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_reference {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_reference_index {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_consensus {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_consensus_global_alignment {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_base_frequencies {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_base_frequencies_global_alignment {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_base_frequencies_hxb2 {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_coordinates {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_insert_size_counts {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_deduplication_metrics {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_remap_bam {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_remap_bam_index {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_remap_bam_pre_dedup {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_remap_reference {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_remap_reference_index {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_remap_consensus {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_remap_base_frequencies {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_remap_base_frequencies_hxb2 {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_remap_insert_size_counts {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    shiver_remap_deduplication_metrics {
        mode 'copy'
        path { item -> "./shiver/final_output/${item[0]}" }
    }
    vcf {
        mode 'copy'
        path { item -> "./variant_calling/${item[0].id}" }
    }
    index {
        mode 'copy'
        path { item -> "./variant_calling/${item[0].id}" }
    }
    stats {
        mode 'copy'
        path { item -> "./variant_calling/${item[0].id}" }
    }

    called_variants {
        mode 'copy'
        path { item -> "./variant_calling/${item[0].id}" }
    }

    read_counts {
        mode 'copy'
        path { item -> "./read_counts/${item[0]}" }
    }
}