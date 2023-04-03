SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

--Vista giacenza articoli Magazzino Automha-Magazzino Manuale-Modula
CREATE VIEW [dbo].[vGroupItems]
AS
--Id Articoli e quantità presenti nel magazzino automha
SELECT		A.Id_Articolo,
				SUM(UD.Quantita_Pezzi) AS QtaTot
	FROM		dbo.Articoli A INNER JOIN	dbo.Udc_Dettaglio UD
	ON			UD.Id_Articolo = A.Id_Articolo	
	GROUP BY	A.Id_Articolo, A.Codice, A.Descrizione






GO
