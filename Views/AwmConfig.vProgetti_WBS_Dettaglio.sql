SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vProgetti_WBS_Dettaglio] AS
	SELECT	CONCAT('|',ISNULL(UD.WBS_Riferimento,''))	ID_WBS,
			ISNULL(UD.WBS_Riferimento,'')				WBS_Riferimento,
			ISNULL(SUM(UD.QUANTITA_PEZZI),0)			Qta_Totale,
			A.Id_Articolo,
			A.Codice,
			A.Descrizione,
			ISNULL(SUM(CQ.Quantita),0)					Qta_Cq,
			ISNULL(SUM(NC.Quantita),0)					Qta_Nf,
			ISNULL(SUM(UD.QUANTITA_PEZZI),0) - ISNULL(SUM(CQ.Quantita),0) - ISNULL(SUM(NC.Quantita),0)	Qta_Disponibile
	FROM	Udc_Dettaglio			UD
	JOIN	Articoli				A
	ON		A.Id_Articolo = UD.Id_Articolo
	LEFT
	JOIN	Custom.ControlloQualita	CQ
	ON		CQ.Id_UdcDettaglio = UD.Id_UdcDettaglio
	LEFT
	JOIN	Custom.NonConformita	NC
	ON		NC.Id_UdcDettaglio = UD.Id_UdcDettaglio
	WHERE	ISNULL(WBS_Riferimento,'')<>''
	GROUP
		BY	UD.WBS_Riferimento,
			A.Codice,
			A.Descrizione,
			A.Id_Articolo
GO
