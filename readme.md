# Flo Energy Tech Interview Submission

## Facts on sample data

### 100 record

- This is a NEM12 data format
- The file is created at 08/06/2005 11:49 AM by the participant "UNITEDDP" and the data is for "NEMMCO"

### 200 record

- This file has a single NMI record => "NEM1201009"
- The meter serial number is - "01009"
- The meter is registering the interval metering data in "kWh" unit
- The interval length for this data is 30 mins

### 300 record

- There are discrepancies on the data because it doesn't give 48 interval metering value. (`1440 / 30 mins interval = 48 values`)
- The quality method, reason code and reason description is not given.
- Assumed that these 300 records are invalid. Because the above pointers. However, assumed that the missing interval value is 0 somehow.
- On the data sample given, on the line 9
  `300,20050301,0,0,0,0,0,0,0,0,0,0,0,0,0.154,0.460,0.770,1.003,1.059,1.750,1.423,1.200,0 0050310121004,`.

  It is assumed that the last column is supposed to be the `UpdateDateTime` but the DateTime format is wrong. It's supposed to be `20050310121004` instead, It's also missing the last column.

  I've made an update to the sample data instead here (TODO).

### 400 record

- There are no 400 record in this data.

### 500 record

- This data is manually read on the 10/03/2005 at 21:04.

### 900 record

- This means the data is a complete set.

## Assumptions

- This solution will assume the data parsed will be in NEM12 format, since the NEM13 format is for a scenario where the meter data is accumulated, which is not relevant considering the SQL table is storing individual meter readings records.
- Since the sample data given is buggy, I've used the data given in the reference file instead as test data.
- I assumed that that the interval value unit that we're stored in the DB will all be in kWh since the given database schema doesn't provide additional info for the `consumption` value unit. If the data given is not in kWh, we'll ignore it.
