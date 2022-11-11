*TITLE: SUBSTATE MINIMUM WAGES, Expanding the daily Minimum Wage Changes File

*Description: This .do file expands the daily minimum wage changes by city/locality file.
*IT REQUIRES the state-level minimum wage output of state_mw.do.

set more off
clear all

*SETTING GLOBAL DIRECTORIES
* You will need to change the $home directory to an appropriate value.
global home `c(pwd)'/../
global raw ${home}rawdata/
global exports ${home}exports/
global release ${home}release/

local substate "SubstateMinimumWage_Changes"
local finaldate 31dec2022


*IMPORTING A CROSSWALK FOR FIPS CODES, STATE NAMES, AND STATE ABBREVIATIONS
*Importing and "loading in" the crosswalk
import excel using ${raw}FIPS_crosswalk.xlsx, clear firstrow
*Renaming variables
rename Name statename
rename FIPSStateNumericCode statefips
rename OfficialUSPSCode stateabb
replace stateabb = upper(stateabb)
keep statename statefips stateabb
*Saving crosswalk as a temporary file
tempfile crosswalk
save `crosswalk'

*PREPARING THE SUBSTATE MINIMUM WAGE CHANGES FILE
*Loading in the substate minimum wage data
import excel using ${raw}`substate'.xlsx, clear firstrow

*Creating a daily date variable
gen date = mdy(month,day,year)
format date %td

*note: Stata loads the minimum wage variables as float, so here, we are adjusting them to double to optimize Excel exports
replace mw = round(mw, .01)
replace mw_tipped = round(mw_tipped, .01)
replace mw_healthinsurance = round(mw_healthinsurance, .01)
replace mw_smallbusiness = round(mw_smallbusiness, .01)
replace mw_smallbusiness_mincomp = round(mw_smallbusiness_mincompensat, .01)
replace mw_hotel = round(mw_hotel, .01)

*Labeling variables
merge m:1 statefips using `crosswalk', nogen keep(3)
label var statefips "State FIPS Code"
label var statename "State"
label var stateabb "State Abbreviation"
label var locality "City/County"
label var mw "Minimum Wage"
order statefips statename stateabb locality year month day date mw mw_* source source_2 source_notes
keep statefips statename stateabb locality year month day date mw mw_* source source_2 source_notes

*Exporting to Stata .dta file
sort locality date
compress
save ${exports}mw_substate_changes.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}mw_substate_changes.xlsx, replace firstrow(varlabels) datestring(%td)

* populate the first of the year for the initial mw, if it doesn't exist already
preserve
egen tag = tag(statefips locality)
keep if tag == 1
keep statefips locality
tempfile localities
save `localities'
restore

sum year
local minyear = r(min)
preserve
use ${exports}mw_state_daily.dta, clear
keep if year(date) >= `minyear' & date <= td(`finaldate')
joinby statefips using `localities'
keep statefips statename stateabb locality date mw
rename mw state_mw
tempfile statemw
save `statemw'
restore

*Creating a "non-string" counter variable based on the locality so that we can use the tsfill function
egen locality_temp = group(statefips locality)

*Expanding the date variable
tsset locality_temp date
tsfill

*Filling in the missing parts of the data
foreach x of varlist statename stateabb locality source_notes {
  bysort locality_temp (date): replace `x' = `x'[_n-1] if `x' == ""
}
foreach x of varlist statefips mw* {
  bysort locality_temp (date): replace `x' = `x'[_n-1] if `x' == .
}

* ONLY USE UP-TO-CURRENT DATA
keep if date <= td(`finaldate')

* fill in earlier dates to complete balanced panel
merge 1:m statefips locality date using `statemw', assert(2 3) nogenerate
replace mw = state_mw if mw == .
replace mw = round(mw,0.01)
gen abovestate = mw > round(state_mw,0.01)
label var abovestate "Local > State min wage"


*Renaming and Labeling variables
keep statefips statename stateabb date locality mw mw_* abovestate source_notes
order statefips statename stateabb date locality mw mw_* abovestate source_notes
notes mw: The mw variable represents the most applicable minimum wage across the locality.

*Saving a temporary file
tempfile data
save `data'


*EXPORTING A DAILY DATASET WITH STATE MINIMUM WAGES, FEDERAL MININUMUM WAGES, and VZ's FINAL MINIMUM WAGE (based on the higher level between the state and federal minimum wages)
use `data', clear

*Exporting to Stata .dta file
sort locality date
compress
save ${exports}mw_substate_daily.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}mw_substate_daily.xlsx, replace firstrow(varlabels) datestring(%td)

*EXPORTING A MONTHLY DATASET WITH SUBSTATE MINIMUM WAGE
use `data', clear

*Creating a monthly date variables
gen monthly_date = mofd(date)
format monthly_date %tm

*Collapsing the data by the monthly date to get lowest, mean, and highest minimum wages for each month.
collapse (min) min_mw = mw (mean) mean_mw = mw (max) max_mw = mw abovestate, by(statefips statename stateabb locality monthly_date)

*Labeling variables
label var monthly_date "Monthly Date"
label var min_mw "Monthly Minimum"
label var mean_mw "Monthly Average"
label var max_mw "Monthly Maximum"
label var abovestate "Local > State min wage"

*Exporting to Stata .dta file
sort locality monthly_date
compress
save ${exports}mw_substate_monthly.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}mw_substate_monthly.xlsx, replace firstrow(varlabels) datestring(%tm)

*EXPORTING A QUARTERLY DATASET WITH SUBSTATE MINIMUM WAGE
use `data', clear

*Creating a quarterly date variables
gen quarterly_date = qofd(date)
format quarterly_date %tq

*Collapsing the data by the quarterly date to get lowest, mean, and highest minimum wages for each month.
collapse (min) min_mw = mw (mean) mean_mw = mw (max) max_mw = mw abovestate, by(statefips statename stateabb locality quarterly_date)

*Labeling variables
label var quarterly_date "Quarterly Date"
label var min_mw "Quarterly Minimum"
label var mean_mw "Quarterly Average"
label var max_mw "Quarterly Maximum"
label var abovestate "Local > State min wage"


*Exporting to Stata .dta file
sort locality quarterly_date
compress
save ${exports}mw_substate_quarterly.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}mw_substate_quarterly.xlsx, replace firstrow(varlabels) datestring(%tq)

*EXPORTING A YEARLY DATASET WITH STATE MINIMUM WAGES, FEDERAL MININUMUM WAGES, and VZ's FINAL MINIMUM WAGE (based on the higher level between the state and federal minimum wages)
use `data', clear

*Creating a yearly date variables
gen year = yofd(date)
format year %ty

*Collapsing the data by the annual date to get lowest, mean, and highest minimum wages for each month.
collapse (min) min_mw = mw (mean) mean_mw = mw (max) max_mw = mw abovestate, by(statefips statename stateabb locality year)

*Labeling variables
label var year "Year"
label var min_mw "Annual Minimum"
label var mean_mw "Annual Average"
label var max_mw "Annual Maximum"
label var abovestate "Local > State min wage"

*Exporting to Stata .dta file
sort locality year
compress
save ${exports}mw_substate_annual.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}mw_substate_annual.xlsx, replace firstrow(varlabels) datestring(%ty)

* COMPRESS FILES FOR DISTRIBUTION
* Substate - Stata
!cp ${exports}mw_substate*.dta .
zipfile mw_substate_annual.dta mw_substate_quarterly.dta mw_substate_monthly.dta mw_substate_daily.dta mw_substate_changes.dta, saving(mw_substate_stata.zip, replace)
!mv mw_substate_stata.zip ${release}
rm mw_substate_annual.dta
rm mw_substate_quarterly.dta
rm mw_substate_monthly.dta
rm mw_substate_daily.dta
rm mw_substate_changes.dta

* Substate - Excel
!cp ${exports}mw_substate*.xlsx .
zipfile mw_substate_annual.xlsx mw_substate_quarterly.xlsx mw_substate_monthly.xlsx mw_substate_daily.xlsx mw_substate_changes.xlsx, saving(mw_substate_excel.zip, replace)
!mv mw_substate_excel.zip ${release}
rm mw_substate_annual.xlsx
rm mw_substate_quarterly.xlsx
rm mw_substate_monthly.xlsx
rm mw_substate_daily.xlsx
rm mw_substate_changes.xlsx
