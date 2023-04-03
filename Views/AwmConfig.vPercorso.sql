SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE VIEW [AwmConfig].[vPercorso]
AS
SELECT		A.ResourceName,
			P.Descrizione,
			P.Direzione,
			P.Id_Percorso,
			UT.Codice_Udc,
			PSORG.DESCRIZIONE AS Sorgente,
			PDEST.DESCRIZIONE AS Destinazione,
			P.Sequenza_Percorso,
			TSP.Descrizione AS Stato,
			P.Id_Tipo_Stato_Percorso
			,DATEDIFF(SECOND,P.lastDateCmd,GETDATE()) runningSec
FROM		dbo.Percorso P INNER JOIN dbo.Missioni M ON M.Id_Missione = P.Id_Percorso
LEFT JOIN	dbo.Alarms A ON A.AlarmId = P.AlarmId
LEFT JOIN	dbo.Partizioni PSORG ON P.Id_Partizione_Sorgente = PSORG.ID_PARTIZIONE
LEFT JOIN	dbo.Partizioni PDEST ON P.Id_Partizione_Destinazione = PDEST.ID_PARTIZIONE
INNER JOIN	dbo.Tipo_Stato_Percorso TSP ON TSP.Id_Stato_Percorso = P.Id_Tipo_Stato_Percorso
INNER JOIN	dbo.Udc_Testata UT ON M.Id_Udc = UT.Id_Udc


-- WITH CHECK OPTION
GO
