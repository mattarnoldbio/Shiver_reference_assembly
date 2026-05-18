// oras://community.wave.seqera.io/library/megahit:1.2.9--8488ea3ad736bcd8

process runDeNovoAssembly{
    container    'oras://community.wave.seqera.io/library/megahit:1.2.9--8488ea3ad736bcd8'

    input: 
    val sample

    output:
    path '${sample}_contigs.fa'

    script:
    """
    echo '${sample}'
    """

}