# Tech Challenge Submission

This is a solution to [this challenge](https://docs.google.com/document/d/1eb8bW6h3ihlm_tngrZybCcdhDoH5z5wmMHoGtndDR3w/edit?usp=sharing). The solution was written in vanilla Ruby and tested with RSpec.

## Assumptions

- This solution will assume the data parsed will be in NEM12 format since the NEM13 format is for a scenario where the meter data is accumulated, which is irrelevant considering this solution assumed that the SQL stores individual meter readings records.
- Since the sample data given is buggy, I've used the reference data file instead of the test data.
- I assumed that the interval value unit that we stored in the DB will ** all be in kWh** since the given database schema doesn't provide additional info for the `consumption` value unit. If the data given is not in kWh, we'll ignore it. This assumption was made after my research that proves that the kWh is a measuring unit for the "active" consumption of electricity.
- If the value given is in Wh or MWh, the solution will convert it to kWh format.
- I assumed that the interval length is mandatory, based on the reference documentation
- If the same NMI data has multiple export interval values and it was recorded on the same day, I assumed that the data will be summed together
- If the 200 records provided import interval data (i.e. any NMI Suffix that's not `E1` or `E2`), I assumed that it's irrelevant data because it's not an active consumption data

## Usage

- I've provided some sample data in the `fixtures` folder in this repo. Please feel free to use it to test the solution. These sample data are all taken from the reference documentation.
- I've also provided some rspec tests to validate my solution.
- Practically this is how you will run the solution
  ```
  csv_file = File.read("sample.csv") # create or prepare this CSV file first
  statements = MeterReader.new('fixtures/sample1.csv').call
  p statements # to show the generated SQL statements
  ```
  
## Facts based on the given sample data

### 100 record

- This is a NEM12 data format
- The file was created at 08/06/2005 11:49 AM by the participant "UNITEDDP" and the data is for "NEMMCO"

### 200 record

- This file has a single NMI record => "NEM1201009"
- The meter serial number is - "01009"
- The meter is registering the interval metering data in "kWh" unit
- The interval length for this data is 30 mins

### 300 record

- There are discrepancies in the data because it doesn't give 48 interval metering values. (`1440 / 30 mins interval = 48 values`)
- The quality method, reason code, and reason description are not given.
- Assumed that these 300 records are invalid. Because of the above pointers, this submission will use a different sample data as per the [referred documentation](https://aemo.com.au/-/media/files/electricity/nem/retail_and_metering/market_settlement_and_transfer_solutions/2022/mdff-specification-nem12-nem13-v25.pdf?la=en) instead

### 400 record

- There are no 400 records in this data.

### 500 record

- This data is manually read on the 10/03/2005 at 21:04.

### 900 record

- This means the data is a complete set.
