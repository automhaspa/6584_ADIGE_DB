SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vUdcTestataSpostamento_Compattazione] AS
WITH Buffer_Compattazione AS
(
	SELECT	C.ID_SOTTOAREA
	FROM	dbo.Parametri_Generali	PG
	JOIN	dbo.Partizioni			P
	ON		CONCAT('Compattazione_Avviata_',SUBSTRING(P.DESCRIZIONE,1,4)) = PG.Id_Parametro
	JOIN	dbo.SottoComponenti		SC
	ON		P.ID_SOTTOCOMPONENTE = SC.ID_SOTTOCOMPONENTE
	JOIN	dbo.Componenti			C
	ON		SC.ID_COMPONENTE = C.ID_COMPONENTE
	WHERE	PG.Valore = 'true'
)
SELECT	UT.Id_Udc,
		UT.Codice_Udc,
		P.DESCRIZIONE	Posizione
FROM	dbo.Udc_Testata			UT
JOIN	dbo.Udc_Posizione		UP
ON		UP.Id_Udc = UT.Id_Udc
JOIN	dbo.Partizioni			P
ON		P.ID_PARTIZIONE = UP.Id_Partizione
JOIN	dbo.SottoComponenti		SC
ON		P.ID_SOTTOCOMPONENTE = SC.ID_SOTTOCOMPONENTE
JOIN	dbo.Componenti			C
ON		SC.ID_COMPONENTE = C.ID_COMPONENTE
JOIN	Buffer_Compattazione	BC
ON		BC.ID_SOTTOAREA = C.ID_SOTTOAREA
GO
