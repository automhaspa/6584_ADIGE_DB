SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vMovimentiMaterializzataBase]
WITH SCHEMABINDING
AS
SELECT	M.Id_Movimento,
		M.Codice_Udc,
		M.Codice_Articolo,
		M.Lotto,	   
		TCM.Descrizione				Tipo_Causale_Movimento,
		M.Data_Movimento,
		P.DESCRIZIONE				Posizione,
		M.Id_Utente,
		M.Quantita,
		M.CODICE_ORDINE,
		M.CAUSALE,
		M.PROD_ORDER_LOTTO,
		M.DESTINAZIONE_DDT,
		M.CONSEGNA_RAGSOC
FROM	dbo.Movimenti					M
JOIN	dbo.Tipo_Causali_Movimenti		TCM
ON		TCM.Id_Tipo_Causale = M.Id_Causale_Movimenti
JOIN	dbo.Partizioni					P
ON		P.ID_PARTIZIONE = M.Id_Partizione;
GO
