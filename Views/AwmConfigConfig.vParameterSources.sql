SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW	[AwmConfigConfig].[vParameterSources]
AS
SELECT Source, WidgetName FROM AwmConfig.ActionParameterSources WHERE Source <> 'vParameterSources' AND Source <> 'vEntityType'
GO
