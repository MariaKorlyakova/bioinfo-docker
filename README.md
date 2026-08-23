# Bioinformatics toolbox image

A Docker image with the current releases of SAMtools, BCFtools and VCFtools,
built on top of HTSlib and libdeflate, plus pysam and a script that recovers
reference alleles for a list of SNPs.

Everything is built from source into `/soft`, one directory per program with
the release version in its name.

## Contents

| Program | Version | Released | Install prefix |
|---|---|---|---|
| [libdeflate](https://github.com/ebiggers/libdeflate) | 1.25 | 2025-11-01 | `/soft/libdeflate-1.25` |
| [HTSlib](https://github.com/samtools/htslib) | 1.24 | 2026-07-09 | `/soft/htslib-1.24` |
| [SAMtools](https://github.com/samtools/samtools) | 1.24 | 2026-07-09 | `/soft/samtools-1.24` |
| [BCFtools](https://github.com/samtools/bcftools) | 1.24 | 2026-07-09 | `/soft/bcftools-1.24` |
| [VCFtools](https://github.com/vcftools/vcftools) | 0.1.17 | 2025-05-15 | `/soft/vcftools-0.1.17` |
| [pysam](https://github.com/pysam-developers/pysam) | 0.24.0 | 2026-04-27 | `/soft/pysam-0.24.0` |

Base image: `ubuntu:22.04`.

HTSlib is built against libdeflate and with libcurl enabled. SAMtools and
BCFtools are linked against that HTSlib rather than the copy bundled in their
own tarballs, so the image contains exactly one HTSlib. pysam is built from
source with `HTSLIB_MODE=external` for the same reason.

`restore_reference_alleles.py` is installed in `/soft/scripts` and described
in [FP_SNPs_README.md](FP_SNPs_README.md).

## Build

```bash
docker build -t bioinfo:1.0 .
```

A cold build takes under ten minutes, most of it spent fetching the Ubuntu
toolchain and compiling pysam, and produces an image of roughly 850 MB.

Versions are declared as build arguments, so a different release can be picked
without editing the Dockerfile:

```bash
docker build --build-arg SAMTOOLS_VERSION=1.23 -t bioinfo:samtools-1.23 .
```

Available arguments: `LIBDEFLATE_VERSION`, `HTSLIB_VERSION`,
`SAMTOOLS_VERSION`, `BCFTOOLS_VERSION`, `VCFTOOLS_VERSION`, `PYSAM_VERSION`.

## Run

Interactive shell inside the container:

```bash
docker run -it --rm bioinfo:1.0
```

`-i` keeps stdin open, `-t` allocates a terminal, `--rm` removes the container
on exit. All programs are already on `PATH`.

A single command can also be run without entering the shell:

```bash
docker run --rm bioinfo:1.0 samtools --version
```
