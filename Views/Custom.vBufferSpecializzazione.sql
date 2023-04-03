SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [Custom].[vBufferSpecializzazione] AS
--Controllo le missioni verso la partizione e le Udc che in quel momento sono in Baia dalla Udc Posizione
WITH Missioni_Specializzazione AS
(
	SELECT	COUNT(1) N_MISSIONI,
			P.ID_PARTIZIONE
	FROM	Missioni	M
	JOIN	Partizioni	P
	ON		M.Id_Partizione_Destinazione = P.ID_PARTIZIONE
		AND	(
				(P.ID_TIPO_PARTIZIONE = 'SP' AND M.Id_Tipo_Missione IN ('SPC','WBS'))
			OR
				P.ID_PARTIZIONE = 3501
			)
	GROUP
		BY	P.ID_PARTIZIONE
),
	UDC_IN_PARTIZIONE AS
(
	SELECT	COUNT(1) N_UDC,
			P.ID_PARTIZIONE
	FROM	Udc_Posizione	UP
	JOIN	Partizioni		P
	ON		UP.Id_Partizione = P.ID_PARTIZIONE
		AND (
				P.ID_TIPO_PARTIZIONE = 'SP'
					OR
				P.ID_PARTIZIONE = 3501
			)
	GROUP
		BY	P.ID_PARTIZIONE
)
SELECT	P.CAPIENZA - ISNULL(MS.N_MISSIONI,0) - ISNULL(UP.N_UDC,0)	PostiLiberiBuffer,
		P.ID_PARTIZIONE												Id_Partizione
FROM	Partizioni					P
LEFT
JOIN	Missioni_Specializzazione	MS
ON		MS.ID_PARTIZIONE = P.ID_PARTIZIONE
LEFT
JOIN	UDC_IN_PARTIZIONE			UP
ON		UP.ID_PARTIZIONE = P.ID_PARTIZIONE
WHERE	P.ID_TIPO_PARTIZIONE = 'SP'
	OR	P.ID_PARTIZIONE = 3501
GO
