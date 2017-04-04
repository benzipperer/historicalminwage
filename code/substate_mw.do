*TITLE: SUBSTATE MINIMUM WAGES, Expanding the VZ Daily Minimum Wage Changes File
*Date Created: 07.01.2016
*Date Edited: 07.16.2016

*Description: This .do file expands the VZ daily minimum wage changes by city/locality file.
*IT REQUIRES the state-level minimum wage output of state_mw.do.

set more off
clear all

*SETTING GLOBAL DIRECTORIES
* You will need to change the $home directory to an appropriate value.
global home "/home/bzipperer/projects/VZ_historicalminwage/"
global raw "${home}rawdata/"
global exports "${home}exports/"
global release "${home}release/"

local substate "VZ_SubstateMinimumWage_Changes"
local finaldate 31mar2017


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
*Loading in the VZ substate minimum wage data
import excel using ${raw}`substate'.xlsx, clear firstrow

*Creating a daily date variable
gen date = mdy(month,day,year)
format date %td

*note: Stata loads the minimum wage variables as float, so here, we are adjusting them to double to optimize Excel exports
gen double mw = round(VZ_mw, .01)
gen double mw_tipped = round(VZ_mw_tipped, .01)
gen double mw_healthinsurance = round(VZ_mw_healthinsurance, .01)
gen double mw_smallbusiness = round(VZ_mw_smallbusiness, .01)
gen double mw_smallbusiness_mincomp = round(VZ_mw_smallbusiness_mincompensat, .01)
gen double mw_hotel = round(VZ_mw_hotel, .01)
drop VZ_mw*

*Labeling variables
merge m:1 statefips using `crosswalk', nogen keep(3)
label var statefips "State FIPS Code"
label var statename "State"
label var stateabb "State Abbreviation"
label var locality "City/County"
label var mw "Minimum Wage"
order statefips statename stateabb locality year month day date mw mw_* source source_2 source_notes

*Exporting to Stata .dta file
sort locality date
save ${exports}VZ_substate_changes.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}VZ_substate_changes.xlsx, replace firstrow(varlabels) datestring(%td)

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
use ${exports}VZ_state_daily.dta, clear
keep if year(date) >= `minyear' & date <= td(`finaldate')
joinby statefips using `localities'
keep statefips statename stateabb locality date mw
rename mw state_mw
tempfile statemw
save `statemw'
restore

*Creating a "non-string" counter variable based on the locality so that we can use the tsfill function
encode locality, gen(locality_temp)

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
gen abovestate = mw > state_mw
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
save ${exports}VZ_substate_daily.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}VZ_substate_daily.xlsx, replace firstrow(varlabels) datestring(%td)

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
save ${exports}VZ_substate_monthly.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}VZ_substate_monthly.xlsx, replace firstrow(varlabels) datestring(%tm)

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
save ${exports}VZ_substate_quarterly.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}VZ_substate_quarterly.xlsx, replace firstrow(varlabels) datestring(%tq)

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
save ${exports}VZ_substate_annual.dta, replace

*Exporting to excel spreadsheet format
export excel using ${exports}VZ_substate_annual.xlsx, replace firstrow(varlabels) datestring(%ty)

* COMPRESS FILES FOR DISTRIBUTION
* Substate - Stata
!cp ${exports}VZ_substate*.dta .
zipfile VZ_substate_annual.dta VZ_substate_quarterly.dta VZ_substate_monthly.dta VZ_substate_daily.dta VZ_substate_changes.dta, saving(VZ_substate_stata.zip, replace)
!mv VZ_substate_stata.zip ${release}
rm VZ_substate_annual.dta
rm VZ_substate_quarterly.dta
rm VZ_substate_monthly.dta
rm VZ_substate_daily.dta
rm VZ_substate_changes.dta

* Substate - Excel
!cp ${exports}VZ_substate*.xlsx .
zipfile VZ_substate_annual.xlsx VZ_substate_quarterly.xlsx VZ_substate_monthly.xlsx VZ_substate_daily.xlsx VZ_substate_changes.xlsx, saving(VZ_substate_excel.zip, replace)
!mv VZ_substate_excel.zip ${release}
rm VZ_substate_annual.xlsx
rm VZ_substate_quarterly.xlsx
rm VZ_substate_monthly.xlsx
rm VZ_substate_daily.xlsx
rm VZ_substate_changes.xlsx
