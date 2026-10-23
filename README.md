# Reproducing TANE (Huhtala et al., 1999)

Reproduction of the experiments in *TANE: An Efficient Algorithm for Discovering Functional and
Approximate Dependencies* (The Computer Journal 42(2), 1999), using the authors' original
C implementation (TANE 1.0). Data Wrangling, Assignment 2, Utrecht University.

## Repository structure

| Path | What it is |
|---|---|
| `src/`, `bin/select.perl`, `descriptions/README`, `original/testdata.orig`, `COPYING`, `GGPLICENSE`, `INSTALLATION`, `GETTINGSTARTED` | Original TANE 1.0 release by the authors (unchanged, GPL v2) |
| `run_tane.sh` | Builds TANE and runs it on the 100-row sample (sanity check) |
| `prepare_datasets.sh` | Downloads the UCI datasets, cleans them and converts them with `select.perl` |
| `run_experiments.sh` | Runs all experiments of Tables 1 and 2 → `results/all_results.csv` |
| `analysis.ipynb` | Compares the results with the paper; makes the figures |
| `descriptions/*.dsc` | Conversion settings per dataset (written by `prepare_datasets.sh`) |
| `results/` | Results: `all_results.csv`, `comparison.csv`, figures, and the full output of every run in `logs/` |

Compiled programs and the datasets are not in the repository; the scripts recreate them.

## How to reproduce

Requirements: macOS or Linux with a C compiler (`xcode-select --install` on macOS), Perl, and
Python 3 with `pandas` and `matplotlib`.

```bash
bash run_tane.sh            # build + sanity check: expect 62, 62 and 101 dependencies
bash prepare_datasets.sh    # download and convert the 5 UCI datasets (Wisconsin x1 ... x512)
bash run_experiments.sh     # all experiments of Tables 1 and 2 (about 30 s in total)
```

Then open `analysis.ipynb` and run all cells.

## Parameters

| Parameter | Value |
|---|---|
| Programs | `tane` (disk), `tanemem` (TANE/MEM), `taneg3` (approximate) |
| stoplevel | number of attributes (full search) |
| ε (`taneg3`) | 0.01, 0.05, 0.1, 0.5 |
| Wisconsin copies n | 1, 2, 4, …, 512 |
| Missing values `?` | kept as an ordinary value |
| Adult | `adult.data` + `adult.test`; trailing `.` in test labels kept (gives the paper's 85) |
| Compiler | Apple clang, flags from the original Makefile (`-O4 -DSTATISTICS`) |

## Result in short

53 of the 59 experiments reported in the paper give exactly the same number of dependencies.
The 6 differences (Wisconsin × n, n ≥ 2, at ε = 0.5: 82 instead of 18) are explained in
`analysis.ipynb`, step 8. Running time scales linearly with the number of rows (log-log slope ≈ 1),
as claimed in the paper.

## License

TANE 1.0 is © 1997 Y. Huhtala, J. Kärkkäinen, P. Porkka and H. Toivonen, distributed under the
GNU GPL v2 (see `COPYING` and `GGPLICENSE`). The datasets come from the UCI Machine Learning Repository.
