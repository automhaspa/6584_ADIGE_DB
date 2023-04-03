SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vArticoliCompletaGrouped] AS
SELECT	Id_Articolo,
		Codice,
		Descrizione,
		Magazzino,
		CAST(ISNULL(SUM(Quantita),0) AS INT)	Quantita_Totale,
		Unita_Di_Misura
FROM	AwmConfig.vArticoliCompleta
GROUP
BY		Id_Articolo,
		Codice,
		Descrizione,
		Magazzino,
		Unita_Di_Misura
GO
