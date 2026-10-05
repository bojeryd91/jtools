# jtools

Stata tools for manipulating large datasets with limited memory.

## jreshape

`jreshape` is a drop-in replacement for `reshape` that processes the data in
batches. The data are saved to a temporary file, each batch is read back,
reshaped and saved, and the reshaped batches are appended at the end. Only one
batch is reshaped in memory at a time, so the working memory that `reshape`
needs scales with the batch rather than the full dataset.

Batches never split an `i()` group, so `jreshape wide` gives the same result as
`reshape wide`. If [gtools](https://github.com/mcaceresb/stata-gtools) is
installed, each batch is reshaped with `greshape`; otherwise with `reshape`.

### Syntax

```stata
jreshape long|wide stubnames, i(varlist) j(varname) [options]
jreshape long|wide stubnames, by(varlist) keys(varname) [options]
```

`by()`/`keys()` follow the `greshape` naming and are synonyms for `i()`/`j()`.
The two styles cannot be mixed.

| Option         | Description                                                |
|----------------|------------------------------------------------------------|
| `nbatches(#)`  | Split the data into about `#` batches (default 1)          |
| `batchsize(#)` | Use batches of about `#` observations                      |
| `string`       | `j()` is a string variable (as in `reshape`)               |

Specify at most one of `nbatches()` and `batchsize()`. Batch sizes are
approximate, because each `i()` group is kept whole.

### Example

```stata
jreshape long var, i(id) j(year) nbatches(10)
jreshape wide var, i(id) j(year) batchsize(1000000)
```

### Notes

- The output is sorted by `i()` (and `j()` for `long`).
- If an error occurs, the original data are restored, sorted by `i()`.
- Requires Stata 17 or later.

### Installation

Copy `jreshape.ado` to your PERSONAL ado directory (type `sysdir` in Stata to
find it), or to the working directory of your project.

## Benchmarks

`run-benchmarks.do` runs each method in a separate Stata batch process and
records peak memory and run time with `/usr/bin/time -l` (macOS). Each method
is run 11 times; the table reports medians.

- **Data:** 8,534,019 observations, `id` plus 20 numeric variables, reshaped
  `long` (about 170 million output rows).
- **Machine:** [MacBook model, chip, RAM], Stata/SE 17.
- **Baseline:** Stata with the test data loaded and no reshape.

| Method                    | Peak memory (GB) | Extra memory (GB) | Extra / baseline | Run time (s) | Time vs. `reshape` |
|---------------------------|-----------------:|------------------:|-----------------:|-------------:|-------------------:|
| Baseline (load only)      | 0.000            | –                 | –                | 0.00         | –                  |
| `reshape`                 | 0.000            | 0.000             | 0.00             | 0.00         | –                  |
| `greshape`                | 0.000            | 0.000             | 0.00             | 0.00         | +0.00              |
| `jreshape`, 10 batches    | 0.000            | 0.000             | 0.00             | 0.00         | +0.00              |
| `jreshape`, 100 batches   | 0.000            | 0.000             | 0.00             | 0.00         | +0.00              |

*Extra memory* is the method's peak minus the baseline peak. *Extra / baseline*
is extra memory as a multiple of the baseline peak. *Time vs. `reshape`* is the
relative difference in run time (−0.50 = half the time of `reshape`).

To reproduce: set the path to your Stata executable at the top of
`run-benchmarks.do` and run it from the repository folder. Requires gtools.
