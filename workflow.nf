include { sayHello }                                                        from './modules.nf'
include { runDeNovoAssembly }                                               from './modules/deNovo/deNovo.nf'
include { buildShiverConfig; runShiverContigsAlign; runShiverReadsAlign  }  from './modules/shiver/shiver.nf'
include { editFASTQheaders }                                                from './modules/editFASTQ/editFASTQ.nf'

workflow {

    main:

    buildShiverConfig(
        file(params.shiver_config),
        file(params.ref_alignment),
        file(params.adapters)
        ) 

    preprocessed_sample_ch = channel.fromPath(params.samplesheet)
                       .splitCsv(header: true)
                       .map { row ->
                           def r1 = file("${params.data_dir}/${row.sample}/${row.sample}_R1.fastq")
                           def r2 = file("${params.data_dir}/${row.sample}/${row.sample}_R2.fastq")
                           tuple(row.sample, r1, r2)
                       }
                       // .view()

    runDeNovoAssembly(preprocessed_sample_ch)

    runShiverContigsAlign(
        runDeNovoAssembly.out.contigs, 
        buildShiverConfig.out.shiver_init_dir
        )

    raw_sample_ch = channel.fromPath(params.samplesheet)
                       .splitCsv(header: true)
                       .map { row ->
                           def r1 = file("${params.data_dir}/${row.sample}/${row.sample}_raw_R1.fastq")
                           def r2 = file("${params.data_dir}/${row.sample}/${row.sample}_raw_R2.fastq")
                           tuple(row.sample, r1, r2)
                       }

    if (params.stop_after_contig_alignment) {
        log.info "Stopping after contig alignments - check results/shiver/contig_alignments"
        return
    }

    editFASTQheaders(raw_sample_ch)

    reads_and_contigs = editFASTQheaders.out.amended_reads
                        .join(runDeNovoAssembly.out.contigs)
                        .join(runShiverContigsAlign.out.shiver_contig_alignment)
                        // .view()

    runShiverReadsAlign(
        reads_and_contigs, 
        buildShiverConfig.out.shiver_init_dir
        )


    publish:
    contigs = runDeNovoAssembly.out.contigs
    shiver_contig_alignment = runShiverContigsAlign.out.shiver_contig_alignment
    shiver_final_output = runShiverReadsAlign.out.shiver_reads_alignment

}

output {
    contigs {
        path { sample -> "./contigs/${sample[0]}" }
    }
    shiver_contig_alignment {
        path { sample -> "./shiver/contig_alignments/${sample[0]}" }
    }
    shiver_final_output {
        path { sample -> "./shiver/final_output/${sample[0]}" }
    }
}