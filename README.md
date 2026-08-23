# Bioinformatics toolbox image

A Docker image with the current releases of SAMtools, BCFtools and VCFtools,
built on top of HTSlib and libdeflate.

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

Base image: `ubuntu:22.04`.

HTSlib is built against libdeflate and with libcurl enabled. SAMtools and
BCFtools are linked against that HTSlib rather than the copy bundled in their
own tarballs, so the image contains exactly one HTSlib.

## Build

```bash
docker build -t bioinfo:1.0 .
```

A cold build takes about 15 minutes and produces an image of roughly 710 MB.

Versions are declared as build arguments, so a different release can be picked
without editing the Dockerfile:

```bash
docker build --build-arg SAMTOOLS_VERSION=1.23 -t bioinfo:samtools-1.23 .
```

Available arguments: `LIBDEFLATE_VERSION`, `HTSLIB_VERSION`,
`SAMTOOLS_VERSION`, `BCFTOOLS_VERSION`, `VCFTOOLS_VERSION`.

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
