SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW [AwmConfig].[vMissioni]
AS

SELECT		M.Id_Partizione_Destinazione,
			M.Id_Partizione_Sorgente,
			M.Id_Stato_Missione,
			M.Id_Tipo_Missione,
			M.Id_Udc,
			M.Id_Missione,
			UT.Codice_Udc,
			P.DESCRIZIONE AS CURRENT_POS,
			TM.Descrizione AS TipoMissione,
			PSORG.DESCRIZIONE AS Sorgente,
			PDEST.DESCRIZIONE AS Destinazione,
			TSM.Descrizione AS Stato,
			TP.Descrizione AS Priorita
FROM		dbo.Missioni M INNER JOIN dbo.Udc_Testata UT ON UT.Id_Udc = M.Id_Udc
INNER JOIN	dbo.Partizioni PSORG ON M.Id_Partizione_Sorgente = PSORG.ID_PARTIZIONE
INNER JOIN	dbo.Partizioni PDEST ON M.Id_Partizione_Destinazione = PDEST.ID_PARTIZIONE
INNER JOIN	dbo.Tipo_Stato_Missioni TSM ON TSM.Id_Stato_Missione = M.Id_Stato_Missione
INNER JOIN	dbo.Tipo_Priorita TP ON TP.Priorita = M.Priorita
INNER JOIN	dbo.Tipo_Missioni TM ON TM.Id_Tipo_Missione = M.Id_Tipo_Missione	 
LEFT JOIN	dbo.Udc_Posizione UP ON UP.Id_Udc = UT.Id_Udc
LEFT JOIN	dbo.Partizioni P ON UP.Id_Partizione = P.ID_PARTIZIONE
WHERE		M.Id_Stato_Missione IN ('NEW','ELA','ESE')
GO
