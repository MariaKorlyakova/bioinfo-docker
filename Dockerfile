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

# libdeflate 1.25 (released 2025-11-01)
# https://github.com/ebiggers/libdeflate/releases/tag/v1.25
RUN curl -fsSL -o libdeflate.tar.gz \
        "https://github.com/ebiggers/libdeflate/releases/download/v${LIBDEFLATE_VERSION}/libdeflate-${LIBDEFLATE_VERSION}.tar.gz" && \
    tar -xzf libdeflate.tar.gz && \
    cd "libdeflate-${LIBDEFLATE_VERSION}" && \
    cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${SOFT}/libdeflate-${LIBDEFLATE_VERSION}" && \
    cmake --build build -j"$(nproc)" && \
    cmake --install build && \
    cd /tmp && \
    rm -rf libdeflate.tar.gz "libdeflate-${LIBDEFLATE_VERSION}"

ENV PATH="${SOFT}/libdeflate-${LIBDEFLATE_VERSION}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${SOFT}/libdeflate-${LIBDEFLATE_VERSION}/lib"
ENV LIBRARY_PATH="${SOFT}/libdeflate-${LIBDEFLATE_VERSION}/lib"
ENV C_INCLUDE_PATH="${SOFT}/libdeflate-${LIBDEFLATE_VERSION}/include"
ENV PKG_CONFIG_PATH="${SOFT}/libdeflate-${LIBDEFLATE_VERSION}/lib/pkgconfig"
ENV LIBDEFLATEGZIP="${SOFT}/libdeflate-${LIBDEFLATE_VERSION}/bin/libdeflate-gzip"
ENV LIBDEFLATEGUNZIP="${SOFT}/libdeflate-${LIBDEFLATE_VERSION}/bin/libdeflate-gunzip"

# HTSlib 1.24 (released 2026-07-09)
# https://github.com/samtools/htslib/releases/tag/1.24
RUN curl -fsSL -o htslib.tar.bz2 \
        "https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2" && \
    tar -xjf htslib.tar.bz2 && \
    cd "htslib-${HTSLIB_VERSION}" && \
    ./configure \
        --prefix="${SOFT}/htslib-${HTSLIB_VERSION}" \
        --with-libdeflate \
        --enable-libcurl && \
    make -j"$(nproc)" && \
    make install && \
    cd /tmp && \
    rm -rf htslib.tar.bz2 "htslib-${HTSLIB_VERSION}"

ENV PATH="${SOFT}/htslib-${HTSLIB_VERSION}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${SOFT}/htslib-${HTSLIB_VERSION}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${SOFT}/htslib-${HTSLIB_VERSION}/lib:${LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${SOFT}/htslib-${HTSLIB_VERSION}/include:${C_INCLUDE_PATH}"
ENV PKG_CONFIG_PATH="${SOFT}/htslib-${HTSLIB_VERSION}/lib/pkgconfig:${PKG_CONFIG_PATH}"
ENV HTSFILE="${SOFT}/htslib-${HTSLIB_VERSION}/bin/htsfile"
ENV BGZIP="${SOFT}/htslib-${HTSLIB_VERSION}/bin/bgzip"
ENV TABIX="${SOFT}/htslib-${HTSLIB_VERSION}/bin/tabix"
ENV ANNOTTSV="${SOFT}/htslib-${HTSLIB_VERSION}/bin/annot-tsv"
ENV REFCACHE="${SOFT}/htslib-${HTSLIB_VERSION}/bin/ref-cache"

# SAMtools 1.24 (released 2026-07-09)
# https://github.com/samtools/samtools/releases/tag/1.24
RUN curl -fsSL -o samtools.tar.bz2 \
        "https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2" && \
    tar -xjf samtools.tar.bz2 && \
    cd "samtools-${SAMTOOLS_VERSION}" && \
    ./configure \
        --prefix="${SOFT}/samtools-${SAMTOOLS_VERSION}" \
        --with-htslib="${SOFT}/htslib-${HTSLIB_VERSION}" && \
    make -j"$(nproc)" && \
    make install && \
    cd /tmp && \
    rm -rf samtools.tar.bz2 "samtools-${SAMTOOLS_VERSION}"

ENV PATH="${SOFT}/samtools-${SAMTOOLS_VERSION}/bin:${PATH}"
ENV SAMTOOLS="${SOFT}/samtools-${SAMTOOLS_VERSION}/bin/samtools"

# BCFtools 1.24 (released 2026-07-09)
# https://github.com/samtools/bcftools/releases/tag/1.24
RUN curl -fsSL -o bcftools.tar.bz2 \
        "https://github.com/samtools/bcftools/releases/download/${BCFTOOLS_VERSION}/bcftools-${BCFTOOLS_VERSION}.tar.bz2" && \
    tar -xjf bcftools.tar.bz2 && \
    cd "bcftools-${BCFTOOLS_VERSION}" && \
    ./configure \
        --prefix="${SOFT}/bcftools-${BCFTOOLS_VERSION}" \
        --with-htslib="${SOFT}/htslib-${HTSLIB_VERSION}" && \
    make -j"$(nproc)" && \
    make install && \
    cd /tmp && \
    rm -rf bcftools.tar.bz2 "bcftools-${BCFTOOLS_VERSION}"

ENV PATH="${SOFT}/bcftools-${BCFTOOLS_VERSION}/bin:${PATH}"
ENV BCFTOOLS_PLUGINS="${SOFT}/bcftools-${BCFTOOLS_VERSION}/libexec/bcftools"
ENV BCFTOOLS="${SOFT}/bcftools-${BCFTOOLS_VERSION}/bin/bcftools"

# VCFtools 0.1.17 (released 2025-05-15)
# https://github.com/vcftools/vcftools/releases/tag/v0.1.17
RUN curl -fsSL -o vcftools.tar.gz \
        "https://github.com/vcftools/vcftools/releases/download/v${VCFTOOLS_VERSION}/vcftools-${VCFTOOLS_VERSION}.tar.gz" && \
    tar -xzf vcftools.tar.gz && \
    cd "vcftools-${VCFTOOLS_VERSION}" && \
    ./configure \
        --prefix="${SOFT}/vcftools-${VCFTOOLS_VERSION}" \
        --with-pmdir=lib/perl5 && \
    make -j"$(nproc)" && \
    make install && \
    cd /tmp && \
    rm -rf vcftools.tar.gz "vcftools-${VCFTOOLS_VERSION}"

ENV PATH="${SOFT}/vcftools-${VCFTOOLS_VERSION}/bin:${PATH}"
ENV PERL5LIB="${SOFT}/vcftools-${VCFTOOLS_VERSION}/lib/perl5"
ENV VCFTOOLS="${SOFT}/vcftools-${VCFTOOLS_VERSION}/bin/vcftools"

CMD ["/bin/bash"]