SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW	[AwmConfig].[vAdiacenze]
as
SELECT	A.Id_Adiacenza
		,A.Id_Partizione_Sorgente
		,PS.DESCRIZIONE SORGENTE
		,A.Id_Partizione_Destinazione
		,PD.DESCRIZIONE DESTINAZIONE
		,A.Descrizione
		,A.Abilitazione
FROM	dbo.Adiacenze A
		INNER JOIN dbo.Partizioni PS ON PS.ID_PARTIZIONE = A.Id_Partizione_Sorgente
		INNER JOIN dbo.Partizioni PD ON PD.ID_PARTIZIONE = A.Id_Partizione_Destinazione
GO
