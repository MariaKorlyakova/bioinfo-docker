FROM ubuntu:22.04

ARG LIBDEFLATE_VERSION=1.25
ARG HTSLIB_VERSION=1.24
ARG SAMTOOLS_VERSION=1.24
ARG BCFTOOLS_VERSION=1.24
ARG VCFTOOLS_VERSION=0.1.17

ARG DEBIAN_FRONTEND=noninteractive
ENV SOFT=/soft

WORKDIR /tmp

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        pkg-config \
        curl \
        ca-certificates \
        bzip2 \
        zlib1g-dev \
        libbz2-dev \
        liblzma-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libncurses-dev && \
    rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash"]