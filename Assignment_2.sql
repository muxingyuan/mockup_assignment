--20220719 Xingyuan

/*
problem met and solved during import:
1. cast Excel to general csv for safer import
2. REPORT_PERIOD, SIZE CLAIMED TO BE NUMBER but got error that character can not be converted to float, change type to varchar(50)
3. lookup blanks in each column in Excel/csv, finally confirm only REPORT_ID, REPORT_PERIOD is not null, other columns nullable
*/
use DBA_Config
; 
--20220803 audit
use DB1;

SELECT TOP (1000) *
  FROM [DBA_Config].[dbo].[MOCKUP]
  ;

  SELECT count(*)
  FROM [DBA_Config].[dbo].[MOCKUP]
  ;
  --129358

Alter Table MOCKUP 
add ID int identity(1,1) primary key
;
Go

create index ind_PERIOD ON MOCKUP (REPORT_PERIOD)
;
GO

-- AS cleaning and munipulation goes, might give dummy value to null to create more index

--20220723 xingyuan

use DBA_Config
;
 
SELECT TOP (1000) *
  FROM [DBA_Config].[dbo].[MOCKUP]
  ;

--**************************************************
--Explorative Data Analysis and Data Pre-processing
--****************************************************
dbcc show_statistics (mockup, ind_period) with histogram
;

--report_id
select report_id, min(report_period), max(report_period), count(distinct report_period), count(*) from mockup
group by report_id
order by report_id
;

--report_period
select report_period,  count(*) from mockup
group by report_period
order by count(*) desc
;

select cast(report_period as int) from mockup
group by cast(report_period as int)
order by cast(report_period as int)
;

--test_no
--create test_no_trim as striping nonAlphaNumeric characters off test_no
select test_no, count(*) from mockup
group by test_no
order by test_no
;

select max(len(test_no))
from mockup
;

Create Function [dbo].[RemoveNonAlphaNumericCharacters](@Temp VarChar(17))
Returns VarChar(17)
AS
Begin

    Declare @KeepValues as varchar(50)
    Set @KeepValues = '%[^a-z0-9]%'
    While PatIndex(@KeepValues, @Temp) > 0
        Set @Temp = Stuff(@Temp, PatIndex(@KeepValues, @Temp), 1, '')

    Return @Temp
End
go

--Test Function
select dbo.RemoveNonAlphaNumericCharacters('!g*9')
;

alter table mockup add test_no_trim varchar(50)
;
go

update mockup 
set test_no_trim=dbo.RemoveNonAlphaNumericCharacters(test_no)
;
--5 seconds used

select test_no_trim, count(*) from mockup
group by test_no_trim
order by test_no_trim
;

select test_no_trim, count(*) from mockup
group by test_no_trim
order by count(*) desc
;


select max(len(test_no_trim))
from mockup
;

select len(test_no), test_no, test_no_trim
from mockup
where len(test_no) > 12
order by len(test_no) desc
;

--*************************
--report to client: test_no column is dirty
--none-alphanumeric characters are stripped out for analysis purpose
--***************************

select * from mockup
where TEST_NO is null
;

select 'report_period=1 and test_no is null', count(*) from mockup 
where report_period = 1 and test_no is null
union 
select 'all rows', count(*) from mockup
;

select 'report_period=1 and test_no is null', count(*) from mockup 
where report_period = 2 and test_no is null
union 
select 'all rows', count(*) from mockup
;

select * from mockup 
where test_no is null and SERIAL_NO is null
;
--14407 rows

select * from mockup
where id > 32000
;

--*****************************************
--observed there are about 10% of rows with test_no and serial no are null value, 
--majority has null value for measure columns.
--since 10% quantity is major, tentatively populate all text type column null value as 'no data', 
--numeric column null value as 0.
--*****************************************

update mockup 
set test_no_trim = 'no data'
where test_no is null or test_no = ''
;
--14673 rows affected

update mockup 
set test_no_trim = 'no data'
where test_no_trim is null or test_no = ''
;
--0 rows affected

--serial_no
--do same cleanup for serial_no as done to test_no
select serial_no, count(*) from mockup
group by serial_no
order by count(*) desc
;

alter table mockup add serial_no_trim varchar(50)
;
go

update mockup 
set serial_no_trim=dbo.RemoveNonAlphaNumericCharacters(serial_no)
;
--4 seconds used

select serial_no_trim, count(*) from mockup
group by serial_no_trim
order by count(*) desc
;

update mockup 
set serial_no_trim = 'no data'
where serial_no is null or serial_no = ''
;
--16877 rows affected

update mockup 
set serial_no_trim = 'no data'
where serial_no_trim is null or serial_no = ''
;
--0 rows affected

--size
select size, count(*) from mockup
group by size
order by size
;

select size, count(*) from mockup
group by size
order by count(*) desc
;
--null: 14739 rows

--when size is null, often time test_no, serial_no is null
select count(*)
from MOCKUP
where size is null and test_no is null and serial_no is null
;
--14368 rows

select SERIAL_NO, count(distinct size)
from mockup
group by SERIAL_NO
order by count(distinct size) desc
;
--*********************************************
--in most cases, cardinality size vs serial_no is 1, which make sense.
--since size is not required as aggregated upon column, leave it as is.
--**********************************************

--type
select type, count(*) from mockup
group by type
order by type
;

select size, count(*) from mockup
group by size
order by count(*) desc
;
--null: 14739 rows

--when type is null, often time test_no, serial_no is null
select count(*)
from MOCKUP
where type is null and test_no is null and serial_no is null
;
--14382 rows

select SERIAL_NO, count(distinct type)
from mockup
group by SERIAL_NO
order by count(distinct type) desc
;
--*********************************************
--in most cases (90%), cardinality type vs serial_no is 1, which make sense.
--since size is not required as aggregated upon column, leave it as is.
--**********************************************

-- start_len, end_len, total_len
select count(*)
from mockup
where START_LEN is null or END_LEN is null or TOTAL_LEN is null
;
--90355

select count(*)
from mockup
where START_LEN is null
; 
--17598

select count(*)
from mockup
where END_LEN is null 
;
--88494

select count(*)
from mockup
where TOTAL_LEN is null
;
--35343

select diff, count(*) from (
select (end_len - start_len) - total_len as diff
from mockup) t1
group by t1.diff
order by count(*) desc
;

--******************************************
--leave start_no, end_no, total_no untouched, during aggregation, can use below methods to collect measure values:
--start_no: use it directly
--end_no: coelesce(end_len, total_len - start_len)
--total_no: coelesce(total_len, end_len - start_len)
--********************************************


--**************************************************
--End of Explorative Data Analysis and Data Pre-processing
--****************************************************

--*******************************
--prepare for grouping
--********************************

--step1: handle Report_Period column
--validate within each report_id sequential rows, report_period is ascending
SELECT T1.REPORT_ID, SUM(VALIDATION) 
FROM
(select REPORT_ID, case when lag(report_period) over (partition by report_id order by REPORT_PERIOD) is null then 1 
ELSE (CASE when cast(REPORT_period AS int) = cast(lag(REPORT_period) over (partition by REPORT_id order by REPORT_PERIOD) AS int) + 1 then 0
else 1
end ) 
END as validation
from MOCKUP) T1
GROUP BY T1.REPORT_ID
ORDER BY SUM(VALIDATION) DESC
;
--that is not true

--cast report_period to integer for easy manipulation.
--first valid report_period is all numeric characters
SELECT * FROM MOCKUP
WHERE PATINDEX('[a-z]', REPORT_PERIOD) > 0
;
--returns 0 rows, meaning validated

--cast column to report_period_trim
alter table mockup add report_period_trim int
;
go

update mockup 
set report_period_trim = cast(report_period as int)
;
--use 7 seconds

select top 100 * from mockup;

SELECT T1.REPORT_ID, SUM(VALIDATION) 
FROM
(select REPORT_ID, case when lag(report_period_trim) over (partition by report_id order by REPORT_PERIOD_trim) is null then 1 
ELSE (CASE when REPORT_period_trim = lag(REPORT_period_trim) over (partition by REPORT_id order by REPORT_PERIOD_trim)  + 1 then 0
else 1
end ) 
END as validation
from MOCKUP) T1
GROUP BY T1.REPORT_ID
ORDER BY SUM(VALIDATION) DESC
;

--412228
--86219
select * from mockup where report_id in ('412228');
--there is only 2 exceptions out of 6000+ report_id,
--majority of report_id have rows with continuous integer as report_period


--step2: copy data into a new table mockup_2
--1. keep all existing columns
--2. order rows by report_id, report_period_trim
--3. because of order rows by these 2 columns, value of id column for each row will change after insert into,
-- therefore drop ID column and create id_new column, make id_new column as identity and primary key. 

--copy table structure
--take advantage of the behavior that when select into statement is used, primary key will not be copied to new table
select top 0 * into mockup_2 from mockup;
select * from mockup_2;

alter table mockup_2
drop column id
;
go

alter table mockup_2
add id_new int identity primary key
;
go

--insert into data, except for ID column
insert into mockup_2 ([REPORT_ID]
      ,[REPORT_PERIOD]
      ,[TEST_NO]
      ,[SERIAL_NO]
      ,[SIZE]
      ,[TYPE]
      ,[START_LEN]
      ,[END_LEN]
      ,[TOTAL_LEN]
      ,[test_no_trim]
      ,[serial_no_trim]
      ,[report_period_trim]
     )
select [REPORT_ID]
      ,[REPORT_PERIOD]
      ,[TEST_NO]
      ,[SERIAL_NO]
      ,[SIZE]
      ,[TYPE]
      ,[START_LEN]
      ,[END_LEN]
      ,[TOTAL_LEN]
      ,[test_no_trim]
      ,[serial_no_trim]
      ,[report_period_trim]
      from mockup
order by report_id, report_period_trim
;
--9 seconds


--step3: 
-- 1. use lag() function to group rows, use condition statement to reserve measure values
-- 2. pull starting row of each smallest group to another table called mockup_2_summary
-- smallest group happens when test_no is new start or when serial_no is new start
with cte as (
select id_new,
[REPORT_ID]
      --,[REPORT_PERIOD]
      ,[report_period_trim]
      ,lag(report_period_trim) over (order by id_new) as report_period_trim_lag
      ,[SIZE]
      ,[TYPE]
      ,[START_LEN]
      ,[END_LEN]
      ,[TOTAL_LEN]
      ,[test_no_trim]
      ,[serial_no_trim]
,  case when lag(test_no_trim) over (partition by report_id order by report_period_trim) is null then 0 
else (case when lag(test_no_trim) over (partition by report_id order by report_period_trim) <> test_no_trim then 0
else 1 end) end as test_no_group_flag
,  case when lag(serial_no_trim) over (partition by report_id order by report_period_trim) is null then 0 
else (case when lag(serial_no_trim) over (partition by report_id order by report_period_trim) like '%'+serial_no_trim+'%'
or serial_no_trim like '%'+lag(serial_no_trim) over (partition by report_id order by report_period_trim)+'%'
then 1 else 0 end) end as serial_no_group_flag
,lag(end_len) over (partition by report_id order by report_period_trim) as end_len_lag
,lag(total_len) over (partition by report_id order by report_period_trim) as total_len_lag
from mockup_2
)
select id_new, REPORT_ID, report_period_trim, report_period_trim_lag,test_no_trim, serial_no_trim, 
size, [type],
start_len, 
coalesce(end_len_lag, start_len + total_len_lag) as end_len,
coalesce(total_len_lag, end_len_lag - start_len) as total_len
into mockup_2_summary
from cte
where test_no_group_flag + serial_no_group_flag < 2
order by id_new
;
--8 seconds

select * from mockup_2
where report_id = '1000489'
order by id_new
;

select count(*) from mockup_2_summary;
select count(*) from mockup_2;
--33491 rows
--129358 rows

--step4: use materialized mockup_2_summary to finalize the aggregation report
--0. validate mockup_2_summary is in id_new ascending order, which is the same as report_id, report_period_trim compound ascending order
--1. Min Period takes report_period_trim value on current row;
--2. Max Period takes report_period_trim_lag value from next row;
--3. test_no takes test_no_trim value on current row;
--4. serial_no takes serial_no_trim value on current row as a representation of the matching serial numbers;
--5. Start_len takes start_len on current row;
--6. End_len takes end_len from next row;
--7. Total_len takes total_len from next row.

--0. validation
select * from mockup_2_summary
order by id_new desc
;

select report_id, report_period_trim, lag(report_period_trim) over (order by id_new desc) from mockup_2_summary
order by id_new desc
;

select sum(t1.validation) from
(select case when report_period_trim > lag(report_period_trim) over (order by id_new) then 0 else 1 end as validation
from mockup_2_summary
) t1
;
--6037

select count(distinct REPORT_ID) from mockup_2_summary
;
--6042
--6037 < 6042, assumption validated

select sum(t1.validation) from
(select case when report_id > lag(report_id) over (order by id_new) then 1 else 0 end as validation
from mockup_2_summary
) t1
;
--6041 = 6042 - 1 null, assumption validated

select count(distinct REPORT_ID) from mockup_2_summary
;
--6042

--make aggregation report
select report_id, test_no_trim, serial_no_trim, report_period_trim as Min_Report_Period,
lag(report_period_trim_lag) over (order by id_new desc) as Max_Report_Period,
size, [type],
START_LEN as min_start_len, 
lag(end_len) over (order by id_new desc) as max_end_len, 
lag(total_len) over (order by id_new desc) as total_len_worked
from mockup_2_summary
order by id_new
;
--2 seconds
--33491 rows