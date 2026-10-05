clear all
local stata   "/Applications/Stata/StataSE.app/Contents/MacOS/stata-se"

*** Generate test data once
set seed 20261004
set obs  8534019
gen long id = _n
forval k = 1/20 {
	gen var`k' = `k'*1.1 + rnormal()
}
save test_data, replace
describe, short
local data_bytes = r(width) * r(N)
clear

*** Run each method in its own Stata process and collect memory figures
tempname results
postfile `results' str20 method method_j iteration byte ok ///
					double(max_rss peak_footprint real_s user_s sys_s) ///
												using mem_results, replace
local j = 1
foreach m in baseline reshape greshape jreshape10 jreshape100 {
	disp "Method: " %23s "`m', iteration:", _cont
	forval i = 1/11 {
		disp "`i', ", _cont
		capture rm ok_`m'.txt
		qui shell /usr/bin/time -l "`stata'" -b do bench.do `m' 2> mem_`m'.txt
		copy bench.log bench_`m'.log, replace       // keep each run's log

		capture confirm file ok_`m'.txt
		local ok = (_rc == 0)

		* Parse the "time -l" output: the number comes first on each line
		local rss  .
		local peak .
		local real .
		local user .
		local sys  .
		tempname fh
		file open `fh' using mem_`m'.txt, read text
		file read `fh' line
		while r(eof) == 0 {
			if strpos(`"`line'"', "maximum resident set size") local rss  : word 1 of `line'
			if strpos(`"`line'"', "peak memory footprint")     local peak : word 1 of `line'
			if strpos(`"`line'"', " real ") {
				local real : word 1 of `line'
				local user : word 3 of `line'
				local sys  : word 5 of `line'
			}
			file read `fh' line
		}
		file close `fh'

		post `results' ("`m'") (`j') (`i') (`ok') (`rss') (`peak') ///
												(`real') (`user') (`sys')
	}
	disp ""
	local ++j
}
postclose `results'

*** Summarise relative to baseline and data size
use mem_results, clear

gcollapse (mean) ok  (p50) max_rss peak_ user_ real_ sys_, by(method*)
sort method_j
drop method_j

gen peak_gb     = peak_footprint / 1e9
gen extra_gb    = (peak_gb - peak_gb[1])   		  if _n > 1 // row 1 = baseline
gen extra_ratio = extra_gb / peak_gb[1]
gen extra_s     = (real_s  - real_s[2])/real_s[2] if _n > 2 // row 2 = reshape
format peak_gb extra_* %6.3g
list method ok peak_gb extra_gb extra_ratio real_s extra_s, noobs sep(0)
