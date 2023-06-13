SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW [AwmConfig].[vArticoliInStock]
AS
WITH Qta_CQ AS
(
	SELECT	Id_UdcDettaglio,
			CONTROL_LOT,
			SUM(Quantita)					QtaTot
	FROM	Custom.ControlloQualita
	GROUP
		BY	Id_UdcDettaglio,
			CONTROL_LOT
),
Qta_NonConforme AS
(
	SELECT	Id_UdcDettaglio,
			CONTROL_LOT,
			SUM(Quantita)					QtaTot
	FROM	Custom.NonConformita
	GROUP
		BY	Id_UdcDettaglio,
			CONTROL_LOT
),
Qta_In_Transito AS
(
	SELECT	UD.Id_UdcDettaglio,
			SUM(UD.Quantita_Pezzi)			QtaTot
	FROM	dbo.Udc_Dettaglio		UD
	JOIN	dbo.Missioni			M
	ON		M.Id_Udc = UD.Id_Udc
		AND M.Id_Tipo_Missione = 'MTM'
	GROUP
		BY	UD.Id_UdcDettaglio
)
SELECT	UT.Id_Udc,
		A.Id_Articolo,
		UT.Codice_Udc,
		SC.PIANO						Piano,
		SC.COLONNA						Colonna,
		NULLIF(SA.ID_AREA,0)			ID_AREA,
		NULLIF(P.Descrizione,'')		Posizione,
		UT.Blocco_Udc,
		NULLIF(A.Codice,'')				Codice_Articolo,
		NULLIF(UD.Quantita_Pezzi,0)		Quantita_Pezzi,

		ISNULL(QT.QtaTot,0)				QtaInTransito,
		ISNULL(UD.Quantita_Pezzi,0)
			- ISNULL(CQ.QtaTot,0)
			- ISNULL(QNC.QtaTot,0)
			- ISNULL(QT.QtaTot,0)		Qta_Disponibile,
		ISNULL(CQ.QtaTot,0)				Qta_ControlloQualita,
		ISNULL(QNC.QtaTot,0)			Qta_NonConforme,

		UD.Qta_Persistenza,
		CONT.Description				Descrizione_Scomparto,
		ISNULL(UD.WBS_Riferimento,'')	WBS_Riferimento,
		ISNULL(UD.CONTROL_LOT,'')		CONTROL_LOT,
		UD.Id_UdcDettaglio
FROM	dbo.Udc_Testata		UT
JOIN	dbo.Udc_Dettaglio	UD
ON		UD.Id_Udc = UT.Id_Udc
JOIN	dbo.Articoli		A
ON		A.Id_Articolo = UD.Id_Articolo
JOIN	dbo.Udc_Posizione	UP
ON		UP.Id_Udc = UT.Id_Udc
JOIN	dbo.Partizioni		P
ON		P.Id_Partizione = UP.Id_Partizione
JOIN	dbo.SottoComponenti SC
ON		SC.Id_SottoComponente = P.Id_SottoComponente
JOIN	dbo.Componenti		C
ON		C.ID_COMPONENTE = SC.ID_COMPONENTE
JOIN	dbo.SottoAree		SA
ON		SA.ID_SOTTOAREA = C.ID_SOTTOAREA
LEFT
JOIN	Compartment.UdcContainer	UDCONT
ON		UDCONT.Id_UdcContainer = UD.Id_UdcContainer
LEFT
JOIN	Compartment.Container		CONT
ON		CONT.Id_Container = UDCONT.Id_Container
LEFT
JOIN	Qta_CQ					CQ
ON		CQ.Id_UdcDettaglio = UD.Id_UdcDettaglio
	--AND UD.CONTROL_LOT = CQ.CONTROL_LOT
LEFT
JOIN	Qta_NonConforme			QNC
ON		QNC.Id_UdcDettaglio = UD.Id_UdcDettaglio
	AND ISNULL(UD.CONTROL_LOT,'') = ISNULL(QNC.CONTROL_LOT,'')
LEFT
JOIN	Qta_In_Transito			QT
ON		QT.Id_UdcDettaglio = UD.Id_UdcDettaglio
WHERE	P.ID_TIPO_PARTIZIONE <> 'AP'
GO
