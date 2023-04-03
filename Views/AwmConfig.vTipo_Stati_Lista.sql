SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [AwmConfig].[vTipo_Stati_Lista]
AS
	SELECT	Id_Stato_Lista,
			Descrizione
	FROM	Tipo_Stati_Lista
	WHERE	Id_Stato_Lista IN (1,3,6)
GO
