# State and sub-state historical minimum wage data
The latest [release](releases/) contains data through March 31, 2017, as
Excel .xlsx spreadsheets or Stata .dta files, along with .pdf files of the
sources for all of the historical changes.

## Documentation
This replication package contains the Stata code and raw
spreadsheets needed to create state-level and sub-state-level
minimum wage datasets.

The original release of this data is described in Vaghul and Zipperer (2016),
available [here](http://equitablegrowth.org/working-papers/historical-state-and-sub-state-minimum-wage-data/).

## Contents of code/
Run the following do-files to create the state and substate-level extracts.
Your working directory should contain the do-files and mirror the directory
structure in the global macros at the top of the do-files. Running the code
will update and replace the contents of the exports/ and release/ folders.

* state_mw.do - creates a state-level data
* substate_mw.do - creates substate-level data (requires output of state_mw.do)

## Contents of rawdata/
The do-files require the following spreadsheets:

* SubstateMinimumWage_Changes.xlsx - substate-level changes
* StateMinimumWage_Changes.xlsx - state-level changes
* FederalMinimumWage_Changes.xlsx - federal changes
* FIPS_crosswalk.xlsx - state geography
