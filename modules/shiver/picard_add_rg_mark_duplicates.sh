#!/usr/bin/env bash

set -euo pipefail

input_bam=''
output_bam=''
metrics_file=''
remove_duplicates=''

for arg in "$@"; do
    case "$arg" in
        I=*) input_bam=${arg#I=} ;;
        O=*) output_bam=${arg#O=} ;;
        M=*) metrics_file=${arg#M=} ;;
        REMOVE_DUPLICATES=*) remove_duplicates=${arg#REMOVE_DUPLICATES=} ;;
    esac
done

if [[ -z "$input_bam" || -z "$output_bam" || -z "$metrics_file" ]]; then
    echo "Expected Shiver to pass I=, O=, and M= arguments." >&2
    exit 2
fi

case "$remove_duplicates" in
    true|True) remove_duplicates=true ;;
    false|False) remove_duplicates=false ;;
    *)
    echo "Expected REMOVE_DUPLICATES=true or REMOVE_DUPLICATES=false." >&2
    exit 2
    ;;
esac

if [[ ! -f "$input_bam" ]]; then
    echo "Input BAM does not exist: $input_bam" >&2
    exit 1
fi

sample=${input_bam##*/}
sample=${sample%_PreDedup.bam}
sample=${sample%_remap}
rg_bam="${output_bam%.bam}.with_read_groups.tmp.bam"

if [[ "$rg_bam" == "$output_bam" ]]; then
    rg_bam="${output_bam}.with_read_groups.tmp.bam"
fi

trap 'rm -f "$rg_bam"' EXIT

# These defaults assume one Illumina library per sample. Replace the values
# here with the actual read-group metadata if the input combines libraries.
picard AddOrReplaceReadGroups \
    I="$input_bam" \
    O="$rg_bam" \
    SORT_ORDER=coordinate \
    RGID="$sample" \
    RGLB="$sample" \
    RGPL=ILLUMINA \
    RGPU="$sample" \
    RGSM="$sample"

picard MarkDuplicates \
    I="$rg_bam" \
    O="$output_bam" \
    M="$metrics_file" \
    REMOVE_DUPLICATES="$remove_duplicates"
