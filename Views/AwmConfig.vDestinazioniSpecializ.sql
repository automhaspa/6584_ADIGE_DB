SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vDestinazioniSpecializ]
AS
	SELECT	ID_PARTIZIONE
			DESCRIZIONE
	FROM	dbo.Partizioni
	WHERE	ID_TIPO_PARTIZIONE = 'SP'
		OR	ID_PARTIZIONE = 3501
GO
