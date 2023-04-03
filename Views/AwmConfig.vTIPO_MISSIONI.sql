SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vTIPO_MISSIONI]
AS
	SELECT	tm.Id_Tipo_Missione
			,tm.Descrizione
	FROM	dbo.Tipo_Missioni AS tm
	WHERE tm.Id_Tipo_Missione IN('RCS','OUL','OUT','ING','REF','OUP')

GO
