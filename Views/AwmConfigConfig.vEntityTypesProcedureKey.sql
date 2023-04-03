SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
--Views
CREATE VIEW	[AwmConfigConfig].[vEntityTypesProcedureKey]
AS
SELECT et.entityTypeName, ah.ProcedureKey  FROM AwmConfig.entityType et INNER JOIN AwmConfig.ActionHeader ah ON et.hash = ah.hash
WHERE entityTypeName <> 'vEntityTypes'
GO
