SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [AwmConfig].[vProgetti_WBS] AS
SELECT	CWBS.ID,
		CWBS.WBS_Partenza,
		CWBS.WBS_Destinazione,
		A.Codice,
		A.Descrizione,
		CWBS.Qta_Pezzi,
		ISNULL(SUM(UD.Quantita_Pezzi),0) - ISNULL(SUM(QI.QTA_INDISPONIBILE),0)	Qta_Disponibile_Sorgente,
		SUM(MWBS.Qta_Spostata)													Qta_Spostata,
		TL.Descrizione															Stato_Lista,
		CWBS.Descrizione														Descrizione_CambioWBS,
		CWBS.DataOra_Creazione,
		CWBS.DataOra_Avvio,
		CWBS.DataOra_UltimaModifica,
		CWBS.DataOra_Chiusura
FROM	Custom.CambioCommessaWBS			CWBS
JOIN	Articoli							A
ON		A.Id_Articolo = CWBS.Id_Articolo
JOIN	Tipo_Stati_Lista					TL
ON		CWBS.Id_Stato_Lista = TL.Id_Stato_Lista
LEFT
JOIN	Udc_Dettaglio						UD
ON		UD.Id_Articolo = CWBS.Id_Articolo
	AND ISNULL(UD.WBS_Riferimento,'') = ISNULL(CWBS.WBS_Partenza,'')
LEFT
JOIN	Custom.Missioni_Cambio_WBS			MWBS
ON		MWBS.Id_Cambio_WBS = CWBS.ID
	AND UD.Id_UdcDettaglio = MWBS.Id_UdcDettaglio
LEFT
JOIN	AwmConfig.vQTA_Indisponibili_WBS	QI
ON		QI.Id_Articolo = CWBS.Id_Articolo
	AND QI.WBS_Riferimento = ISNULL(CWBS.WBS_Partenza,'')
	AND QI.Id_UdcDettaglio = UD.Id_UdcDettaglio
	AND ISNULL(QI.ID_CAMBIO_WBS,0) <> MWBS.Id_Cambio_WBS
GROUP
	BY	CWBS.ID,
		CWBS.WBS_Partenza,
		CWBS.WBS_Destinazione,
		A.Codice,
		A.Descrizione,
		CWBS.Qta_Pezzi,
		TL.Descrizione,
		CWBS.Descrizione,
		CWBS.DataOra_Creazione,
		CWBS.DataOra_Avvio,
		CWBS.DataOra_UltimaModifica,
		CWBS.DataOra_Chiusura
GO
