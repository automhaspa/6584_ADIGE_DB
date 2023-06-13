SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vTIPO_MISSIONI]
AS
	SELECT	Id_Tipo_Missione,
			Descrizione
	FROM	dbo.Tipo_Missioni
	WHERE	Id_Tipo_Missione IN ('RCS','OUL','OUT','ING','OUP','MTM','COM','SPC','OUM','INT','CQL')

GO
