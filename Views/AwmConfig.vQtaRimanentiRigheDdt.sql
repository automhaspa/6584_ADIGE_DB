SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [AwmConfig].[vQtaRimanentiRigheDdt]
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
		AND UP.Id_Partizione NOT IN (9104, 9105,9106)
	JOIN	Custom.RigheOrdiniEntrata			ROE
	ON		ROE.Id_Testata = UD.Id_Ddt_Reale
		AND ROE.LOAD_LINE_ID = UD.Id_Riga_Ddt
	JOIN	Custom.TestataOrdiniEntrata			TOE
	ON		TOE.ID = ROE.Id_Testata
		AND TOE.LOAD_ORDER_TYPE = 'RPO'
		AND TOE.DES_SUPPLIER_CODE <> 'IT30'
		AND TOE.SUPPLIER_CODE = 'IT30'
	WHERE	UD.Id_Ddt_Reale IS NOT NULL
		AND UD.Id_Riga_Ddt IS NOT NULL
	GROUP
		BY	UD.Id_Ddt_Reale,
			UD.Id_Articolo,
			UD.Id_Riga_Ddt
),
	UD_SPOST	AS
(
	SELECT	UD.Id_Ddt_Reale,
			UD.Id_Articolo,
			UD.Id_Riga_Ddt,
			CAST(SUM(Quantita_Pezzi) as numeric(10,2))		Qta
	FROM	Udc_Dettaglio				UD
	JOIN	Udc_Posizione				UP
	ON		UP.Id_Udc = UD.Id_Udc
	WHERE	ISNULL(UD.Id_Ddt_Reale, -1) <> -1
		AND ISNULL(UD.Id_Riga_Ddt, -1) <> -1
		AND UP.Id_Partizione IN (9104, 9105, 9106)
	GROUP
		BY	ud.Id_Ddt_Reale,
			ud.Id_Articolo,
			ud.Id_Riga_Ddt
),
	QtaConsuntivata		AS
(
	SELECT	TOE.ID,
			ROE.LOAD_LINE_ID,
			ROE.ITEM_CODE,
			CAST(SUM(his.ACTUAL_QUANTITY) AS numeric(10,2))			Qta
	FROM	L3INTEGRATION.dbo.HOST_INCOMING_SUMMARY		HIS
	JOIN	Custom.TestataOrdiniEntrata					TOE
	ON		TOE.LOAD_ORDER_ID = HIS.LOAD_ORDER_ID
		AND TOE.LOAD_ORDER_TYPE = HIS.LOAD_ORDER_TYPE
	JOIN	Custom.RigheOrdiniEntrata					ROE
	ON		ROE.Id_Testata = TOE.ID
		AND ROE.LOAD_LINE_ID = HIS.LOAD_LINE_ID
	GROUP
		BY	TOE.ID,
			ROE.LOAD_LINE_ID,
			ROE.ITEM_CODE
)
SELECT	ROE.Id_Testata,
		TOE.Id_Ddt_Fittizio,
		A.Id_Articolo,
		TOE.LOAD_ORDER_ID																			NUMERO_BOLLA_ERP,
		TOE.LOAD_ORDER_TYPE																			CAUSALE_BOLLA_ERP,
		ROE.LOAD_LINE_ID																			ID_RIGA,
		ROE.ITEM_CODE																				CODICE_ARTICOLO,
		A.Descrizione																				DESCRIZIONE_ARTICOLO,
		ROE.QUANTITY																				QUANTITA_TOTALE,
		(ROE.QUANTITY - ISNULL(UD_SPOST.Qta, 0) - ISNULL(QtaCons.Qta, 0) - ISNULL(RPO.QTA,0))		QUANTITA_RIMANENTE_DA_SPECIALIZZARE,
		A.Unita_Misura																				UNITA_DI_MISURA,
		ROE.PURCHASE_ORDER_ID																		CODICE_ORDINE_ACQUISTO,
		CAST(ISNULL(ROE.FL_INDEX_ALIGN, 0) AS bit)													FLAG_ALLINEAMENTO_INDICE,
		CAST(ISNULL(ROE.FL_QUALITY_CHECK,0) AS bit)													FLAG_CONTROLLO_QUALITA,
		ROE.COMM_PROD																				COMMESSA_PRODUZIONE,
		ROE.COMM_SALE																				COMMESSA_VENDITA,
		ROE.MANUFACTURER_ITEM																		CODICE_ARTICOLO_COSTRUTTORE,
		ROE.MANUFACTURER_NAME																		NUMERO_COSTRUTTORE
FROM	Custom.RigheOrdiniEntrata			ROE
JOIN	Custom.TestataOrdiniEntrata			TOE
ON		TOE.ID = ROE.Id_Testata
JOIN	Articoli							A
ON		A.Codice = ROE.ITEM_CODE
LEFT
JOIN 	UD_SPOST
ON		UD_SPOST.Id_Ddt_Reale = TOE.ID
	AND UD_SPOST.Id_Articolo = A.Id_Articolo
	AND UD_SPOST.Id_Riga_Ddt = ROE.LOAD_LINE_ID
LEFT
JOIN	QtaConsuntivata						QtaCons
ON		QtaCons.ID = TOE.ID
	AND QtaCons.LOAD_LINE_ID = ROE.LOAD_LINE_ID 
	AND QtaCons.ITEM_CODE = ROE.ITEM_CODE
LEFT
JOIN	QTA_SPEC_RPO						RPO
ON		RPO.Id_Ddt_Reale = TOE.ID
	AND RPO.Id_Articolo = A.Id_Articolo
	AND RPO.Id_Riga_Ddt = ROE.LOAD_LINE_ID
WHERE	ROE.Stato = 1
GO
