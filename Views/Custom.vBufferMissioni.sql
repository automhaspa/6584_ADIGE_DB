SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [Custom].[vBufferMissioni] AS

WITH COMPATTAZIONI_ATTIVE AS
(
	SELECT	C.ID_SOTTOAREA,
			PG.Valore
	FROM	dbo.Parametri_Generali	PG
	JOIN	dbo.Partizioni			P
	ON		CONCAT('Compattazione_Avviata_',SUBSTRING(P.DESCRIZIONE,1,4)) = PG.Id_Parametro
	JOIN	dbo.SottoComponenti		SC
	ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
	JOIN	dbo.Componenti			C
	ON		C.ID_COMPONENTE = SC.ID_COMPONENTE
)
SELECT	CASE
			WHEN CA.Valore = 'True' THEN 0
			ELSE BufferSottoaree.PostiLiberiBuffer
		END				PostiLiberiBuffer,
		BufferSottoaree.Id_Sottoarea,
		BufferSottoaree.Tipo_Missione
FROM	
(
	SELECT	(TT.grandezzabuffer - TT.peso_udc - TT.nmissioniincorso)	PostiLiberiBuffer, 
			TT.Id_Sottoarea,
			TT.Tipo_Missione
	FROM	(
				SELECT	T.id_sottoarea, 
						T.grandezzabuffer, 
						T.peso_udc, 
						Msi.nmissioniincorso, 
						T.tipo_missione 
				FROM	(
							SELECT	34                            Id_Sottoarea,
									Isnull(Sum(UdcFerme.peso), 0) Peso_Udc,
									'OUL'                         Tipo_Missione,
									4                             GrandezzaBuffer
							FROM	(	--CARICA LE UDC FERME IN BAIA 3404
										SELECT	P.id_partizione Id_Partizione, 
												up.id_udc       Id_Udc, 
												CASE
													WHEN ISNULL(UP.Id_Udc, 0) = 0 THEN 0 
													ELSE 1 
												END				Peso
										FROM	Partizioni			P
										JOIN	Udc_Posizione		UP
										ON		P.ID_PARTIZIONE = UP.ID_PARTIZIONE
										LEFT
										JOIN	Missioni			M
										ON		M.Id_Udc = UP.Id_Udc
										WHERE	P.ID_PARTIZIONE = 3404
											AND M.Id_Missione IS NULL
										UNION
										--CARICA LE UDC FERME IN BAIA 3403
										SELECT	P.ID_PARTIZIONE,
												UP.Id_Udc,
												CASE 
													WHEN ISNULL(UP.ID_UDC, 0) = 0 THEN 0 
													ELSE 2 
												END
										FROM	Partizioni		P
										JOIN	Udc_Posizione		UP
										ON		P.ID_PARTIZIONE = UP.ID_PARTIZIONE
											AND	P.ID_PARTIZIONE = 3403
										LEFT
										JOIN	Missioni			M
										ON		M.Id_Udc = UP.Id_Udc
										WHERE	M.Id_Missione IS NULL
											AND NOT EXISTS	(
																SELECT	TOP 1 1 
																FROM	Udc_Posizione
																WHERE	ID_PARTIZIONE = 3404
															) 
											--AND NOT EXISTS (SELECT TOP 1 1 FROM Missioni WHERE Id_Udc = up.Id_Udc)
										UNION
										--CARICA LE UDC FERME IN BAIA 3403 CON UN UDC CHE LE FERMA IN 3404
										SELECT	P.ID_PARTIZIONE,
												UP.Id_Udc,
												CASE 
													WHEN ISNULL(UP.ID_UDC, 0) = 0 THEN 0 
													ELSE 2 
												END
										FROM	Partizioni		P
										JOIN	Udc_Posizione	UP
										ON		P.ID_PARTIZIONE = UP.ID_PARTIZIONE
											AND	P.ID_PARTIZIONE = 3403
										LEFT
										JOIN	Missioni		M
										ON		M.Id_Udc = UP.Id_Udc
										WHERE	M.Id_Udc IS NULL
											AND EXISTS	(
															SELECT	TOP 1 1 
															FROM	Udc_Posizione
															WHERE	ID_PARTIZIONE = 3404
														)
											  --AND NOT EXISTS (SELECT TOP 1 1 FROM Missioni WHERE Id_Udc = up.Id_Udc) 
									)	UdcFerme
							UNION 
							SELECT	34								Id_Sottoarea, 
									ISNULL(SUM(UdcFerme.peso), 0), 
									'OUC'							Tipo_Missione, 
									3								GrandezzaBuffer
							FROM	(
										SELECT	P.id_partizione		Id_Partizione, 
												up.id_udc			Id_Udc, 
												CASE
													WHEN Isnull(up.id_udc, 0) = 0 THEN 0 
													ELSE 1 
												END					Peso 
										FROM	Partizioni		P
										JOIN	Udc_Posizione	UP
										ON		P.ID_PARTIZIONE = UP.Id_Partizione
										LEFT
										JOIN	Missioni		M
										ON		M.Id_Udc = UP.Id_Udc
										WHERE	P.ID_PARTIZIONE = 3403
											AND M.Id_Missione IS NULL
											--AND NOT EXISTS (SELECT TOP 1 1 FROM Missioni WHERE Id_Udc = UP.Id_Udc)
									)	UdcFerme
						) T 
				LEFT--CARICA LE MISSIONI IN CORSO VERSO 3404/3403
				JOIN	(
							SELECT	34					Id_Sottoarea,
									COUNT(Id_Missione)	NMissioniInCorso 
							FROM	Missioni
							WHERE	Id_Partizione_Destinazione IN (3403, 3404)
								AND Id_Tipo_Missione IN ( 'OUL', 'OUC', 'OUP','OUM' ) 
						)	Msi 
				ON		Msi.id_sottoarea = T.id_sottoarea
			)	TT
	UNION
	SELECT	(TT2.grandezzabuffer - TT2.peso_udc - TT2.nmissioniincorso )		PostiLiberiBuffer, 
			TT2.Id_Sottoarea, 
			TT2.Tipo_Missione 
	FROM	(
				SELECT	T.id_sottoarea, 
						T.grandezzabuffer, 
						T.peso_udc, 
						Msi.nmissioniincorso, 
						T.tipo_missione
				FROM	(
							SELECT	36								Id_Sottoarea,
									ISNULL(SUM(UdcFerme.peso), 0)	Peso_Udc,
									'OUL'							Tipo_Missione,
									4								GrandezzaBuffer
							FROM	(
										SELECT	P.id_partizione		Id_Partizione, 
												up.id_udc			Id_Udc, 
												CASE
													WHEN ISNULL(up.id_udc, 0) = 0 THEN 0 
													ELSE 1 
												END					Peso
										FROM	Partizioni		P
										JOIN	Udc_Posizione	UP
										ON		P.ID_PARTIZIONE = UP.Id_Partizione
										WHERE	P.id_partizione = 3604
											AND NOT EXISTS (SELECT 1 FROM Missioni WHERE Id_Udc = up.Id_Udc)
										UNION
										SELECT	P.id_partizione		Id_Partizione, 
												up.id_udc			Id_Udc, 
												CASE
													WHEN ISNULL(up.id_udc, 0) = 0 THEN 0 
													ELSE 1 
												END					Peso
										FROM	Partizioni		P
										JOIN	Udc_Posizione	UP
										ON		P.ID_PARTIZIONE = UP.Id_Partizione
										WHERE	P.ID_PARTIZIONE IN (3603)
											AND NOT EXISTS(SELECT TOP 1 1 FROM udc_posizione WHERE id_partizione = 3604)
											AND NOT EXISTS(SELECT TOP 1 1 FROM Missioni WHERE Id_Udc = up.Id_Udc)
										UNION
										SELECT	P.id_partizione		Id_Partizione, 
												up.id_udc			Id_Udc, 
												CASE
													WHEN ISNULL(up.id_udc, 0) = 0 THEN 0 
													ELSE 1 
												END					Peso
										FROM	Partizioni		P
										JOIN	Udc_Posizione	UP
										ON		P.ID_PARTIZIONE = UP.Id_Partizione
										WHERE	P.ID_PARTIZIONE IN ( 3603 )
											AND EXISTS(SELECT TOP 1 1 FROM Udc_Posizione WHERE ID_PARTIZIONE = 3604)
											AND NOT EXISTS(SELECT TOP 1 1 FROM Missioni WHERE Id_Udc = up.Id_Udc)
									)	UdcFerme
							UNION
							SELECT	36,
									ISNULL(SUM(UdcFerme.PESO), 0),
									'OUC',
									3
							FROM	(
										SELECT	P.id_partizione		Id_Partizione, 
												up.id_udc			Id_Udc, 
												CASE
													WHEN ISNULL(up.id_udc, 0) = 0 THEN 0 
													ELSE 1 
												END					Peso
										FROM	Partizioni		P
										JOIN	Udc_Posizione	UP
										ON		P.ID_PARTIZIONE = UP.Id_Partizione
										WHERE	P.ID_PARTIZIONE = 3603
											AND	NOT EXISTS (SELECT TOP 1 1 FROM Missioni WHERE Id_Udc = up.Id_Udc)
									)	UdcFerme
						)	T 
					LEFT
					JOIN	(
								SELECT	36						Id_Sottoarea,
										COUNT(Id_Missione)		NMissioniInCorso
								FROM	Missioni
								WHERE	Id_Partizione_Destinazione IN (3603, 3604)
									AND Id_Tipo_Missione IN ('OUL','OUC','OUP','OUM')
							) Msi
					ON	Msi.id_sottoarea = T.id_sottoarea
			) TT2
	UNION
	SELECT	3 - COUNT(Id_Missione) -	(
											SELECT	COUNT(1)
											FROM	Udc_Posizione		UP
											WHERE	Id_Partizione = 3203 AND NOT EXISTS(SELECT TOP 1 1 FROM Missioni WHERE Id_Udc = UP.Id_Udc)
										),
			32,
			''
	FROM	Missioni
	WHERE	Id_Partizione_Destinazione = 3203
		AND Id_Tipo_Missione IN ('OUL', 'OUC', 'OUT', 'OUP', 'SPC','WBS','OUM')
	UNION
	SELECT	1 - COUNT(Id_Missione) -	(
											SELECT	COUNT(1)
											FROM	Udc_Posizione UP
											WHERE	Id_Partizione = 3701
												AND	NOT EXISTS(SELECT TOP 1 1 FROM Missioni WHERE Id_Udc = UP.Id_Udc)
										),
			37,
			''
	FROM	Missioni
	WHERE	Id_Partizione_Destinazione = 3701
		AND Id_Tipo_Missione IN ('CQL', 'OUP')
) BufferSottoaree
LEFT
JOIN	COMPATTAZIONI_ATTIVE			CA
ON		BufferSottoaree.Id_Sottoarea = CA.ID_SOTTOAREA
GO
