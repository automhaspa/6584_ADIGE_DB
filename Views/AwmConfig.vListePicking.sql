SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vListePicking]
AS
SELECT	A.ID_AREA,
		P.DESCRIZIONE		Destinazione,
		LHG.Descrizione		Viaggio,
		LHG.Id_Partizione_Destinazione,
		LHG.Id_Gruppo_Lista,
		TSL.Descrizione		Stato,
		CAST(CASE WHEN SUM(LD.Qta_Lista) - (SUM(MD.Qta_Orig) + SUM(LUD.Qta_Prelevata)) > 0 THEN 1 ELSE 0 END AS BIT)	Mancanze,
		(SELECT COUNT(0) FROM dbo.Liste_Testata WHERE Id_Gruppo_Lista = lhg.Id_Gruppo_Lista)							nListe
FROM	dbo.Lista_Host_Gruppi		LHG
JOIN	dbo.Partizioni				P
ON		P.ID_PARTIZIONE = lhg.Id_Partizione_Destinazione
JOIN	dbo.SottoComponenti			SC
ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
JOIN	dbo.Componenti				C
ON		C.ID_COMPONENTE = SC.ID_COMPONENTE
JOIN	dbo.SottoAree				SA
ON		SA.ID_SOTTOAREA = C.ID_SOTTOAREA
JOIN	dbo.Aree					A
ON		A.ID_AREA = SA.ID_AREA
JOIN	dbo.Tipo_Stati_Lista		TSL
ON		TSL.Id_Stato_Lista = LHG.Id_Stato_Gruppo
JOIN	dbo.Liste_Testata			LT
ON		LT.Id_Gruppo_Lista = LHG.Id_Gruppo_Lista
LEFT
JOIN	dbo.Missioni_Dettaglio		MD
ON		MD.Id_Gruppo_Lista = LHG.Id_Gruppo_Lista
LEFT
JOIN	dbo.Liste_Dettaglio			LD
ON		LD.Id_Lista = LT.Id_Lista
LEFT
JOIN	dbo.Lista_Uscita_Dettaglio	LUD
ON		LUD.Id_Dettaglio = LD.Id_Dettaglio
GROUP
	BY	A.ID_AREA,
		P.DESCRIZIONE,
		LHG.Descrizione,
		LHG.Id_Partizione_Destinazione,
		LHG.Id_Gruppo_Lista,
		TSL.Descrizione
GO
