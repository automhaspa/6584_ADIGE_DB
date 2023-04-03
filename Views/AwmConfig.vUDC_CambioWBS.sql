SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [AwmConfig].[vUDC_CambioWBS] AS
	SELECT	MWBS.Id_Cambio_WBS,
			UT.Id_Udc,
			UT.Codice_Udc,
			UD.Id_UdcDettaglio,
			UD.WBS_Riferimento								WBS_Dettaglio,
			CWBS.WBS_Destinazione,
			A.Codice,
			A.Descrizione,
			CWBS.Qta_Pezzi,
			SUM(CWBS.Qta_Pezzi)								QTA_TOT_DA_SPOSTARE,
			MWBS.Quantita - ISNULL(MWBS.Qta_Spostata,0)		QTA_DA_SPOSTARE_UDC,
			MWBS.Qta_Spostata								QTA_SPOSTATA_UDC,
			ISNULL(UD.Quantita_Pezzi,0)						QTA_TOT_IN_UDC,
			TSL.Descrizione									STATO_MISSIONE,
			MWBS.DataOra_Creazione							DataOra_Associazione,
			MWBS.DataOra_Esecuzione							DataOra_AvvioMissione,
			MWBS.DataOra_Termine,
			MWBS.DataOra_UltimaModifica,
			MWBS.Descrizione								Descrizione_Missione_WBS
	FROM	Udc_Dettaglio				UD
	JOIN	Custom.Missioni_Cambio_WBS	MWBS
	ON		UD.Id_UdcDettaglio = MWBS.Id_UdcDettaglio
		AND UD.Id_Articolo = MWBS.Id_Articolo
	JOIN	Custom.CambioCommessaWBS	CWBS
	ON		MWBS.Id_Cambio_WBS = CWBS.ID
		AND ISNULL(UD.WBS_Riferimento,'') = ISNULL(CWBS.WBS_Partenza,'')
	JOIN	Articoli					A
	ON		A.Id_Articolo = CWBS.Id_Articolo
	JOIN	Udc_Testata					UT
	ON		UT.Id_Udc = UD.Id_Udc
	JOIN	Tipo_Stati_Lista			TSL
	ON		TSL.Id_Stato_Lista = MWBS.Id_Stato_Lista
	GROUP
		BY	MWBS.Id_Cambio_WBS,
			UT.Id_Udc,
			UT.Codice_Udc,
			UD.Id_UdcDettaglio,
			UD.WBS_Riferimento,
			CWBS.WBS_Destinazione,
			A.Codice,
			A.Descrizione,
			CWBS.Qta_Pezzi,
			MWBS.Quantita,
			MWBS.Qta_Spostata,
			ISNULL(UD.Quantita_Pezzi,0),
			TSL.Descrizione,
			MWBS.DataOra_Creazione,
			MWBS.DataOra_Esecuzione,
			MWBS.DataOra_Termine,
			MWBS.DataOra_UltimaModifica,
			MWBS.Descrizione
GO
