include { runSpadesAssembly }                                               from './modules/deNovo/Spades.nf'
include { runMegahitAssembly }                                              from './modules/deNovo/Megahit.nf'
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

    if (params.assembler == 'megahit') {
        runDeNovoAssembly = runMegahitAssembly(preprocessed_sample_ch)
    } else if (params.assembler == 'spades') {
        runDeNovoAssembly = runSpadesAssembly(preprocessed_sample_ch)
    } else {
        log.error "Invalid assembly tool specified: ${params.assembler}. Please choose either 'megahit' or 'spades'."
        System.exit(1)
    }

    runShiverContigsAlign(
        runDeNovoAssembly.contigs, 
        buildShiverConfig.out.shiver_init_dir
        )

    raw_sample_ch = channel.fromPath(params.samplesheet)
                       .splitCsv(header: true)
                       .map { row ->
                           def r1 = file("${params.data_dir}/${row.sample}/${row.sample}_raw_R1.fastq")
                           def r2 = file("${params.data_dir}/${row.sample}/${row.sample}_raw_R2.fastq")
                           tuple(row.sample, r1, r2)
                       }

    if (!params.stop_after_contig_alignment) {
        editFASTQheaders(raw_sample_ch)

        reads_and_contigs = editFASTQheaders.out.amended_reads
                            .join(runDeNovoAssembly.contigs)
                            .join(runShiverContigsAlign.shiver_contig_alignment)
                            // .view()

        runShiverReadsAlign(
            reads_and_contigs, 
            buildShiverConfig.out.shiver_init_dir
            )
    }else{
        log.info "Stopping after contig alignments - check results/shiver/contig_alignments"
    }


    publish:
    contigs                 = runDeNovoAssembly.contigs
    shiver_contig_alignment = runShiverContigsAlign.shiver_contig_alignment
    shiver_final_output     = params.stop_after_contig_alignment 
                                ? channel.empty() 
                                : runShiverReadsAlign.out.shiver_reads_alignment

}

output {
    contigs {
        mode 'copy'
        path { sample -> "./contigs/${sample[0]}" }
    }
    shiver_contig_alignment {
        mode 'copy'
        path { sample -> "./shiver/contig_alignments/${sample[0]}" }
    }
    shiver_final_output {
        mode 'copy'
        path { sample -> "./shiver/final_output/${sample[0]}" }
    }
}