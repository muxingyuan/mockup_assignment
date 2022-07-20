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

