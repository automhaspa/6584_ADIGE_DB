SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[ParserJSON]
	(@XML_PARAM XML)
RETURNS VARCHAR(MAX)
AS
BEGIN
	DECLARE @MyHierarchy Hierarchy -- to pass the hierarchy table around
	insert into @MyHierarchy SELECT * from dbo.ParseXML((@XML_PARAM))
	RETURN (SELECT dbo.ToJSON(@MyHierarchy))
END


GO
