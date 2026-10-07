* cleanup.do — removes files created by the benchmark scripts
* Run from the repository folder: do cleanup.do
* The .do and .ado files, README and LICENSE are never touched.

* Choose what to remove (1 = remove, 0 = keep)
local remove_runs      1   // per-run files: mem_*.txt, ok_*.txt, bench logs
local remove_results   0   // summary results: mem_results*.dta
local remove_test_data 0   // test datasets: test_data*.dta (slow to regenerate)

* Patterns are written without quotes: a local whose value starts and ends
* with " has those outer quotes stripped, which breaks a list of quoted words
local patterns
if `remove_runs'      local patterns `patterns' ///
				mem_*.txt ok_*.txt bench_*.log bench-*.log bench.log
if `remove_results'   local patterns `patterns' mem_results*.dta
if `remove_test_data' local patterns `patterns' test_data*.dta

local n = 0
foreach p in `patterns' {
	local files : dir . files "`p'"
	foreach f in `files' {
		erase "`f'"
		local ++n
	}
}
disp as text "cleanup.do: removed `n' file(s)"
