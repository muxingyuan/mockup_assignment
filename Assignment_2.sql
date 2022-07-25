--20220719 Xingyuan

/*
problem met and solved during import:
1. cast Excel to general csv for safer import
2. REPORT_PERIOD, SIZE CLAIMED TO BE NUMBER but got error that character can not be converted to float, change type to varchar(50)
3. lookup blanks in each column in Excel/csv, finally confirm only REPORT_ID, REPORT_PERIOD is not null, other columns nullable
*/
use DBA_Config
; 

SELECT TOP (1000) *
  FROM [DBA_Config].[dbo].[MOCKUP]
  ;

  SELECT count(*)
  FROM [DBA_Config].[dbo].[MOCKUP]
  ;
  
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
 
select * from mockup
;

--Explorative Data Analysis
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
--NULL value will be treated as business meaning: same value as previous row
--blank value will be treated as business meaning: same value as previous row
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

select * from mockup
where id > 32000
;

--*****************************************
--observed there are about 10% of rows with test_no and serial no are null value, majority has null value for measure columns.
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
where serial_no is null or test_no = ''
;
--16877 rows affected
update mockup 
set serial_no_trim = 'no data'
where serial_no_trim is null or test_no = ''
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
--start_no: leave as is
--end_no: coelesce(end_len, total_len - start_len)
--total_no: coelesce(total_len, end_len - start_len)
--********************************************

--end of Explorative Data Analyis

--prepare for grouping

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

select * from mockup;

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


--step2: copy data into a new table mockup_1
--1. keep all existing columns
--2. order rows by report_id, report_period_trim
--3. set report_id, report_period_trim as primary key

--copy table structure
--take advantage of the behavior that when select into statement is used, primary key will not be copied to new table
select top 0 * into mockup_1 from mockup;
select * from mockup_1;
--set report_id, report_period_trim as primary key
alter table mockup_1
alter column report_period_trim int not null
;
go
alter table mockup_1 add constraint pk_report_id_period primary key (report_id, report_period_trim)
;
go
--insert into data
insert into mockup_1 
select * from mockup
order by report_id, report_period_trim
;

/*need to handle identity insert
https://www.sqlnethub.com/blog/set-identity_insert-command-sql-server/
SET IDENTITY_INSERT #myTable ON;
GO  
INSERT INTO #myTable ( id ,
                       code ,
                       descr )
VALUES ( 3, 'code3', 'descr3' );
GO
SET IDENTITY_INSERT #myTable OFF;
GO

*/

--make flags of whether report_id, test_no and serial_no is same value as previous record
alter table mockup add report_id_flag int, test_no_flag int, serial_no_flag int
;
go

