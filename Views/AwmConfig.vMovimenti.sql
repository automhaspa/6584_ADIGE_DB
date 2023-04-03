SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vMovimenti]
AS
SELECT	Id_Movimento,
		CASE
			WHEN Posizione LIKE '5A02.000%' THEN CONCAT('UDC FITTIZIA SPOSTAMENTO AUTOMHA-MODULA, ', Codice_Udc)
			ELSE Codice_Udc
		END								Codice_Udc,
		Codice_Articolo,
		Lotto,
		Tipo_Causale_Movimento,
		Data_Movimento,
		Posizione,
		Quantita,
		Id_Utente,
		CODICE_ORDINE,
		CAUSALE,
		PROD_ORDER_LOTTO,
		DESTINAZIONE_DDT,
		CONSEGNA_RAGSOC
FROM	AwmConfig.vMovimentiMaterializzataBase
GO
