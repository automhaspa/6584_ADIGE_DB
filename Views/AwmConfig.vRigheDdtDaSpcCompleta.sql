SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


--SPECIALIZZAZIONE INGOMBRANTI
CREATE VIEW [AwmConfig].[vRigheDdtDaSpcCompleta] as

WITH UdcDettaglioSpost AS
(
	SELECT	ud.Id_Ddt_Reale,
			ud.Id_Articolo,
			ud.Id_Riga_Ddt,
			ISNULL(CAST(SUM(Quantita_Pezzi) as numeric(10,2)),0)		Qta
	FROM	Udc_Testata		ut 
	JOIN	Udc_Dettaglio		ud ON ud.Id_Udc = ut.Id_Udc
	JOIN	Udc_Posizione		up ON up.Id_Udc = ut.Id_Udc
	WHERE	ISNULL(ud.Id_Ddt_Reale, -1) <> -1
		AND ISNULL(ud.Id_Riga_Ddt, -1) <> -1
		AND up.Id_Partizione IN (9104, 9105, 9106) --AREA TERRA VICINO A 3B
	GROUP BY ud.Id_Ddt_Reale, ud.Id_Articolo, ud.Id_Riga_Ddt
),
QtaCons	AS
(
	SELECT	toe.ID,
			roe.LOAD_LINE_ID,
			a.Id_Articolo,
			ISNULL(CAST(SUM(his.ACTUAL_QUANTITY) AS numeric(10,2)), 0)	Qta
	FROM	L3INTEGRATION.dbo.HOST_INCOMING_SUMMARY		his
	JOIN	Articoli									a
	ON		his.ITEM_CODE = a.Codice
	JOIN	Custom.TestataOrdiniEntrata					toe
	ON		toe.LOAD_ORDER_ID = his.LOAD_ORDER_ID
		AND toe.LOAD_ORDER_TYPE = his.LOAD_ORDER_TYPE
	JOIN	Custom.RigheOrdiniEntrata					roe
	ON		roe.Id_Testata = toe.ID
		AND roe.LOAD_LINE_ID = his.LOAD_LINE_ID
	GROUP
		BY	toe.ID, roe.LOAD_LINE_ID, a.Id_Articolo
)
SELECT	DISTINCT
		ut.Id_Udc,
		roe.Id_Testata,
		a.Id_Articolo,
		toe.LOAD_ORDER_ID										NUMERO_BOLLA_ERP,
		TOE.LOAD_ORDER_TYPE										CAUSALE_BOLLA_ERP,
		toe.SUPPLIER_CODE										CODICE_FORNITORE,
		toe.DES_SUPPLIER_CODE									RAGIONE_SOCIALE_FORNITORE,
		toe.SUPPLIER_DDT_CODE									CODICE_DDT_FORNITORE,
		roe.LOAD_LINE_ID										NUMERO_RIGA,
		roe.ITEM_CODE											CODICE_ARTICOLO,
		a.Descrizione											DESCRIZIONE_ARTICOLO,
		roe.QUANTITY											QUANTITA_TOTALE,
		(roe.QUANTITY - ISNULL(US.Qta, 0) - ISNULL(QC.Qta, 0))	QUANTITA_RIMANENTE_DA_SPECIALIZZARE,
		a.Unita_Misura											UNITA_DI_MISURA,
		roe.PURCHASE_ORDER_ID									CODICE_ORDINE_ACQUISTO,
		CAST(ISNULL(roe.FL_INDEX_ALIGN, 0) AS bit)				FLAG_ALLINEAMENTO_INDICE,
		CAST(ISNULL(roe.FL_QUALITY_CHECK,0) AS bit)				FLAG_CONTROLLO_QUALITA,
		roe.COMM_PROD											COMMESSA_PRODUZIONE,
		roe.COMM_SALE											COMMESSA_VENDITA,
		roe.MANUFACTURER_ITEM									CODICE_ARTICOLO_COSTRUTTORE,
		roe.MANUFACTURER_NAME									NUMERO_COSTRUTTORE
FROM	Eventi							ev
JOIN	Custom.AnagraficaDdtFittizi		ad
ON		ad.ID = ev.Xml_Param.value('data(//Parametri//Id_Ddt_Fittizio)[1]','INT')
JOIN	Udc_Testata						ut
ON		ut.Id_Udc = ev.Xml_Param.value('data(//Parametri//Id_Udc)[1]','INT')
JOIN	Custom.TestataOrdiniEntrata		toe
ON		toe.Id_Ddt_Fittizio = ad.ID
JOIN	Custom.RigheOrdiniEntrata		roe
ON		roe.Id_Testata = toe.ID
JOIN	Articoli						a
ON		a.Codice = roe.ITEM_CODE
LEFT
JOIN	UdcDettaglioSpost				US
ON		US.Id_Ddt_Reale = toe.ID
	AND US.Id_Articolo = A.Id_Articolo
	AND US.Id_Riga_Ddt = roe.LOAD_LINE_ID
LEFT
JOIN	QtaCons							QC
ON		QC.ID = TOE.ID
	AND QC.LOAD_LINE_ID = roe.LOAD_LINE_ID
	AND QC.Id_Articolo = a.Id_Articolo
WHERE	ev.Id_Tipo_Evento = 43
	AND ev.Id_Tipo_Stato_Evento = 1
	AND roe.Stato = 1

GO
