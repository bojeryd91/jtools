# stata-jtools

Stata tools for manipulating large datasets with limited memory.

Commands such as `reshape` can need several times the dataset's size in
working memory. When that exceeds the RAM available, Stata stops with an
out-of-memory error or slows to a crawl as the operating system swaps memory
to disk, which can make Stata freeze. The commands in this repository process
the data in pieces, so the extra memory needed stays bounded and large jobs
finish instead of freezing Stata.

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
- When `greshape` is installed, `jreshape` uses it for every batch and inherits
  its limitations. In particular, `greshape` does not implement `reshape`'s
  extended syntax (typing `reshape long` or `reshape wide` with no arguments to
  reverse a previous reshape) or the subcommands `error`, `query`, `i`, `j`,
  `xij`, `xi` and `clear`. See the
  [greshape documentation](https://gtools.readthedocs.io/en/latest/usage/greshape/index.html).
  There is currently no option to force built-in `reshape` when `greshape` is
  installed (see the to-do list below).

### Installation

Copy `jreshape.ado` to your PERSONAL ado directory (type `sysdir` in Stata to
find it), or to the working directory of your project.

## Benchmarks

`run-benchmarks.do` runs each method in a separate Stata batch process and
records peak memory and run time with `/usr/bin/time -l` (macOS). Each method
is run 11 times; the table reports medians.

- **Data:** 8,534,019 observations, `id` plus 20 numeric variables, reshaped
  `long` (about 170 million output rows).
- **Machine:** [MacBook Pro, M3 Pro, 36GB], Stata/SE 17.
- **Baseline:** Stata with the test data loaded and no reshape.

| Method                    | Peak memory (GB) | Extra memory (GB) | Extra / baseline | Run time (s) | Run time / `reshape` |
|---------------------------|-----------------:|------------------:|-----------------:|-------------:|-------------------:|
| Baseline (load only)      | 0.818            | –                 | –                |   0.14       | –                  |
| `reshape`                 | 3.22             | 2.40              | 2.93             | 127          | –                  |
| `greshape`                | 6.71             | 5.89              | 7.20             |   6.17       | -0.95              |
| `jreshape`, 10 batches    | 2.71             | 1.89              | 2.31             |  15.3        | -0.88              |
| `jreshape`, 100 batches   | 2.62             | 1.80              | 2.20             |  26.8        | -0.79              |

*Extra memory* is the method's peak minus the baseline peak. *Extra / baseline*
is extra memory as a multiple of the baseline peak. *Run time / `reshape`* is the
relative difference in run time (−0.50 = half the time of `reshape`).

To reproduce: set the path to your Stata executable at the top of
`run-benchmarks.do` and run it from the repository folder. Requires gtools.

## To do

- [ ] Option to use built-in `reshape` even when `greshape` is installed, for
      features `greshape` does not support
- [ ] Keep `reshape`'s dataset characteristics, so that `reshape long`/`reshape
      wide` with no arguments reverses a `jreshape`
- [ ] Restore the original sort order (not only the data) after an error
- [ ] Order the columns of `jreshape wide` output as `reshape wide` does
- [ ] Help file (`jreshape.sthlp`)
- [ ] Package files (`stata.toc`, `jtools.pkg`) for `net install` from GitHub
- [ ] More commands for large datasets
