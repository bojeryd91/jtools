clear
set seed 20261005
set obs  1000000
gen long g  = runiformint(1, 5000)
gen x       = rnormal()
gen w       = runiform()
replace x   = . in 1/1000
tempfile d
save `d'

collapse (mean) m=x (p50) med=x (sum) s=x (count) n=x [aw=w], by(g)
tempfile ref
save `ref'

use `d', clear
jcollapse (mean) m=x (p50) med=x (sum) s=x (count) n=x [aw=w], by(g) nbatches(10)

qui ds g, not
foreach var in `r(varlist)' {
	rename `var' `var'_j
}

merge 1:1 g using `ref'
gen diff = s - s_j
sum diff, d
