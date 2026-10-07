*! version 0.3.0  05oct2026  Jesper Böjeryd
*! Copyright (c) 2026 Jesper Böjeryd. MIT License.
*! Issues: https://github.com/bojeryd91/stata-jtools/issues
/*
	jreshape: memory-efficient reshape for large datasets (part of stata-jtools)

	Reshapes the data in batches so that the working memory needed by reshape
	scales with the batch rather than the full dataset. The data are saved to a
	temporary file; each batch is read back, reshaped and saved, and the
	reshaped batches are appended at the end. Batches never split an i() group.
	Uses greshape (gtools) for each batch if installed, otherwise reshape.

	Syntax:
		jreshape long|wide stubnames, i(varlist) j(varname) [options]
		jreshape long|wide stubnames, by(varlist) keys(varname) [options]

	Options:
		nbatches(#)   split the data into about # batches (default 1)
		batchsize(#)  use batches of about # observations
		string        j() is a string variable
		nogtools      use reshape even if greshape is installed
		fast          do not keep track of the original row order; on error,
		              the data are restored sorted by i() instead

	On error, the original data are restored.
	See README.md for details and benchmarks.
*/
program define jreshape
	version 17.0
	syntax anything, ///
		[i(varlist) j(string) by(varlist) KEYs(string) ///
			NBatches(integer 1) BATCHSize(integer 0) string NOGtools fast]
	
	* Check if long or wide
	gettoken direction : anything
	if !inlist("`direction'", "long", "wide") {
		disp as error "Specify long or wide"
		exit 198
	}
	
	* Use either i()/j() or by()/keys(), not a mix
	if "`by'`keys'" != "" & "`i'`j'" != "" {
		disp as error "You cannot mix the i()/j() and by()/keys() syntaxes"
		exit 198
	}
	if "`by'`keys'" != "" {
		local i `by'
		local j `keys'
	}
	if "`i'" == "" | "`j'" == "" {
		disp as error "Specify both i() and j(), or both by() and keys()"
		exit 198
	}
	
	* Use greshape if installed, unless nogtools is specified
	local reshape reshape
	if "`gtools'`nogtools'" == "" {   // syntax stores nogtools in local gtools
		capture which greshape
		if !_rc local reshape greshape
	}

	* Unless fast, record the original row order, to restore it on error
	if "`fast'" == "" {
		tempvar orig_order
		qui gen long `orig_order' = _n
	}

	* Sort by i() and assign rows to batches
	_jbatches `i', nbatches(`nbatches') batchsize(`batchsize')
	local edges    `r(edges)'
	local nbatches = r(nbatches)

	*** Save data to read from
	tempfile  all_data
	qui save `all_data'
	
	capture noi { // Do capture in case of internal error
		forval ii = 1/`nbatches' {
			local ii_first : word   `ii'    of `edges'
			local ii_last  : word `=`ii'+1' of `edges'
			local --ii_last
			qui {
				use in `ii_first'/`ii_last' using `all_data', clear
				if "`fast'" == "" drop `orig_order'   // not part of the reshape
				
				`reshape' `anything', i(`i') j(`j') `string'
				
				tempfile  reshaped`ii'
				save `reshaped`ii''
			}
		}
		qui {
			clear
			forval ii = 1/`nbatches' {
				append using `reshaped`ii''
			}
		}
	}
	local rc = _rc
	if `rc' { // If internal error occurs, reload the original data
		qui use `all_data', clear
		if "`fast'" == "" {
			sort `orig_order'
			disp as error "jreshape failed; original data restored"
		}
		else {
			disp as error "jreshape failed; original data restored, sorted by i()"
		}
		exit `rc'
	}
end
