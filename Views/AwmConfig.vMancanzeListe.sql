SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vMancanzeListe]
AS
	SELECT	T.Id_Gruppo_Lista,
            T.Id_Lista,
            T.Id_Dettaglio,
            T.Id_Articolo,
            T.Codice_Lista,
            T.Codice_Articolo,
            T.Qta_Lista,
            T.Qta_Sodd,
            T.Qta_Lista - T.Qta_Sodd		Qta_Mancante
	FROM	(
				SELECT	LHG.Id_Gruppo_Lista,
						LT.Id_Lista,
						LD.Id_Dettaglio,
						LD.Id_Articolo,
						LT.Codice_Lista,
						A.Codice		Codice_Articolo,
						LD.Qta_Lista,
						CASE
							WHEN SUM(ISNULL(MD.Qta_Orig,0)) = 0 THEN LUD.Qta_Prelevata
							ELSE SUM(ISNULL(MD.Qta_Orig,0))
						END				Qta_Sodd
						--,LD.Qta_Lista -	CASE
						--					WHEN SUM(ISNULL(MD.Qta_Orig,0)) = 0 THEN LUD.Qta_Prelevata
						--					ELSE SUM(ISNULL(MD.Qta_Orig,0))
						--				END											Qta_Mancante
				FROM	dbo.Lista_Host_Gruppi		LHG
				JOIN	dbo.Liste_Testata			LT
				ON		LT.Id_Gruppo_Lista = LHG.Id_Gruppo_Lista
				JOIN	dbo.Liste_Dettaglio			LD
				ON		LD.Id_Lista = LT.Id_Lista
				JOIN	dbo.Lista_Uscita_Dettaglio	LUD
				ON		LUD.Id_Dettaglio = LD.Id_Dettaglio
				JOIN	dbo.Articoli				A
				ON		A.Id_Articolo = LD.Id_Articolo
				LEFT
				JOIN	dbo.Missioni_Dettaglio		MD
				ON		MD.Id_Dettaglio = LD.Id_Dettaglio
					AND MD.Id_Articolo = LD.Id_Articolo
					AND MD.Id_Lista = LT.Id_Lista
				GROUP
					BY	LHG.Id_Gruppo_Lista, LT.Id_Lista, LD.Id_Dettaglio,
						LD.Id_Articolo, LT.Codice_Lista, A.Codice, LD.Qta_Lista,
						LUD.Qta_Prelevata,LUD.Qta_Prelevata
			)	T
	WHERE	T.Qta_Lista - T.Qta_Sodd <> 0
GO
