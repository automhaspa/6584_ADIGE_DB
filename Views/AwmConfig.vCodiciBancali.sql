SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE view [AwmConfig].[vCodiciBancali] as 
SELECT	ID,
		ab.Codice_Barcode		Codice_Udc,
		DataOra_Creazione
FROM	[Custom].[AnagraficaBancali]		ab
LEFT
JOIN	Udc_Testata							ut
ON		ab.Codice_Barcode = ut.Codice_Udc
WHERE	ut.Id_Udc IS NULL
	AND ab.Stato = 1
GO
