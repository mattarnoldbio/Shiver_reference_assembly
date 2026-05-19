include { sayHello }                                                        from './modules.nf'
include { runDeNovoAssembly }                                               from './modules/deNovo/deNovo.nf'
include { buildShiverConfig; runShiverContigsAlign; runShiverReadsAlign  }  from './modules/shiver/shiver.nf'
include { editFASTQheaders }                                                from './modules/editFASTQ/editFASTQ.nf'

workflow {

    main:
    sample_ch = channel.fromPath(params.samplesheet)
                       .splitCsv(header: true)
                       .map { row ->
                           def r1 = file("${params.data_dir}/${row.sample}/${row.sample}_R1.fastq")
                           def r2 = file("${params.data_dir}/${row.sample}/${row.sample}_R2.fastq")
                           tuple(row.sample, r1, r2)
                       }
                       .view()

    runDeNovoAssembly(sample_ch)

    // TODO: check the most "nextflow" way of managing the inputs. I think it should maybe just be a continuation of the sample_ch?
    runShiverContigsAlign(runDeNovoAssembly.out.contigs, file(params.shiver_init_dir))

    editFASTQheaders(sample_ch)

    sample_ch.view()

    publish:
    contigs = runDeNovoAssembly.out.contigs
    shiver_contig_alignment = runShiverContigsAlign.out.shiver_contig_alignment

}

output {
    contigs {
        path './contigs'
    }
    shiver_contig_alignment {
        path './shiver'
    }
}