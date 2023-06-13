SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [Custom].[SpazioUdc_PerTipo](@Larghezza INT, @Profondita INT) 
RETURNS @freeSpace_PerType TABLE
(
	ID_SOTTOCOMPONENTE	INT,
	ID_PARTIZIONE		INT
)
AS
BEGIN
	INSERT INTO @freeSpace_PerType
	SELECT	freeSpace.ID_SOTTOCOMPONENTE,
			freeSpace.ID_PARTIZIONE
	FROM	dbo.vSpazioDisponibile		freeSpace
	LEFT
	JOIN	(
				SELECT	vPV.ID_SOTTOCOMPONENTE,
						UT.Larghezza,
						POS,
						POS + UT.Larghezza		POSDX
				FROM	dbo.vPosizioniVertici	vPV
				JOIN	dbo.Udc_Testata			UT
				ON		UT.Id_Udc = vPV.Id_Udc
				JOIN	dbo.SottoComponenti		SC
				ON		SC.ID_SOTTOCOMPONENTE = vPV.ID_SOTTOCOMPONENTE
				WHERE	UDCDX = 0
					AND vPV.Id_Udc IS NOT NULL
					AND vPV.CODICE_ABBREVIATO = '0002'
					AND vPV.Larghezza = @Larghezza
			)	Locazioni_Tipo_A
	ON		Locazioni_Tipo_A.ID_SOTTOCOMPONENTE = freeSpace.ID_SOTTOCOMPONENTE
		AND freeSpace.CODICE_ABBREVIATO   = '0001'
		AND freeSpace.PosX <= Locazioni_Tipo_A.POS
		AND freeSpace.PosX + freeSpace.SpazioDisponibile >= POSDX
	JOIN	dbo.Partizioni			P
	ON		P.ID_PARTIZIONE = freeSpace.ID_PARTIZIONE
	JOIN	dbo.SottoComponenti		SC
	ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
	WHERE	freeSpace.SpazioDisponibile >= @Larghezza + 10
		AND freeSpace.PROF_SLOT >= @PROFONDITA
		AND P.CAPIENZA > (SELECT COUNT(0) FROM dbo.Udc_Posizione WHERE Id_Partizione = freeSpace.ID_PARTIZIONE)
		AND (freeSpace.CODICE_ABBREVIATO = '0002' OR Locazioni_Tipo_A.POS IS NOT NULL OR SC.ID_COMPONENTE = 1201 OR SC.ID_COMPONENTE = 1102)
		AND	(@Larghezza <> 800 OR (@Larghezza = 800 AND SC.COLONNA <> 1))
		
	RETURN 

END
GO
