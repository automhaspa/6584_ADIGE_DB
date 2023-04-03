SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE VIEW [dbo].[vSpazioDisponibile] AS
SELECT	c1.ID_SOTTOCOMPONENTE,
		c1.ID_PARTIZIONE,
		c1.CODICE_ABBREVIATO,
		c2.pos					PosX,
		c1.pos - c2.pos			SpazioDisponibile,
		Partizioni.PROFONDITA	PROF_SLOT,
		0						Flag_Speciale
FROM	vPosizioniVertici	c1
JOIN	dbo.Partizioni
ON		Partizioni.ID_PARTIZIONE = c1.ID_PARTIZIONE
LEFT
JOIN	vPosizioniVertici	c2
ON		c1.ord = c2.ord + 1
	AND c2.ID_PARTIZIONE = c1.ID_PARTIZIONE
--LEFT
--JOIN	dbo.Udc_Testata ON Udc_Testata.Id_Udc = c1.Id_Udc
--LEFT
--JOIN	dbo.Tipo_Udc ON Tipo_Udc.Id_Tipo_Udc = Udc_Testata.Id_Tipo_Udc
WHERE	c1.udcDx = 0
--Customizzazione presa da Scotton
--UNION 
--SELECT	Partizioni.ID_SOTTOCOMPONENTE
--		,ID_PARTIZIONE					
--		,Partizioni.CODICE_ABBREVIATO
--		,dbo.Partizioni.LARGHEZZA - 1120
--		,1120
--		,1200
--		,1 FLAG_SPECIALE
--FROM	dbo.Partizioni
--		INNER JOIN dbo.SottoComponenti ON SottoComponenti.ID_SOTTOCOMPONENTE = Partizioni.ID_SOTTOCOMPONENTE
--WHERE	ID_COMPONENTE = 5 AND COLONNA = 1 AND PIANO IN (1,2,5,6) AND Partizioni.CODICE_ABBREVIATO = '0002'
--		AND NOT EXISTS (SELECT	* 
--						FROM	dbo.Udc_Posizione 
--								INNER JOIN dbo.Udc_Testata ON Udc_Testata.Id_Udc = Udc_Posizione.Id_Udc
--						WHERE	ID_PARTIZIONE = dbo.Partizioni.ID_PARTIZIONE 
--								AND (QuotaDepositoX + dbo.Udc_Testata.Larghezza) > dbo.Partizioni.LARGHEZZA - 1120)
GO
