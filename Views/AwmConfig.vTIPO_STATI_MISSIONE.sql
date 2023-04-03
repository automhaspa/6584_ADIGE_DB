SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO









CREATE VIEW [AwmConfig].[vTIPO_STATI_MISSIONE]
AS
	SELECT	tsm.Id_Stato_Missione
			,tsm.Descrizione
	FROM	dbo.Tipo_Stato_Missioni AS tsm
	WHERE	tsm.Id_Stato_Missione IN ('NEW','ELA','ESE')

GO
