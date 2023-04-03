SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW [AwmConfig].[vTestataDdtAssociati] AS
WITH MANCANTI_PER_EAC AS
(
	SELECT	ROE.Id_Testata,
			1							N_MANCANTI
	FROM	Custom.AnagraficaMancanti		M
	JOIN	Articoli						A
	ON		M.Id_Articolo = A.Id_Articolo
		AND M.Qta_Mancante > 0
	JOIN	Custom.RigheOrdiniEntrata		ROE
	ON		A.Codice = ROE.ITEM_CODE
	GROUP
		BY	ROE.Id_Testata
)
SELECT	UT.Id_Udc,
		TOE.ID,
		TOE.LOAD_ORDER_ID					NUMERO_BOLLA_ERP,
		TOE.LOAD_ORDER_TYPE					CAUSALE_DDT,
		CAST(TOE.DT_RECEIVE_BLM AS date)	DATA_RICEZIONE_BLM,
		TOE.SUPPLIER_CODE					CODICE_FORNITORE,
		TOE.DES_SUPPLIER_CODE				RAGIONE_SOCIALE_FORNITORE,
		TOE.SUPPLIER_DDT_CODE				CODICE_DDT_FORNITORE,
		TSLO.Descrizione,
		CAST(
				CASE
					WHEN ISNULL(MEAC.N_MANCANTI,0) > 0 THEN 1
					ELSE 0
				END AS BIT
			)		MANCANTI_PER_EAC
FROM	Eventi			EV
JOIN	Udc_Testata		UT
ON		UT.Id_Udc = EV.Xml_Param.value('data(//Parametri//Id_Udc)[1]','INT')
JOIN	Custom.AnagraficaDdtFittizi		ADF
ON		ADF.ID = UT.Id_Ddt_Fittizio
JOIN	Custom.TestataOrdiniEntrata		TOE
ON		TOE.Id_Ddt_Fittizio = ADF.ID
JOIN	Custom.Tipo_Stato_Testata_OrdiniEntrata	TSLO
ON		TOE.Stato = TSLO.Id_Stato_Riga
LEFT
JOIN	MANCANTI_PER_EAC				MEAC
ON		MEAC.Id_Testata = TOE.ID
	AND TOE.LOAD_ORDER_TYPE = 'EAC'
WHERE	Id_Tipo_Evento = 33
	AND Id_Tipo_Stato_Evento = 1
	AND TOE.Stato IN (1,2)
GO
