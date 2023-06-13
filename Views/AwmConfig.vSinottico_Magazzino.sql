SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [AwmConfig].[vSinottico_Magazzino] AS
WITH LOCAZIONI_SCAFFALE AS
(
	SELECT	C.ID_COMPONENTE,
			C.DESCRIZIONE,
			C.ID_SOTTOAREA,
			P.ID_PARTIZIONE,
			P.CAPIENZA,
			P.LARGHEZZA
	FROM	dbo.Partizioni			P
	JOIN	dbo.SottoComponenti		SC
	ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
		AND P.ID_TIPO_PARTIZIONE = 'MA'
		AND P.ID_PARTIZIONE <> 9101
	JOIN	dbo.Componenti			C
	ON		C.ID_COMPONENTE = SC.ID_COMPONENTE
),
PARTIZIONI_CON_UDC AS
(
	SELECT	P.ID_PARTIZIONE,
			COUNT(DISTINCT UP.Id_Udc)			N_UDC,
			COUNT(CASE WHEN UT.Id_Tipo_Udc IN ('1','2','3') THEN 1 ELSE NULL END)	UDC_TIPO_A,
			COUNT(CASE WHEN UT.Id_Tipo_Udc IN ('4','5','6') THEN 1 ELSE NULL END)	UDC_TIPO_B
	FROM	dbo.Partizioni			P
	JOIN	dbo.Udc_Posizione		UP
	ON		UP.Id_Partizione = P.ID_PARTIZIONE
		AND P.ID_TIPO_PARTIZIONE = 'MA'
	JOIN	dbo.Udc_Testata			UT
	ON		UT.Id_Udc = UP.Id_Udc
	GROUP
		BY	P.ID_PARTIZIONE
)
SELECT	LS.ID_COMPONENTE,
		CASE
			WHEN LS.ID_COMPONENTE IN (1201,1102) THEN CONCAT(LS.DESCRIZIONE,' - UNA PARTIZIONE RIMANE LIBERA PER SCAMBI')
			ELSE LS.DESCRIZIONE																
		END																			ZONA_MAGAZZINO,
		SUM(LS.CAPIENZA)															CAPIENZA_TOT,
		COUNT(DISTINCT LS.ID_PARTIZIONE)											N_PARTIZIONI,
		COUNT(CASE WHEN PU.ID_PARTIZIONE IS NULL THEN 1 ELSE NULL END)				PARTIZIONI_VUOTE,
		COUNT(DISTINCT PU.Id_Partizione)											PARTIZIONI_OCCUPATE,
		SUM(PU.UDC_TIPO_A)															UDC_TIPO_A,
		SUM(PU.UDC_TIPO_B)															UDC_TIPO_B,
		COUNT(S_TIPO_A.ID_PARTIZIONE)												SPAZIO_LIBERO_UDC_TIPO_A,
		COUNT(S_TIPO_B.ID_PARTIZIONE)												SPAZIO_LIBERO_UDC_TIPO_B,
		ISNULL(SUM(PU.UDC_TIPO_A),0) + ISNULL(SUM(PU.UDC_TIPO_B),0)					TOT_UDC
FROM	LOCAZIONI_SCAFFALE			LS
LEFT
JOIN	PARTIZIONI_CON_UDC			PU
ON		PU.ID_PARTIZIONE = LS.ID_PARTIZIONE
LEFT
JOIN	Custom.SpazioUdc_PerTipo(800, 1200)				S_TIPO_A
ON		S_TIPO_A.ID_PARTIZIONE = LS.ID_PARTIZIONE
LEFT
JOIN	Custom.SpazioUdc_PerTipo(2400,800)				S_TIPO_B
ON		S_TIPO_B.ID_PARTIZIONE = LS.ID_PARTIZIONE
GROUP
	BY	LS.ID_COMPONENTE,
		CASE
			WHEN LS.ID_COMPONENTE IN (1201,1102) THEN CONCAT(LS.DESCRIZIONE,' - UNA PARTIZIONE RIMANE LIBERA PER SCAMBI')
			ELSE LS.DESCRIZIONE																
		END


GO