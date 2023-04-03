SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vUDCDettaglioAProgettoWBS] AS
	SELECT	CONCAT('|',ISNULL(UD.WBS_Riferimento,'')) ID_WBS,
			ISNULL(UD.WBS_Riferimento,'')	WBS_Riferimento,
			UD.QUANTITA_PEZZI				Qta_Totale,
			A.Id_Articolo,
			A.Codice,
			A.Descrizione,
			ISNULL(CQ.Quantita,0)	Qta_Cq,
			ISNULL(NC.Quantita,0)	Qta_Nf,
			ISNULL(UD.QUANTITA_PEZZI,0) - ISNULL(CQ.Quantita,0) - ISNULL(NC.Quantita,0)	Qta_Disponibile,
			P.DESCRIZIONE			Posizione_Udc,
			UT.Codice_Udc,
			UT.Id_Udc,
			UD.Id_UdcDettaglio
	FROM	Udc_Dettaglio			UD
	JOIN	Udc_Testata				UT
	ON		UT.Id_Udc = UD.Id_Udc
	JOIN	Udc_Posizione			UP
	ON		UP.Id_Udc = UD.Id_Udc
	JOIN	Partizioni				P
	ON		P.ID_PARTIZIONE = UP.Id_Partizione
	JOIN	Articoli				A
	ON		A.Id_Articolo = UD.Id_Articolo
	LEFT
	JOIN	Custom.ControlloQualita	CQ
	ON		CQ.Id_UdcDettaglio = UD.Id_UdcDettaglio
	LEFT
	JOIN	Custom.NonConformita	NC
	ON		NC.Id_UdcDettaglio = UD.Id_UdcDettaglio
	WHERE	WBS_Riferimento IS NOT NULL
GO
