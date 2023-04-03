SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vRigheDdtDaSpecializzare] as

WITH UdcDettaglioSpost AS
(
	SELECT	ud.Id_Ddt_Reale,
			ud.Id_Articolo,
			ud.Id_Riga_Ddt,
			ISNULL(CAST(SUM(Quantita_Pezzi) as numeric(10,2)),0)	Qta
	FROM	Udc_Testata		ut
	JOIN	Udc_Dettaglio	ud ON ud.Id_Udc = ut.Id_Udc
	JOIN	Udc_Posizione	up ON up.Id_Udc = ut.Id_Udc
	WHERE	ISNULL(ud.Id_Ddt_Reale, -1) <> -1
		AND ISNULL(ud.Id_Riga_Ddt, -1) <> -1
		AND up.Id_Partizione IN (9104, 9105, 9106)
	--AND EXISTS (SELECT 1 FROM Missioni WHERE Id_Tipo_Missione = 'MTM' AND Id_Stato_Missione IN ('NEW', 'ELA', 'ESE') AND Id_Udc = ut.Id_Udc)
	GROUP
		BY	ud.Id_Ddt_Reale,
			ud.Id_Articolo,
			ud.Id_Riga_Ddt
),
QtaCons			AS
(
	SELECT	toe.ID,
			roe.LOAD_LINE_ID,
			a.Id_Articolo,
			ISNULL(CAST(SUM(his.ACTUAL_QUANTITY) AS numeric(10,2)), 0)	Qta
	FROM	L3INTEGRATION.dbo.HOST_INCOMING_SUMMARY his
	JOIN	Articoli		a
	ON		his.ITEM_CODE = a.Codice
	JOIN	Custom.TestataOrdiniEntrata toe ON (toe.LOAD_ORDER_ID = his.LOAD_ORDER_ID AND toe.LOAD_ORDER_TYPE = his.LOAD_ORDER_TYPE)
	JOIN	Custom.RigheOrdiniEntrata roe ON (roe.Id_Testata = toe.ID AND roe.LOAD_LINE_ID = his.LOAD_LINE_ID)
	GROUP
		BY	toe.ID,
			roe.LOAD_LINE_ID,
			a.Id_Articolo
)
SELECT	ut.Id_Udc,
		roe.Id_Testata, 
		a.Id_Articolo,
		toe.LOAD_ORDER_ID																NUMERO_BOLLA_ERP,
		TOE.LOAD_ORDER_TYPE																CAUSALE_BOLLA_ERP,
		roe.LOAD_LINE_ID																NUMERO_RIGA,
		roe.ITEM_CODE																	CODICE_ARTICOLO,
		a.Descrizione																	DESCRIZIONE_ARTICOLO,
		roe.QUANTITY																	QUANTITA_TOTALE,
		roe.QUANTITY - ISNULL(UDS.Qta, 0) - ISNULL(QT.Qta, 0)							QUANTITA_RIMANENTE_DA_SPECIALIZZARE,
		a.Unita_Misura																	UNITA_DI_MISURA,
		roe.PURCHASE_ORDER_ID															CODICE_ORDINE_ACQUISTO,
		CAST(ISNULL(roe.FL_INDEX_ALIGN, 0) AS bit)										FLAG_ALLINEAMENTO_INDICE,
		CAST(ISNULL(roe.FL_QUALITY_CHECK,0) AS bit)										FLAG_CONTROLLO_QUALITA,
		roe.COMM_PROD																	COMMESSA_PRODUZIONE,
		ROE.WBS_ELEM																	WBS_ELEM,
		ROE.CONTROL_LOT																	CONTROL_LOT,
		roe.COMM_SALE																	COMMESSA_VENDITA,
		roe.MANUFACTURER_ITEM 															CODICE_ARTICOLO_COSTRUTTORE,
		roe.MANUFACTURER_NAME															NUMERO_COSTRUTTORE,
		ISNULL(roe.FL_QUALITY_CHECK,0)													DOPPIO_STEP_QM
FROM	Eventi						ev
JOIN	Custom.RigheOrdiniEntrata	roe
ON		roe.Id_Testata = ev.Xml_Param.value('data(//Parametri//Id_Ddt_Reale)[1]','INT')
JOIN	Udc_Testata					UT
ON		ut.Id_Udc = ev.Xml_Param.value('data(//Parametri//Id_Udc)[1]','INT')
JOIN	Custom.TestataOrdiniEntrata toe
ON		toe.ID = roe.Id_Testata
JOIN	Articoli					A
ON		a.Codice = roe.ITEM_CODE
LEFT
JOIN	UdcDettaglioSpost			UDS
ON		UDS.Id_Ddt_Reale = toe.ID
	AND UDS.Id_Articolo = A.Id_Articolo
	AND UDS.Id_Riga_Ddt = roe.LOAD_LINE_ID
LEFT
JOIN	QtaCons						QT
ON		QT.ID = TOE.ID
	AND QT.LOAD_LINE_ID = roe.LOAD_LINE_ID
	AND QT.Id_Articolo = a.Id_Articolo
WHERE	ev.Id_Tipo_Evento = 32
	AND ev.Id_Tipo_Stato_Evento = 1
	AND roe.Stato = 1
GO
