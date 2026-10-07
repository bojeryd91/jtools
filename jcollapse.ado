*! version 0.2.0  05oct2026  Jesper Böjeryd
*! Copyright (c) 2026 Jesper Böjeryd. MIT License.
*! Issues: https://github.com/bojeryd91/stata-jtools/issues
/*
	jcollapse: memory-efficient collapse for large datasets (part of stata-jtools)

	Collapses the data in batches so that the working memory needed by
	collapse scales with the batch rather than the full dataset. The data are
	saved to a temporary file; each batch is read back, collapsed and saved,
	and the collapsed batches are appended at the end. Batches never split a
	by() group, so every statistic (including medians and percentiles) is
	computed on the complete group and the result equals that of collapse.
	Uses gcollapse (gtools) for each batch if installed, otherwise collapse.

	Syntax:
		jcollapse clist [if] [in] [weight], by(varlist) [options]

	clist is specified as in collapse, e.g. (mean) x y (sum) total=z

	Options:
		by(varlist)   groups over which to collapse (required)
		nbatches(#)   split the data into about # batches (default 1)
		batchsize(#)  use batches of about # observations
		cw            casewise deletion (as in collapse)
		nogtools      use collapse even if gcollapse is installed
		fast          do not keep track of the original row order; on error,
		              the data are restored sorted by by() instead

	On error, the original data are restored.
	See README.md for details.
*/
program define jcollapse
	version 17.0
	syntax anything(name=clist equalok) [if] [in] [aw fw iw pw], ///
		by(varlist) [NBatches(integer 1) BATCHSize(integer 0) cw fast NOGtools]

	* Unless fast, record the original row order, to restore it on error
	if "`fast'" == "" {
		tempvar orig_order
		qui gen long `orig_order' = _n
	}

	* Observations selected by if/in (and nonmissing weights)
	marksample touse, novarlist
	qui count if `touse'
	if r(N) == 0 {
		disp as error "no observations"
		exit 2000
	}

	* Use gcollapse if installed, unless nogtools is specified
	local collapse collapse
	if "`gtools'`nogtools'" == "" {   // syntax stores nogtools in local gtools
		capture which gcollapse
		if !_rc local collapse gcollapse
	}

	* Weights are passed on to each batch
	local wgt
	if "`weight'" != "" local wgt [`weight'`exp']

	* Sort by group and assign rows to batches
	_jbatches `by', nbatches(`nbatches') batchsize(`batchsize')
	local edges    `r(edges)'
	local nbatches = r(nbatches)

	*** Save data to read from
	tempfile  all_data
	qui save `all_data'

	capture noi { // Do capture in case of internal error
		local parts
		forval ii = 1/`nbatches' {
			local ii_first : word   `ii'    of `edges'
			local ii_last  : word `=`ii'+1' of `edges'
			local --ii_last
			qui {
				use in `ii_first'/`ii_last' using `all_data', clear
				keep if `touse'
				if "`fast'" == "" drop `orig_order'   // not part of the collapse
			}
			if _N == 0 continue   // no selected observations in this batch

			qui {
				* fast: skip collapse's own preserve, which would copy the batch
				`collapse' `clist' `wgt', by(`by') `cw' fast

				tempfile  collapsed`ii'
				save `collapsed`ii''
			}
			local parts `parts' `ii'   // batches with output
		}
		qui {
			clear
			foreach ii of local parts {
				append using `collapsed`ii''
			}
			sort `by'
		}
	}
	local rc = _rc
	if `rc' { // If internal error occurs, reload the original data
		qui use `all_data', clear
		if "`fast'" == "" {
			sort `orig_order'
			disp as error "jcollapse failed; original data restored"
		}
		else {
			disp as error "jcollapse failed; original data restored, sorted by by()"
		}
		exit `rc'
	}
end
