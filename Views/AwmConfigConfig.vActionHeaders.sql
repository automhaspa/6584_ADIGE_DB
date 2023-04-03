SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfigConfig].[vActionHeaders] AS
SELECT ah.hash, ah.ProcedureKey, ah.ProcedureName,  ah.CSS, ah.DisplayOrder,  ah.ConfResource FROM AwmConfig.ActionHeader ah
GO
