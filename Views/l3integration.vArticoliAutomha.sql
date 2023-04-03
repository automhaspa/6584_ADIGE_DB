SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE     VIEW [l3integration].[vArticoliAutomha]
AS
--Id Articoli, Codice e quantità presenti nel magazzino automha e Modula
SELECT	CONVERT(date,GETDATE())		DT_INS,
		0							STATUS,
		NULL						DT_ELAB,
		'AWM'						USERNAME,
		T.Codice					ITEM_CODE,
		SUM(T.Qta)					QUANTITY,
		0							QUANTITY_IN_KIT,
		0							ST_QUALITY,
		0							REASON
FROM	(
			SELECT	ud.Id_UdcDettaglio,
					a.Codice,
					(ud.Quantita_Pezzi - ISNULL(nc.Quantita, 0) - ISNULL(cq.Quantita, 0))	Qta
			FROM	Udc_Dettaglio			UD
			JOIN	Articoli				A
			ON		UD.Id_Articolo = A.Id_Articolo
			JOIN	Udc_Posizione			UP
			ON		UP.Id_Udc = UD.Id_Udc
			JOIN	Partizioni				P
			ON		P.Id_PArtizione = UP.Id_Partizione
			LEFT
			JOIN	Custom.NonConformita	NC
			ON		UD.Id_UdcDettaglio = NC.Id_UdcDettaglio
			LEFT
			JOIN	Custom.ControlloQualita CQ
			ON		CQ.Id_UdcDettaglio = UD.Id_UdcDettaglio
			WHERE	P.Id_Tipo_Partizione <> 'AP'
				AND P.ID_PARTIZIONE NOT IN (9104, 9105,9106)
		) T
GROUP
	BY	T.Codice
GO
