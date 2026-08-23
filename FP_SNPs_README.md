# FP SNPs: recovering reference alleles

GRAF ships a list of fingerprinting SNPs in `FP_SNPs.txt`. They are used to
spot duplicate and related samples without comparing whole genomes.

The file gives two alleles per variant but never says which one the reference
genome carries. These notes cover how that was worked out.

## The script

[`restore_reference_alleles.py`](restore_reference_alleles.py) takes a table of
SNPs with two alleles each, looks up the reference base at every position, and
decides which allele is REF and which is ALT.

```
#CHROM  POS  ID  allele1  allele2     ->     #CHROM  POS  ID  REF  ALT
```

The reference base is read with `pysam.FastaFile` from per-chromosome FASTA
files. Whichever allele equals it becomes REF, the other becomes ALT. If
neither matches, the variant is counted, reported in the log, and left out of
the output.

```
usage: restore_reference_alleles.py [-h] -i FILE -o FILE [-r DIR] [-l FILE]
                                    [--allow-strand-flip]
```

| Option | Meaning |
|---|---|
| `-i`, `--input` | input TSV (required) |
| `-o`, `--output` | output TSV (required) |
| `-r`, `--reference-genome` | directory of `chr*.fa` files (default `/ref/GRCh38.d1.vd1_mainChr/sepChrs`) |
| `-l`, `--log` | log file |
| `--allow-strand-flip` | also resolve variants read from the opposite DNA strand |

It checks that the header is the one it expects, accepts either Unix or Windows
line endings, skips malformed rows with a warning instead of stopping, and
writes a timestamped log.

## Preparing the input

`FP_SNPs.txt` comes from the GRAF package:

```bash
curl -fsSL -o GRAF_files.zip \
    "https://www.ncbi.nlm.nih.gov/projects/gap/cgi-bin/GetZip.cgi?zip_name=GRAF_files.zip"

mkdir graf
tar -xzf GRAF_files.zip -C graf
cp graf/data/FP_SNPs.txt .
```

The download is named `.zip` but is really `GrafPkg2.4.tar.gz`, so it needs
`tar`, not `unzip`.

It has 11 000 rows and 6 columns — `rs#`, `chromosome`, `GB37_position`,
`GB38_position`, `allele1`, `allele2` — and needs four changes: drop the GRCh37
coordinate, rename and reorder the columns, add the `chr` and `rs` prefixes,
and drop chromosome X.

Chromosome X is written as `23` and holds 1 000 variants used for sex typing.
Dropping them leaves the 10 000 autosomal SNPs — hence `10k` in the output file
name.

```bash
awk -F'\t' -v OFS='\t' '
    NR == 1  { next }                                # skip the header
    $2 == 23 { next }                                # skip chromosome X
             { print "chr"$2, $4, "rs"$1, $5, $6 }   # reorder, add prefixes
' FP_SNPs.txt > body.tsv
```

`-F'\t'` and `OFS='\t'` make awk read and write tab-separated fields. The
GRCh37 coordinate is dropped simply by never being printed.

Rows come sorted by the GRCh37 coordinate, and that order no longer holds under
GRCh38, so they are sorted again. `-V` keeps `chr2` before `chr10`:

```bash
sort -k1,1V -k2,2n body.tsv > body_sorted.tsv
```

The old header is replaced rather than edited, because every column is renamed
and the first field has to start with `#CHROM`:

```bash
printf '#CHROM\tPOS\tID\tallele1\tallele2\n' > FP_SNPs_10k_GB38_twoAllelsFormat.tsv
cat body_sorted.tsv >> FP_SNPs_10k_GB38_twoAllelsFormat.tsv
rm body.tsv body_sorted.tsv
```

The result should be one header line plus the 10 000 autosomal variants:

```bash
wc -l < FP_SNPs_10k_GB38_twoAllelsFormat.tsv
```

### Reference genome

Not part of this repository. The GRCh38.d1.vd1 FASTA from the
[GDC](https://gdc.cancer.gov/about-data/data-harmonization-and-generation/gdc-reference-files)
is split into the 25 main chromosomes and indexed. The `.fai` indexes are what
let pysam read a single base without scanning the whole file:

```bash
mkdir sepChrs
samtools faidx GRCh38.d1.vd1.fa

for c in {1..22} M X Y; do
    samtools faidx GRCh38.d1.vd1.fa "chr$c" > "sepChrs/chr$c.fa"
    samtools faidx "sepChrs/chr$c.fa"
done
```

## Running it on FP_SNPs.txt

The reference genome is mounted into the container at run time:

```bash
docker run --rm \
    -v /mnt/data/ref/GRCh38.d1.vd1_mainChr/sepChrs:/ref/GRCh38.d1.vd1_mainChr/sepChrs:ro \
    -v "$PWD":/work -w /work \
    bioinfo:1.1 \
    restore_reference_alleles.py \
        -i FP_SNPs_10k_GB38_twoAllelsFormat.tsv \
        -o FP_SNPs_10k_GB38_RefAlt.tsv \
        -l restore_reference_alleles.log
```

The script opens each chromosome file once, walks the variants in order, and
reads one base per variant. On this input it takes a couple of seconds.

## Results

| Outcome | Variants |
|---|---|
| reference base is allele1 | 3 650 |
| reference base is allele2 | 6 341 |
| matches the complement of an allele | 9 |
| written to the output | 9 991 |

Almost everything resolved. Nothing was lost for lack of a reference base:
there were no `N` positions, no coordinates past the end of a chromosome, and
no variant whose base matched neither allele in either orientation.

The reference allele is `allele2` noticeably more often than `allele1`, so the
order of the two alleles in `FP_SNPs.txt` is probably not a REF/ALT assignment —
more likely they are ordered by something else, such as population frequency.

### What did not convert

Nine variants were left out. In every one of them the reference base matches
the complement of an allele rather than the allele itself, which most likely
means they were recorded against the opposite DNA strand.

| ID | Position | Reference | Alleles | Complement |
|---|---|---|---|---|
| rs2274617 | chr1:145899155 | G | T/C | **A/G** |
| rs10994675 | chr10:46031829 | C | A/G | **T/C** |
| rs2790937 | chr10:47099482 | T | G/A | **C/T** |
| rs12414155 | chr10:47268342 | A | T/C | **A/G** |
| rs11204215 | chr10:47320207 | T | C/A | **G/T** |
| rs4342964 | chr10:47420743 | G | T/C | **A/G** |
| rs527464 | chr11:54678670 | G | C/T | **G/A** |
| rs4778334 | chr15:22832212 | A | T/C | **A/G** |
| rs7174982 | chr15:22907410 | G | T/C | **A/G** |

Other explanations look far less likely. An off-by-one error in the coordinates
would misplace every variant, not nine of them. Coordinates from a different
build would fail all over the genome rather than in two narrow regions.
Undefined reference sequence would show up as `N`, and none did. Random errors
in the source data would not land on a complement every single time.

The complement reading is also unambiguous here. The panel deliberately
excludes palindromic pairs (`A/T`, `C/G`), where one allele is the complement of
the other and a single base cannot tell the two strands apart.

Six of the nine sit in two regions that had already looked odd during
preprocessing: the input is ordered by GRCh37 coordinate, and it stops being
ordered under GRCh38 in exactly those places. An inversion explains both at
once — a segment stored the other way round has its coordinates running
backwards and its strands swapped. That can be checked: an inversion maps
coordinates by reflection, so within an inverted block `GB37 + GB38` should be
constant. It is, exactly:

| Chromosome | Variants | `GB37 + GB38` |
|---|---|---|
| chr10 | 4 | 95 739 362 |
| chr15 | 2 | 45 873 068 |

The other three are each the only panel variant in their region, so there is no
second coordinate to compare against. A strand flip is still the likely
explanation, but the rearrangement behind it cannot be identified from these
two columns alone.

These nine are excluded by default because the task is to say which of the two
*listed* alleles is the reference one, and for them neither is. Running with
`--allow-strand-flip` resolves them and writes all 10 000.

### The output file

`FP_SNPs_10k_GB38_RefAlt.tsv` — 9 991 variants plus a header, tab-separated,
sorted by coordinate, in GRCh38.

```
#CHROM  POS      ID          REF  ALT
chr1    1220751  rs2887286   T    C
chr1    1275912  rs6685064   C    T
chr1    2352457  rs2840528   A    G
```

The first row shows the point of the exercise: the input listed the alleles as
`C/T`, the reference carries `T`, so REF and ALT come out in the opposite order
from the input.

## Files

| File | Description |
|---|---|
| `FP_SNPs.txt` | original file from GRAF 2.4 |
| `FP_SNPs_10k_GB38_twoAllelsFormat.tsv` | after preprocessing, autosomal variants only |
| `restore_reference_alleles.py` | the script |
| `FP_SNPs_10k_GB38_RefAlt.tsv` | output, with REF and ALT |
| `restore_reference_alleles.log` | log of the run that produced it |
