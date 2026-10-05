* bench.do — runs one reshape method on test_data.dta; called by run-benchmarks.do
args method
use test_data, clear

if      ("`method'" == "baseline")    qui disp ""
else if ("`method'" == "reshape")     reshape  long var, i(id) j(new)
else if ("`method'" == "greshape")    greshape long var, i(id) j(new)
else if ("`method'" == "jreshape10")  jreshape long var, i(id) j(new) nbatches(10)
else if ("`method'" == "jreshape100") jreshape long var, i(id) j(new) nbatches(100)

* Reached only if everything above succeeded
tempname ok
file open `ok' using ok_`method'.txt, write replace
file close `ok'
