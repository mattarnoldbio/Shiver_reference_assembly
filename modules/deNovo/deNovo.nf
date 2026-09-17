// oras://community.wave.seqera.io/library/megahit:1.2.9--8488ea3ad736bcd8

process runDeNovoAssembly{
    container   'community.wave.seqera.io/library/megahit_pigz:87a590163e594224'  // 'oras://community.wave.seqera.io/library/megahit:1.2.9--8488ea3ad736bcd8'

    input: 
    tuple val(sample), path(r1), path(r2)

    output:
    tuple val(sample), path("${sample}_contigs.fa"), emit: contigs

    script:
    """
    megahit \\
        -1 ${r1} \\
        -2 ${r2} \\
        -m 0.1 \\
        -t 8 \\
        -o ${sample}_assembly \\
        --out-prefix ${sample} \\
        --min-contig-len 150

    mv ${sample}_assembly/${sample}.contigs.fa ${sample}_contigs.fa
    """

}