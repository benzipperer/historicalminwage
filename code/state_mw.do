*TITLE: HISTORICAL MINIMUM WAGES, Expanding the Daily Minimum Wage Changes File

*Description: This .do file expands the daily minimum wage changes by state file and merges it with a daily federal minimum wage changes file.

set more off
clear all

*SETTING GLOBAL DIRECTORIES
* You will need to change the $home directory to an appropriate value.
global home `c(pwd)'/../
global raw ${home}rawdata/
global exports ${home}exports/
global release ${home}release/

local federal FederalMinimumWage_Changes
local states StateMinimumWage_Changes

* these dates should reflect complete sample of data
local begindate 01may1974
local finaldate 31dec2021

*IMPORTING A CROSSWALK FOR FIPS CODES, STATE NAMES, AND STATE ABBREVIATIONS
*Importing and "loading in" the crosswalk
import excel using ${raw}FIPS_crosswalk.xlsx, clear firstrow

*Renaming variables
rename Name statename
rename FIPSStateNumericCode statefips
rename OfficialUSPSCode stateabb
replace stateabb = upper(stateabb)
keep statename statefips stateabb
label var stateabb "State Abbreviation"
*Saving crosswalk as a temporary file
tempfile crosswalk
save `crosswalk'
*Storing the levels of State FIPS for use in expanding the federal file
levelsof statefips, local(fips)

*PREPARING THE FEDERAL MINIMUM WAGE CHANGES FILE
*Loading in the federal minimum wage data
import excel using ${raw}`federal'.xlsx, clear firstrow
rename Fed_mw fed_mw
keep year month day fed_mw source

*Creating a daily date variable
gen date = mdy(month,day,year)
format date %td

rename fed_mw old_fed_mw
gen double fed_mw = round(old_fed_mw, .01)
drop old_fed_mw
label var fed_mw "Federal Minimum Wage"
order year month day date fed_mw source

*Exporting to Stata .dta file
sort date
save ${exports}mw_federal_changes.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}mw_federal_changes.xlsx, replace firstrow(varlabels) datestring(%td)

*Expanding the date variable
tsset date
tsfill

*Filling in the missing parts of the data
carryforward year month day fed_mw, replace

*Dropping the year, month, and date variables and rearranging order of dataset
keep date fed_mw

*Creating a loop to add State FIPS codes to the federal minimum wage daily file so that we can create a file that has the federal minimum wage changes per state
tempfile temp
save `temp'

foreach i in `fips' {
	use `temp', clear
	gen statefips = `i'
	tempfile state`i'
	save `state`i''
}

foreach i in `fips' {
	if `i' == 1 use `state`i'', clear
	else quietly append using `state`i''
}

*Saving a tempfile
compress
tempfile fedmw
save `fedmw'


*PREPARING THE STATE MINIMUM WAGE CHANGES FILE
*Loading in the State by State minimum wage data
import excel using ${raw}`states'.xlsx, clear firstrow

*Creating a daily date variable
gen date = mdy(month,day,year)
format date %td

replace mw = round(mw, .01)
replace mw_healthinsurance = round(mw_healthinsurance, .01)
replace mw_smallbusiness = round(mw_smallbusiness, .01)

merge m:1 statefips using `crosswalk', nogen assert(3)

order statefips statename stateabb year month day date mw* source source_2 source_notes
label var statefips "State FIPS Code"
label var statename "State"

*Exporting to Stata .dta file
sort stateabb date
save ${exports}mw_state_changes.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}mw_state_changes.xlsx, replace firstrow(varlabels) datestring(%td)

*Expanding the date variable
tsset statefips date
tsfill

keep statefips date mw* source_notes

*Filling in the missing parts of the data
foreach x of varlist source_notes {
  bysort statefips (date): replace `x' = `x'[_n-1] if `x' == ""
}
foreach x of varlist mw* {
  bysort statefips (date): replace `x' = `x'[_n-1] if `x' == .
}


*MERGING THE FEDERAL AND THE STATE BY STATE DATA SET TO FIND WHERE FEDERAL MINIMUM WAGE SUPERCEDES THE STATE MINIMUM WAGE LEVEL
*Merging the federal and the state change data together
merge 1:1 statefips date using `fedmw', nogenerate
merge m:1 statefips using `crosswalk', nogen assert(3)

*Picking the higher minimum wage or replacing the missing minimum wages with the Federal minimum wage
gen mw_adj = mw
replace mw_adj = fed_mw if fed_mw >= mw & fed_mw ~= .
replace mw_adj = fed_mw if mw == . & fed_mw ~= .
drop mw
rename mw_adj mw

*Keeping complete sample only
keep if date >= td(`begindate') & date <= td(`finaldate')

order statefips statename stateabb date fed_mw mw
label var mw "State Minimum Wage"
notes mw: The mw variable represents the higher rate between the state and federal minimum wage

*Saving a temporary file
tempfile data
save `data'

*EXPORTING A DAILY DATASET WITH STATE MINIMUM WAGES, FEDERAL MININUM WAGES, and FINAL MINIMUM WAGE (based on the higher level between the state and federal minimum wages)
use `data', clear
*Exporting to Stata .dta file
sort stateabb date
compress
save ${exports}mw_state_daily.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}mw_state_daily.xlsx, replace firstrow(varlabels) datestring(%td)

*EXPORTING A MONTHLY DATASET WITH STATE MINIMUM WAGES, FEDERAL MININUMUM WAGES, and FINAL MINIMUM WAGE (based on the higher level between the state and federal minimum wages)
use `data', clear

*Creating a monthly date variables
gen monthly_date = mofd(date)
format monthly_date %tm

*Collapsing the data by the monthly date to get lowest, mean, and highest minimum wages for each month.
collapse (min) min_fed_mw = fed_mw min_mw = mw (mean) mean_fed_mw = fed_mw mean_mw = mw (max) max_fed_mw = fed_mw max_mw = mw, by(statefips statename stateabb monthly_date)

*Labeling variables
label var monthly_date "Monthly Date"
label var min_fed_mw "Monthly Federal Minimum"
label var min_mw "Monthly State Minimum"

label var mean_fed_mw "Monthly Federal Average"
label var mean_mw "Monthly State Average"

label var max_fed_mw "Monthly Federal Maximum"
label var max_mw "Monthly State Maximum"

*Exporting to Stata .dta file
sort stateabb monthly_date
compress
save ${exports}mw_state_monthly.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}mw_state_monthly.xlsx, replace firstrow(varlabels) datestring(%tm)

*EXPORTING A QUARTERLY DATASET WITH STATE MINIMUM WAGES, FEDERAL MININUMUM WAGES, and FINAL MINIMUM WAGE (based on the higher level between the state and federal minimum wages)
use `data', clear

*Creating a quarterly date variables
gen quarterly_date = qofd(date)
format quarterly_date %tq

*Collapsing the data by the quarterly date to get lowest, mean, and highest minimum wages for each month.
collapse (min) min_fed_mw = fed_mw min_mw = mw (mean) mean_fed_mw = fed_mw mean_mw = mw (max) max_fed_mw = fed_mw max_mw = mw, by(statefips statename stateabb quarterly_date)

*Labeling variables
label var quarterly_date "Quarterly Date"
label var min_fed_mw "Quarterly Federal Minimum"
label var min_mw "Quarterly State Minimum"

label var mean_fed_mw "Quarterly Federal Average"
label var mean_mw "Quarterly State Average"

label var max_fed_mw "Quarterly Federal Maximum"
label var max_mw "Quarterly State Maximum"

*Exporting to Stata .dta file
sort stateabb quarterly_date
compress
save ${exports}mw_state_quarterly.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}mw_state_quarterly.xlsx, replace firstrow(varlabels) datestring(%tq)

*EXPORTING A YEARLY DATASET WITH STATE MINIMUM WAGES, FEDERAL MININUMUM WAGES, and FINAL MINIMUM WAGE (based on the higher level between the state and federal minimum wages)
use `data', clear

*Creating a yearly date variables
gen year = yofd(date)
format year %ty

*Collapsing the data by the annual date to get lowest, mean, and highest minimum wages for each month.
collapse (min) min_fed_mw = fed_mw min_mw = mw (mean) mean_fed_mw = fed_mw mean_mw = mw (max) max_fed_mw = fed_mw max_mw = mw, by(statefips statename stateabb year)

*Labeling variables
label var year "Year"
label var min_fed_mw "Annual Federal Minimum"
label var min_mw "Annual State Minimum"

label var mean_fed_mw "Annual Federal Average"
label var mean_mw "Annual State Average"

label var max_fed_mw "Annual Federal Maximum"
label var max_mw "Annual State Maximum"

*Exporting to Stata .dta file
sort stateabb year
compress
save ${exports}mw_state_annual.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}mw_state_annual.xlsx, replace firstrow(varlabels) datestring(%ty)

* COMPRESS FILES FOR DISTRIBUTION
* state - Stata
!cp ${exports}mw_state*.dta .
zipfile mw_state_annual.dta mw_state_quarterly.dta mw_state_monthly.dta mw_state_daily.dta mw_state_changes.dta, saving(mw_state_stata.zip, replace)
!mv mw_state_stata.zip ${release}
rm mw_state_annual.dta
rm mw_state_quarterly.dta
rm mw_state_monthly.dta
rm mw_state_daily.dta
rm mw_state_changes.dta

* state - Excel
!cp ${exports}mw_state*.xlsx .
zipfile mw_state_annual.xlsx mw_state_quarterly.xlsx mw_state_monthly.xlsx mw_state_daily.xlsx mw_state_changes.xlsx, saving(mw_state_excel.zip, replace)
!mv mw_state_excel.zip ${release}
rm mw_state_annual.xlsx
rm mw_state_quarterly.xlsx
rm mw_state_monthly.xlsx
rm mw_state_daily.xlsx
rm mw_state_changes.xlsx
