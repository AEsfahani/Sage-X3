-- Alter the reference to the PRODUCTION folder below to the name of your folder

SELECT 
	TBL_0, 
	COUNT(TBL_0) TableCount, 
	EVT_0, 
	COUNT(EVT_0) EventTypeCount
FROM PRODUCTION.AUDITH
GROUP BY TBL_0, EVT_0
ORDER BY COUNT(TBL_0) DESC, COUNT(EVT_0) DESC
