SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW [dbo].[vPosizioniVertici] AS
SELECT	T.*,
		ROW_NUMBER() OVER  (ORDER BY Partizioni.ID_PARTIZIONE ASC, T.POS ASC) ord,
		ID_SOTTOCOMPONENTE,
		dbo.Partizioni.CODICE_ABBREVIATO,
		Udc_Testata.Larghezza
FROM (
		SELECT	ID_PARTIZIONE,
				0		POS,
				1		UDCDX,
				NULL	Id_Udc
		FROM	Partizioni 
		UNION	
		SELECT	ID_PARTIZIONE,
				LARGHEZZA,
				0,
				NULL
		FROM	Partizioni			P
		JOIN	SottoComponenti		SC
		ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
		UNION
		SELECT	Id_Partizione,
				QuotaDepositoX,
				0,
				Id_Udc
		FROM	Udc_Posizione
		UNION
		SELECT	UP.Id_Partizione,
				QuotaDepositoX + Larghezza,
				1,
				UP.Id_Udc
		FROM	dbo.Udc_Posizione	UP
		JOIN	dbo.Udc_Testata		UT
		ON		UT.Id_Udc = UP.Id_Udc
	)  T
JOIN	dbo.Partizioni ON Partizioni.ID_PARTIZIONE = T.ID_PARTIZIONE
LEFT
JOIN	dbo.Udc_Testata ON Udc_Testata.Id_Udc = T.Id_Udc
WHERE	ID_TIPO_PARTIZIONE = 'MA'
	--ORDER BY Partizioni.ID_PARTIZIONE ASC, T.POS ASC			
GO
