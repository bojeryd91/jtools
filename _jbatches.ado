*! version 0.1.0  05oct2026  Jesper Böjeryd
*! Copyright (c) 2026 Jesper Böjeryd. MIT License.
*! Issues: https://github.com/bojeryd91/stata-jtools/issues
/*
	_jbatches: internal helper for the stata-jtools commands

	Sorts the data in memory by the group variables and splits the rows into
	batches of about batchsize() rows each, without splitting any group across
	two batches. Each group goes into the batch where its first row falls.

	Syntax:
		_jbatches varlist [, nbatches(#) batchsize(#)]

	Stored results:
		r(edges)      first row of each batch, plus _N+1 as a sentinel, so
		              batch b covers rows word(b) to word(b+1) - 1
		r(nbatches)   number of batches actually created (can be fewer than
		              nbatches(), because groups are kept whole)
		r(batchsize)  target batch size in rows

	Side effect: the data are left sorted by varlist.
*/
program define _jbatches, rclass
	version 17.0
	syntax varlist, [NBatches(integer 1) BATCHSize(integer 0)]

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

	* Target batch size in rows
	if `batchsize' == 0 local batchsize = ceil(_N/`nbatches')

	* Sort by group; each group joins the batch where its first row falls
	tempvar row batch start
	sort `varlist'
	qui {
		gen long `row' = _n
		by `varlist': gen long `batch' = ceil(`row'[1]/`batchsize')
		gen byte `start' = `batch' != `batch'[_n-1]
	}

	* First row of each batch, plus a sentinel one past the end
	mata: st_local("edges", invtokens(strofreal(selectindex( ///
									st_data(., "`start'"))', "%15.0f")))
	local edges `edges' `=_N + 1'
	local nb : word count `edges'
	local --nb
	drop `row' `batch' `start'

	return local  edges     "`edges'"
	return scalar nbatches  = `nb'
	return scalar batchsize = `batchsize'
end
