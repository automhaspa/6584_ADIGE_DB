SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO












CREATE VIEW [AwmConfig].[vTIPO_PARTIZIONI]
AS
	SELECT	Tipo_Partizioni.Id_Tipo_Partizione
			,Descrizione			
	FROM	(SELECT DISTINCT ID_TIPO_PARTIZIONE FROM dbo.Partizioni) T
			INNER JOIN dbo.Tipo_Partizioni ON Tipo_Partizioni.ID_TIPO_PARTIZIONE = T.ID_TIPO_PARTIZIONE
	WHERE	T.ID_TIPO_PARTIZIONE <> 'OO'
GO
