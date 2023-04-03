SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfigConfig].[vEntityTypes] AS
SELECT et.entityTypeName, et.hash FROM AwmConfig.entityType et
GO
