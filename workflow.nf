include { sayHello } from './modules.nf'
include { runDeNovoAssembly } from './deNovo.nf'

params {
    ref_alignment: Path = 'RefAlignment.fasta'
    samplesheet: Path = './test/test.csv'
}

workflow {

    main:
    // print list of samples from sample sheet
    sample_ch = channel.fromPath(params.samplesheet)
                       .splitCsv()
                       .map{ row -> row[0] }
                       .view()

    runDeNovoAssembly(sample_ch)
}

