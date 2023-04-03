SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfigConfig].[vFilterTypes]
AS
SELECT ROW_NUMBER() OVER (ORDER BY ft.filterTypeName ASC) AS FilterType
, ft.filterTypeName AS Descrizione FROM AwmConfig.FilterType ft WHERE ft.filterTypeName <> 'TIPO_FILTRI_INPUT'
GO
