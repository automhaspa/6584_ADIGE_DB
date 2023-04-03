SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vTestataOrdiniEntrata_Storico] AS
SELECT	toe.ID,
		toe.Id_Ddt_Fittizio,
		LOAD_ORDER_ID		NUMERO_BOLLA_ERP,
		LOAD_ORDER_TYPE		CAUSALE_DDT,
		DT_RECEIVE_BLM		DATA_RICEZIONE_BLM,
		SUPPLIER_CODE		CODICE_FORNITORE,
		DES_SUPPLIER_CODE	RAGIONE_SOCIALE_FORNITORE,
		adf.Codice_DDT		CODICE_BOLLA_AWM,
		SUPPLIER_DDT_CODE	CODICE_DDT_FORNITORE,
		tstoe.Descrizione	STATO_DDT
FROM	Custom.TestataOrdiniEntrata					toe
JOIN	Custom.Tipo_Stato_Testata_OrdiniEntrata		tstoe
ON		tstoe.Id_Stato_Riga = toe.Stato
LEFT
JOIN	Custom.AnagraficaDdtFittizi adf
ON		toe.Id_Ddt_Fittizio = adf.ID
WHERE	TOE.Stato NOT IN (1,2)

GO
