SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vArticoliCompleta] AS
SELECT	a.Id_Articolo,
		a.Codice,
		a.Descrizione,
		CASE
			WHEN ud.Id_Udc = 702 THEN 'MODULA'
			WHEN ud.Id_Udc <> 702 THEN 'AUTOMHA'
		END												Magazzino,
		CAST(ISNULL(SUM(ud.Quantita_Pezzi),0) AS INT)	Quantita,
		a.Unita_Misura									Unita_Di_Misura
FROM	Articoli		A
LEFT
JOIN	Udc_Dettaglio	UD
ON		UD.Id_Articolo = A.Id_Articolo
GROUP
	BY	A.Id_Articolo,
		A.Codice,
		A.Descrizione, 
		UD.Id_Udc,
		A.Unita_Misura
GO
