SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW [AwmConfig].[vMancanti] AS
WITH ARTICOLI_DA_SPECIALIZZARE AS
(
	SELECT	A.Id_Articolo,
			roe.QUANTITY - ISNULL(qspec.Qta, 0)	qta_da_specializzare
	FROM	Custom.RigheOrdiniEntrata		ROE
	JOIN	dbo.Articoli					A
	ON		A.Codice = ROE.ITEM_CODE
		AND ROE.Stato = 1
    LEFT
	JOIN	AwmConfig.vQTASpecializzata		qspec
	ON		qspec.Id_Ddt_Reale = roe.Id_Testata
		AND A.Id_Articolo = QSPEC.Id_Articolo
	GROUP
		BY	A.Id_Articolo,
			roe.QUANTITY - ISNULL(qspec.Qta, 0)
),
CONTROLLO_QUALITA AS
(
	SELECT	DISTINCT ID_ARTICOLO
	FROM	Custom.ControlloQualita	CQ
	JOIN	Udc_Dettaglio			UD
	ON		UD.Id_UdcDettaglio = CQ.Id_UdcDettaglio
)
SELECT	ISNULL(tlp.ID,AM.Id_Testata)										Id_Testata,
		am.Id_Riga,
		ISNULL(tlp.ORDER_ID,AM.ORDER_ID)									ORDER_ID,
		ISNULL(tlp.ORDER_TYPE, AM.ORDER_TYPE)								ORDER_TYPE,
		ISNULL(tlp.DT_EVASIONE,AM.DT_EVASIONE)								DT_EVASIONE,
		ISNULL(tlp.COMM_PROD,AM.COMM_PROD)									COMM_PROD,
		ISNULL(tlp.COMM_SALE,AM.COMM_SALE)									COMM_SALE,
		AM.PROD_LINE,
		ISNULL(AM.PROD_ORDER,'')											PROD_ORDER,
		A.Codice,
		A.Descrizione,
		AM.Qta_Mancante														Qta_Mancante,
		CAST(
				CASE
					WHEN ISNULL(SUM(aspec.qta_da_specializzare),0) = 0 THEN 0
					ELSE 1
				END AS BIT
			)																Qta_Da_Specializzare,
		CAST(
				CASE
					WHEN CQ.Id_Articolo IS NULL THEN 0
					ELSE 1
				END AS BIT
			)																Qta_A_CQ
FROM	Custom.AnagraficaMancanti		am
JOIN	dbo.Articoli					a
ON		a.Id_Articolo = am.Id_Articolo
LEFT
JOIN	Custom.TestataListePrelievo		tlp
ON		am.Id_Testata = tlp.ID
LEFT
JOIN	ARTICOLI_DA_SPECIALIZZARE		aspec
ON		aspec.Id_Articolo = am.Id_Articolo
LEFT
JOIN	CONTROLLO_QUALITA				CQ
ON		CQ.ID_ARTICOLO = A.ID_ARTICOLO
WHERE	am.Qta_Mancante > 0
GROUP
	BY	ISNULL(tlp.ID,AM.Id_Testata),
		am.Id_Riga,
		ISNULL(tlp.ORDER_ID,AM.ORDER_ID),
		ISNULL(tlp.ORDER_TYPE, AM.ORDER_TYPE),
		ISNULL(tlp.DT_EVASIONE,AM.DT_EVASIONE),
		ISNULL(tlp.COMM_PROD,AM.COMM_PROD),
		ISNULL(tlp.COMM_SALE,AM.COMM_SALE),
		AM.PROD_LINE,
		ISNULL(AM.PROD_ORDER,''),
		A.Codice,
		A.Descrizione,
		AM.Qta_Mancante,
		CAST(
				CASE
					WHEN CQ.Id_Articolo IS NULL THEN 0
					ELSE 1
				END AS BIT
			)
GO
