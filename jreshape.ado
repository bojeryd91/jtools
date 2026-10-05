*! version 0.1.0  04oct2026  Jesper Böjeryd
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

	On error, the original data are restored, sorted by i().
	See README.md for details and benchmarks.
*/
program define jreshape
	version 17.0
	syntax anything, ///
		[i(varlist) j(string) by(varlist) KEYs(string) ///
			NBatches(integer 1) BATCHSize(integer 0) string]
	
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
	
	
	* Check batch options
	if `nbatches' != 1 & `batchsize' != 0 {
		disp as error "You cannot specify both nbatches() and batchsize()"
		exit 198
	}
	if `nbatches' < 1 | `batchsize' < 0 {
		disp as error "nbatches() and batchsize() must be positive"
		exit 198
	}
	if _N == 0 {
		disp as error "no observations"
		exit 2000
	}
	
	* Check if greshape is installed
	qui {
		capture which greshape
		if _rc { // If greshape not found
			local reshape reshape  // fall back to built-in reshape
		}
		else { // If greshape is found
			local reshape greshape // use gtools version
		}
	}
	
		
	* Compute batch sizes and assign observations to batches
	local orig_N = _N
	if (`batchsize' == 0) local batchsize = ceil(`orig_N'/`nbatches')
	
	* Assign data to batches
	tempvar row batch start
	sort `i' //, stable
	qui {
		gen long `row' = _n
		by `i': gen long `batch' = ceil(`row'[1]/`batchsize')
		gen byte `start' = `batch' != `batch'[_n-1]
	}
	
	* First row of each batch, plus a sentinel one past the end
	mata: st_local("edges", invtokens(strofreal(selectindex( ///
										st_data(., "`start'"))', "%15.0f")))
	local edges `edges' `=_N + 1'
	local nbatches : word count `edges'
	local --nbatches
	drop `row' `batch' `start'
	
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
				
				`reshape' `anything', i(`i') j(`j') `string'
				
				
				tempfile  reshaped`ii'
				save `reshaped`ii''
			}
		}
		qui {
			clear
			forval ii = 1/`nbatches'{
				append using `reshaped`ii''
			}
		}
	}
	local rc = _rc
	if `rc' { // If internal error occurs, reload original (sorted) data
		qui use `all_data', clear
		disp as error "jreshape failed; original data restored (but sorted)"
		exit `rc'
	}
end
