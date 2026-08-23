#!/usr/bin/env python3

"""
Determine which of two observed alleles of a SNP is the reference allele.

Reads a tab-separated table of biallelic SNPs in the format:

    #CHROM  POS  ID  allele1  allele2

looks up the reference base at each position in a GRCh38 reference genome,
and writes the same variants with the alleles resolved:

    #CHROM  POS  ID  REF  ALT
"""

import sys
import time
from pathlib import Path
from collections import Counter

import click
from loguru import logger
from pysam import FastaFile

LOG_FORMAT = "{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {message}"
EXPECTED_HEADER = ["#CHROM", "POS", "ID", "allele1", "allele2"]
OUTPUT_HEADER = ["#CHROM", "POS", "ID", "REF", "ALT"]
COMPLEMENT = {"A": "T", "T": "A", "G": "C", "C": "G"}
PROGRESS_EVERY = 1000


def setup_logging(log_file: Path) -> None:
    logger.remove()
    logger.add(sys.stderr, format=LOG_FORMAT, level="INFO")
    logger.add(log_file, format=LOG_FORMAT, level="INFO", mode="w")


def open_chromosome(
    reference_genome: Path,
    chrom: str,
    handles: dict[str, FastaFile],
    missing: set[str],
) -> FastaFile | None:
    """Return an open FASTA file for a chromosome, or None if there is none."""
    if chrom in handles:
        return handles[chrom]
    if chrom in missing:
        return None

    fasta = reference_genome / f"{chrom}.fa"
    if not fasta.is_file():
        logger.warning("No reference file for {}, its variants are skipped.", chrom)
        missing.add(chrom)
        return None

    index = fasta.parent / (fasta.name + ".fai")
    if not index.is_file():
        raise click.ClickException(
            f"Missing FASTA index: {index}\nCreate it with: samtools faidx {fasta}"
        )

    handles[chrom] = FastaFile(str(fasta))
    logger.info("Opened reference file {}.", fasta)
    return handles[chrom]


def determination_of_alleles(
    ref_base: str,
    allele1: str,
    allele2: str,
    allow_strand_flip: bool,
) -> tuple[str | None, str | None, str]:
    """Determine which allele is the reference one.

    Returns (ref, alt, outcome). `ref` is None when the variant cannot be
    resolved; `outcome` always names the category for the statistics.
    """
    if ref_base == allele1:
        return allele1, allele2, "reference_is_allele1"
    if ref_base == allele2:
        return allele2, allele1, "reference_is_allele2"
    if ref_base == "N":
        return None, None, "reference_is_n"

    # The reference base may match the complement of an allele, which means
    # the variant was read from the opposite DNA strand. Such variants are
    # only resolved when --allow-strand-flip is given.
    flipped1 = COMPLEMENT.get(allele1)
    flipped2 = COMPLEMENT.get(allele2)
    if ref_base == flipped1:
        if allow_strand_flip:
            return flipped1, flipped2, "strand_flip_resolved"
        return None, None, "strand_mismatch"
    if ref_base == flipped2:
        if allow_strand_flip:
            return flipped2, flipped1, "strand_flip_resolved"
        return None, None, "strand_mismatch"

    return None, None, "no_match"


def parse_line(
    line: str,
    line_no: int,
    stats: Counter[str],
) -> tuple[str, int, str, str, str] | None:
    """Split a data line into (chrom, coord, name, allele1, allele2).

    Returns None for malformed lines, which are counted and skipped.
    """
    fields = line.rstrip("\r\n").split("\t")

    if len(fields) != len(EXPECTED_HEADER):
        logger.warning("Line {}: expected {} columns, found {}, skipped.",
                       line_no, len(EXPECTED_HEADER), len(fields))
        stats["malformed_columns"] += 1
        return None

    chrom, coord_text, name, allele1, allele2 = fields

    try:
        coord = int(coord_text)
    except ValueError:
        logger.warning("Line {}: position {!r} is not an integer, skipped.",
                       line_no, coord_text)
        stats["malformed_position"] += 1
        return None

    if coord < 1:
        logger.warning("Line {}: position {} is not positive, skipped.",
                       line_no, coord)
        stats["malformed_position"] += 1
        return None

    return chrom, coord, name, allele1.upper(), allele2.upper()


def check_header(header: str) -> None:
    """Check the first line against the expected header."""
    fields = header.split("\t")
    if fields != EXPECTED_HEADER:
        expected = "\t".join(EXPECTED_HEADER)
        found = "\t".join(fields)
        raise click.ClickException(
            f"Unexpected header.\n  Expected: {expected}\n  Found:    {found}"
        )
    logger.info("Header validated.")


def report(stats: Counter[str], elapsed: float) -> None:
    """Write the final summary to the log."""
    logger.info("Summary:")
    logger.info("  variants read: {}", stats["variants_read"])
    for key in sorted(k for k in stats if k != "variants_read"):
        logger.info("  {}: {}", key, stats[key])
    logger.info("Finished in {:.2f} s.", elapsed)


@click.command()
@click.option("-i", "--input", "input_path", required=True,
              type=click.Path(exists=True, dir_okay=False, path_type=Path),
              help="Input TSV (format: #CHROM POS ID allele1 allele2).")
@click.option("-o", "--output", "output_path", required=True,
              type=click.Path(dir_okay=False, writable=True, path_type=Path),
              help="Output TSV (format: #CHROM POS ID REF ALT).")
@click.option("-r", "--reference-genome", default="/ref/GRCh38.d1.vd1_mainChr/sepChrs",
              show_default=True,
              type=click.Path(exists=True, file_okay=False, path_type=Path),
              help="Directory with chr*.fa files and their .fai indexes.")
@click.option("-l", "--log", "log_file", default="restore_reference_alleles.log",
              show_default=True, type=click.Path(dir_okay=False, path_type=Path),
              help="Path of the log file to write.")
@click.option("--allow-strand-flip", is_flag=True,
              help="Complement both alleles when the variant was read from "
                   "the opposite DNA strand.")
def main(
    input_path: Path,
    output_path: Path,
    reference_genome: Path,
    log_file: Path,
    allow_strand_flip: bool,
) -> None:
    """
    Recover reference alleles for biallelic SNPs.

    Script defines each of the two alleles as a reference (REF) or alternative
    (ALT) based on coordinates in the genomic assembly.
    """
    setup_logging(log_file)
    logger.info("Input: {}", input_path)
    logger.info("Output: {}", output_path)
    logger.info("Reference: {}", reference_genome)
    logger.info("Log: {}", log_file)
    logger.info("Strand flipping: {}", "enabled" if allow_strand_flip else "disabled")

    stats = Counter()
    handles = {}
    missing = set()
    started = time.monotonic()

    try:
        destination = output_path.open("w")
    except OSError as error:
        raise click.ClickException(f"Cannot write to {output_path}: {error}")

    with input_path.open() as source, destination:
        header = source.readline().rstrip("\r\n")
        check_header(header)

        destination.write("\t".join(OUTPUT_HEADER) + "\n")

        for line_no, line in enumerate(source, start=2):
            if not line.strip():
                stats["blank_lines"] += 1
                continue

            variant = parse_line(line, line_no, stats)
            if variant is None:
                continue

            chrom, coord, name, allele1, allele2 = variant
            stats["variants_read"] += 1

            handle = open_chromosome(reference_genome, chrom, handles, missing)
            if handle is None:
                stats["chromosome_unavailable"] += 1
                continue

            ref_base = handle.fetch(chrom, coord - 1, coord).upper()
            if not ref_base:
                logger.warning("Line {}: {}:{} is past the end of the "
                               "chromosome, skipped.", line_no, chrom, coord)
                stats["position_out_of_range"] += 1
                continue

            ref, alt, outcome = determination_of_alleles(ref_base, allele1, allele2,
                                                         allow_strand_flip)
            stats[outcome] += 1

            if ref is None:
                continue

            destination.write(f"{chrom}\t{coord}\t{name}\t{ref}\t{alt}\n")
            stats["written"] += 1

            if stats["variants_read"] % PROGRESS_EVERY == 0:
                logger.info("Processed {} variants.", stats["variants_read"])

    for handle in handles.values():
        handle.close()

    report(stats, time.monotonic() - started)
    logger.success("Done.")


if __name__ == "__main__":
    main()
