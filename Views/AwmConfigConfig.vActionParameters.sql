SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW	[AwmConfigConfig].[vActionParameters]
AS SELECT ap.hash, ap.ProcedureKey, ap.ParameterName, ap.ParameterSource, ap.ParameterValue, ap.DisplayOrder,
ap.directValidated, ap.resourceName, ap.validationModule, ap.out
FROM AwmConfig.ActionParameter ap
GO
