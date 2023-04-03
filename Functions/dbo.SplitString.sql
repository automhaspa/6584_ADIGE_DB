SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[SplitString] (@s VARCHAR(MAX), @sep CHAR(1))
RETURNS TABLE
AS
-- SplitString function created by Steve Stedman
RETURN (
WITH splitter_cte AS
(
  SELECT CHARINDEX(@sep, @s) AS pos, CAST(0 AS BIGINT) AS lastPos
  UNION ALL
  SELECT CHARINDEX(@sep, @s, pos + 1), pos
  FROM splitter_cte
  WHERE pos > 0
)
, splitter2_cte AS
(
  SELECT LTRIM(RTRIM(SUBSTRING(@s, lastPos + 1,
  CASE WHEN pos = 0 THEN 80000000000
  ELSE pos - lastPos -1 END))) AS chunk
  FROM splitter_cte
)
SELECT	ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) Passo
		,chunk AS chunk
  FROM splitter2_cte
 WHERE NULLIF(chunk, '') IS NOT NULL
)
GO
