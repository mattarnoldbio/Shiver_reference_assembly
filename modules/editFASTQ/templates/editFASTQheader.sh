set -euo pipefail

case "${r1}" in
    *.gz) gzip -cd "${r1}" | sed 's| 1:.*|/1|' > "${sample}_R1_amended.fastq" ;;
    *) sed 's| 1:.*|/1|' "${r1}" > "${sample}_R1_amended.fastq" ;;
esac

case "${r2}" in
    *.gz) gzip -cd "${r2}" | sed 's| 2:.*|/2|' > "${sample}_R2_amended.fastq" ;;
    *) sed 's| 2:.*|/2|' "${r2}" > "${sample}_R2_amended.fastq" ;;
esac