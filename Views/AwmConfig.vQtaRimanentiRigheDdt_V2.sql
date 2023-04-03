SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [AwmConfig].[vQtaRimanentiRigheDdt_V2]
as

WITH QTA_SPEC_RPO AS
(
	SELECT	ud.Id_Ddt_Reale,
			ud.Id_Articolo,
			ud.Id_Riga_Ddt,
			CAST(SUM(Quantita_Pezzi) as numeric(10,2))		Qta
	FROM	Udc_Dettaglio						UD
	JOIN	Udc_Posizione						UP
	ON		UP.Id_Udc = UD.Id_Udc
		AND up.Id_Partizione NOT IN (9104, 9105,9106)
	JOIN	Custom.RigheOrdiniEntrata			ROE
	ON		ROE.Id_Testata = UD.Id_Ddt_Reale
		AND ROE.LOAD_LINE_ID = UD.Id_Riga_Ddt
	JOIN	Custom.TestataOrdiniEntrata			TOE
	ON		TOE.ID = ROE.Id_Testata
		AND TOE.LOAD_ORDER_TYPE = 'RPO'
		AND TOE.DES_SUPPLIER_CODE <> 'IT30'
		AND TOE.SUPPLIER_CODE = 'IT30'
	WHERE	ud.Id_Ddt_Reale IS NOT NULL
		AND ud.Id_Riga_Ddt IS NOT NULL
	GROUP
		BY	ud.Id_Ddt_Reale,
			ud.Id_Articolo,
			ud.Id_Riga_Ddt
),
	UD_SPOST	AS
(
	SELECT	ud.Id_Ddt_Reale,
			ud.Id_Articolo,
			ud.Id_Riga_Ddt,
			CAST(SUM(Quantita_Pezzi) as numeric(10,2))		Qta
	FROM	Udc_Dettaglio			UD
	JOIN	Udc_Posizione			UP
	ON		UP.Id_Udc = UD.Id_Udc
	WHERE	ISNULL(UD.Id_Ddt_Reale, -1) <> -1
		AND ISNULL(UD.Id_Riga_Ddt, -1)	<> -1
		AND UP.Id_Partizione IN (9104, 9105, 9106)
	GROUP
		BY	UD.Id_Ddt_Reale,
			UD.Id_Articolo,
			UD.Id_Riga_Ddt
),
	QtaConsuntivata	AS
(
	SELECT	toe.ID,
			roe.LOAD_LINE_ID,
			ROE.ITEM_CODE,
			CAST(SUM(his.ACTUAL_QUANTITY) AS numeric(10,2))			Qta
	FROM	L3INTEGRATION.dbo.HOST_INCOMING_SUMMARY		his
	JOIN	Custom.TestataOrdiniEntrata					toe
	ON		toe.LOAD_ORDER_ID = his.LOAD_ORDER_ID
		AND toe.LOAD_ORDER_TYPE = his.LOAD_ORDER_TYPE
	JOIN	Custom.RigheOrdiniEntrata					roe
	ON		roe.Id_Testata = toe.ID
		AND roe.LOAD_LINE_ID = his.LOAD_LINE_ID
	GROUP
		BY	toe.ID,
			roe.LOAD_LINE_ID,
			ROE.ITEM_CODE
)
SELECT	roe.Id_Testata,
		toe.Id_Ddt_Fittizio,
		a.Id_Articolo,
		toe.LOAD_ORDER_ID																			NUMERO_BOLLA_ERP,
		TOE.LOAD_ORDER_TYPE																			CAUSALE_BOLLA_ERP,
		roe.LOAD_LINE_ID																			ID_RIGA,
		roe.ITEM_CODE																				CODICE_ARTICOLO,
		a.Descrizione																				DESCRIZIONE_ARTICOLO,
		roe.QUANTITY																				QUANTITA_TOTALE,
		(roe.QUANTITY - ISNULL(UD_SPOST.Qta, 0) - ISNULL(QtaCons.Qta, 0) - ISNULL(RPO.QTA,0))		QUANTITA_RIMANENTE_DA_SPECIALIZZARE,
		a.Unita_Misura																				UNITA_DI_MISURA,
		roe.PURCHASE_ORDER_ID																		CODICE_ORDINE_ACQUISTO,
		CAST(ISNULL(roe.FL_INDEX_ALIGN, 0) AS bit)													FLAG_ALLINEAMENTO_INDICE,
		CAST(ISNULL(roe.FL_QUALITY_CHECK,0) AS bit)													FLAG_CONTROLLO_QUALITA,
		roe.COMM_PROD																				COMMESSA_PRODUZIONE,
		roe.COMM_SALE																				COMMESSA_VENDITA,
		roe.MANUFACTURER_ITEM																		CODICE_ARTICOLO_COSTRUTTORE,
		roe.MANUFACTURER_NAME																		NUMERO_COSTRUTTORE
FROM	Custom.RigheOrdiniEntrata			roe
JOIN	Custom.TestataOrdiniEntrata			toe
ON		toe.ID = roe.Id_Testata
JOIN	Articoli							a
ON		a.Codice = roe.ITEM_CODE
LEFT
JOIN 	UD_SPOST
ON		UD_SPOST.Id_Ddt_Reale = toe.ID
	AND UD_SPOST.Id_Articolo = A.Id_Articolo
	AND UD_SPOST.Id_Riga_Ddt = roe.LOAD_LINE_ID
LEFT
JOIN	QtaConsuntivata						QtaCons
ON		QtaCons.ID = TOE.ID
	AND QtaCons.LOAD_LINE_ID = roe.LOAD_LINE_ID
	AND QtaCons.ITEM_CODE = ROE.ITEM_CODE
LEFT
JOIN	QTA_SPEC_RPO	RPO
ON		RPO.Id_Ddt_Reale = toe.ID
	AND RPO.Id_Articolo = A.Id_Articolo
	AND RPO.Id_Riga_Ddt = roe.LOAD_LINE_ID
WHERE	ROE.Stato = 1
GO
