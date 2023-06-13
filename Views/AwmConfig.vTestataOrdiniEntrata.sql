SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





CREATE VIEW [AwmConfig].[vTestataOrdiniEntrata] AS
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
SELECT	toe.ID,
		toe.Id_Ddt_Fittizio,
		LOAD_ORDER_ID		NUMERO_BOLLA_ERP,
		LOAD_ORDER_TYPE		CAUSALE_DDT,
		DT_RECEIVE_BLM		DATA_RICEZIONE_BLM,
		SUPPLIER_CODE		CODICE_FORNITORE,
		DES_SUPPLIER_CODE	RAGIONE_SOCIALE_FORNITORE,
		adf.Codice_DDT		CODICE_BOLLA_AWM,
		SUPPLIER_DDT_CODE	CODICE_DDT_FORNITORE,
		tstoe.Descrizione	STATO_DDT,
		CAST(
				CASE
					WHEN ISNULL(MEAC.N_MANCANTI,0) > 0 THEN 1
					ELSE 0
				END AS BIT
			)					MANCANTI_PER_EAC
FROM	Custom.TestataOrdiniEntrata					toe
JOIN	Custom.Tipo_Stato_Testata_OrdiniEntrata		tstoe
ON		tstoe.Id_Stato_Riga = toe.Stato
LEFT
JOIN	Custom.AnagraficaDdtFittizi adf
ON		toe.Id_Ddt_Fittizio = adf.ID
LEFT
JOIN	MANCANTI_PER_EAC				MEAC
ON		MEAC.Id_Testata = TOE.ID
	AND TOE.LOAD_ORDER_TYPE = 'EAC'
WHERE	TOE.Stato IN (1,2)
	AND TOE.LOAD_ORDER_ID NOT LIKE 'AWM%'

GO
