SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO






CREATE VIEW [AwmConfig].[vArticoli]
AS
WITH Qta_Da_Considerare AS
(
	SELECT	UD.Id_Articolo,
			COUNT(UD.Id_Udc)		Presenza_Udc,
			SUM(UD.Quantita_Pezzi)	QtaTot
	FROM	Udc_Dettaglio	UD
	JOIN	Udc_Posizione	UP
	ON		UP.Id_Udc = UD.Id_Udc
	JOIN	Partizioni		P
	ON		P.Id_PArtizione = UP.Id_Partizione
	WHERE	ISNULL(p.Id_Tipo_Partizione, '') <> 'AP'
	GROUP
		BY	Id_Articolo
),
Qta_CQ AS
(
	SELECT	UD.Id_Articolo,
			SUM(CQ.Quantita)					QtaTot,
			COUNT(DISTINCT UD.Id_UdcDettaglio)	Presenza_UDC
	FROM	Custom.ControlloQualita		CQ
	JOIN	dbo.Udc_Dettaglio			UD
	ON		UD.Id_UdcDettaglio = CQ.Id_UdcDettaglio	
	JOIN	Udc_Posizione	UP
	ON		UP.Id_Udc = UD.Id_Udc
	JOIN	Partizioni		P
	ON		P.Id_PArtizione = UP.Id_Partizione
	WHERE	ISNULL(p.Id_Tipo_Partizione, '') <> 'AP'
	GROUP
		BY	UD.Id_Articolo
),
Qta_NonConforme AS
(
	SELECT	UD.Id_Articolo,
			SUM(NC.Quantita)					QtaTot,
			COUNT(DISTINCT UD.Id_UdcDettaglio)	Presenza_UDC
	FROM	Custom.NonConformita		NC
	JOIN	dbo.Udc_Dettaglio			UD
	ON		UD.Id_UdcDettaglio = NC.Id_UdcDettaglio
	JOIN	Udc_Posizione	UP
	ON		UP.Id_Udc = UD.Id_Udc
	JOIN	Partizioni		P
	ON		P.Id_PArtizione = UP.Id_Partizione
	WHERE	ISNULL(p.Id_Tipo_Partizione, '') <> 'AP'
	GROUP
		BY	UD.Id_Articolo
),
Qta_MANCANTI AS
(
	SELECT	Id_Articolo,
			SUM(Qta_Mancante)					QtaTot,
			COUNT(DISTINCT Id_Articolo)			Presenza_UDC
	FROM	Custom.AnagraficaMancanti
	WHERE	Qta_Mancante > 0
	GROUP
		BY	Id_Articolo
),
Qta_In_Transito AS
(
	SELECT	Id_Articolo,
			SUM(UD.Quantita_Pezzi)			QtaTot,
			COUNT(DISTINCT Id_Articolo)		Presenza_UDC
	FROM	Udc_Dettaglio		UD
	JOIN	Missioni			M
	ON		M.Id_Udc = UD.Id_Udc
		AND M.Id_Tipo_Missione = 'MTM'
	JOIN	Udc_Posizione	UP
	ON		UP.Id_Udc = UD.Id_Udc
	JOIN	Partizioni		P
	ON		P.Id_PArtizione = UP.Id_Partizione
	WHERE	ISNULL(p.Id_Tipo_Partizione, '') <> 'AP'
	GROUP
		BY	Id_Articolo
)
SELECT	A.Id_Articolo,
		A.Codice,
		A.Descrizione,
		ISNULL(QN.Presenza_Udc,0)		Presenza_Udc,
		ISNULL(QN.QtaTot,0)				QtaTot,
		ISNULL(QT.QtaTot,0)				QtaInTransito,
		ISNULL(QN.QtaTot,0)
			- ISNULL(CQ.QtaTot,0)
			- ISNULL(QNC.QtaTot,0)
			- ISNULL(QT.QtaTot,0)		Qta_Disponibile,
		ISNULL(CQ.QtaTot,0)				Qta_ControlloQualita,
		ISNULL(QNC.QtaTot,0)			Qta_NonConforme,
		ISNULL(QM.QtaTot,0)				Qta_Mancante
FROM	dbo.Articoli			A
LEFT
JOIN	Qta_Da_Considerare	QN
ON		QN.Id_Articolo = A.Id_Articolo
LEFT
JOIN	Qta_CQ					CQ
ON		CQ.Id_Articolo = A.Id_Articolo
LEFT
JOIN	Qta_MANCANTI			QM
ON		QM.Id_Articolo = A.Id_Articolo
LEFT
JOIN	Qta_NonConforme			QNC
ON		QNC.Id_Articolo = A.Id_Articolo
LEFT
JOIN	Qta_In_Transito			QT
ON		QT.Id_Articolo = A.Id_Articolo
GROUP
	BY	A.Id_Articolo, A.Codice, A.Descrizione,
		ISNULL(QN.Presenza_Udc,0),
		ISNULL(QN.QtaTot,0),
		ISNULL(QM.QtaTot,0),
		ISNULL(CQ.QtaTot,0),
		ISNULL(QNC.QtaTot,0),
		ISNULL(QT.QtaTot,0)

GO
