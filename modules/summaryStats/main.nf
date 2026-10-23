process calculateSummaryStats {
    tag "$sample"
    label 'process_single'

    container 'community.wave.seqera.io/library/picard_shiver:c2e2da40c7f510d6'

    input: 
    tuple val(sample), path(raw_r1), path(dedup_stats)

    output:
    tuple val(sample), path("${sample}_read_counts.txt"), emit: read_counts

    when:
    task.ext.when == null || task.ext.when

    script:
    // template 'editFASTQheader.sh'
    def rawReadCountCommand = raw_r1.name.endsWith('.gz')
        ? "gzip -cd '${raw_r1}' | awk 'END {print NR/4}'"
        : "awk 'END {print NR/4}' '${raw_r1}'"
    """
    set -euo pipefail

    n_raw_reads=\$(${rawReadCountCommand})
    echo raw read pairs > ${sample}_raw_read_count.txt
    echo \${n_raw_reads} >> ${sample}_raw_read_count.txt
    n_mapped_reads=\$(grep -A2 "METRICS CLASS" ${dedup_stats} | tail -n1 | cut -f3 -d\$'\t')
    echo mapped read pairs > ${sample}_mapped_read_count.txt
    echo \${n_mapped_reads} >> ${sample}_mapped_read_count.txt
    n_dups=\$(grep -A2 "METRICS CLASS" ${dedup_stats} | tail -n1 | cut -f7 -d\$'\t')
    n_unique_reads=\$((\$n_mapped_reads - \$n_dups))
    echo unique read pairs > ${sample}_unique_read_count.txt
    echo \${n_unique_reads} >> ${sample}_unique_read_count.txt


    paste ${sample}_raw_read_count.txt ${sample}_mapped_read_count.txt ${sample}_unique_read_count.txt > ${sample}_read_counts.txt

    """
}