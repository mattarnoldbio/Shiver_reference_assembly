process buildSampleDirs {
    input: 
    path ''
    
    script:
    """
    """
    
    output: 
    path ''
}

process report{
    input: 
    path ''

    script:
    """
    """

    output:
    path ''
}

process runDeNovoAssembly{
    input: 
    path ''

    script:
    """
    """

    output:
    path ''
}


process buildShiverConfig{
    input: 
    path ''

    script:
    """
    """

    output:
    path ''
}

process runShiverRefAlign{
    input: 
    path ''

    script:
    """
    """

    output:
    path ''
}

process checkpoint{
    input: 
    path ''

    script:
    """
    """

    output:
    path ''
}

process preprocessReads{
    input: 
    path ''

    script:
    """
    """

    output:
    path ''
}

process runShiverReadsAlign{
    input: 
    path ''

    script:
    """
    """

    output:
    path ''
}

process sayHello {

    output:
    path 'output.txt'

    script:
    """
    echo 'Hello World!' > output.txt
    """
}