include { sayHello }                                                        from './modules.nf'
include { runDeNovoAssembly }                                               from './deNovo.nf'
include { buildShiverConfig; runShiverContigsAlign; runShiverReadsAlign  }  from './shiver.nf'

workflow {

    main:
    // print list of samples from sample sheet
    sample_ch = channel.fromPath(params.samplesheet)
                       .splitCsv(header: true)
                       .map { row ->
                           def r1 = file("${params.data_dir}/${row.sample}/${row.sample}_R1.fastq")
                           def r2 = file("${params.data_dir}/${row.sample}/${row.sample}_R2.fastq")
                           tuple(row.sample, r1, r2)
                       }
                       .view()

    runDeNovoAssembly(sample_ch)

    runShiverContigsAlign(runDeNovoAssembly.out.contigs, file(params.shiver_init_dir))

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