// oras://community.wave.seqera.io/library/megahit:1.2.9--8488ea3ad736bcd8

process runSpadesAssembly{
    tag "$sample"
    label 'process_high'

    container   'community.wave.seqera.io/library/spades:4.3.0--fefe8aa442d71a4d'

    input: 
    tuple val(sample), path(r1), path(r2)

    output:
    tuple val(sample), path("${sample}_contigs.fa"), emit: contigs
    
    
    //TODO: set ext.args in config file to allow user to specify additional SPAdes parameters
    
    script:
    """
    spades.py \\
        -1 ${r1} \\
        -2 ${r2} \\
        ${task.ext.args} \\
        -o ${sample}_assembly 

    mv ${sample}_assembly/scaffolds.fasta ${sample}_contigs.fa
    """

}