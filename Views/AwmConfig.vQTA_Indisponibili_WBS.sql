SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vQTA_Indisponibili_WBS] AS
	SELECT	UD.Id_UdcDettaglio,
			UD.Id_Articolo,
			ISNULL(UD.WBS_Riferimento,'')		WBS_Riferimento,
			SUM(Quantita)						QTA_INDISPONIBILE,
			NULL								ID_CAMBIO_WBS
	FROM	Missioni_Picking_Dettaglio	MPD
	JOIN	Udc_Dettaglio				UD
	ON		UD.Id_UdcDettaglio = MPD.Id_UdcDettaglio
	WHERE	Id_Stato_Missione IN (1,2)
	GROUP
		BY	UD.Id_Articolo,
			UD.Id_UdcDettaglio,
			ISNULL(UD.WBS_Riferimento,'')
	UNION
	SELECT	UD.Id_UdcDettaglio,
			UD.Id_Articolo,
			ISNULL(UD.WBS_Riferimento,''),
			SUM(Quantita)	Qta_Impegnata,
			WBS.Id_Cambio_WBS
	FROM	Custom.Missioni_Cambio_WBS	WBS
	JOIN	Udc_Dettaglio				UD
	ON		UD.Id_UdcDettaglio = WBS.Id_UdcDettaglio
	WHERE	Id_Stato_Lista IN (1,5,3)
	GROUP
		BY	UD.Id_UdcDettaglio,
			UD.Id_Articolo,
			ISNULL(UD.WBS_Riferimento,''),
			WBS.Id_Cambio_WBS
	UNION
	SELECT	UD.Id_UdcDettaglio,
			UD.Id_Articolo,
			ISNULL(UD.WBS_Riferimento,''),
			SUM(Quantita),
			NULL
	FROM	Custom.ControlloQualita		CQ
	JOIN	Udc_Dettaglio				UD
	ON		UD.Id_UdcDettaglio = CQ.Id_UdcDettaglio
	GROUP
		BY	UD.Id_UdcDettaglio,
			UD.Id_Articolo,
			ISNULL(UD.WBS_Riferimento,'')
	UNION
	SELECT	UD.Id_UdcDettaglio,
			UD.Id_Articolo,
			ISNULL(UD.WBS_Riferimento,''),
			SUM(Quantita),
			NULL
	FROM	Custom.NonConformita		NC
	JOIN	Udc_Dettaglio				UD
	ON		UD.Id_UdcDettaglio = NC.Id_UdcDettaglio
	GROUP
		BY	UD.Id_UdcDettaglio,
			UD.Id_Articolo,
			ISNULL(UD.WBS_Riferimento,'')
	UNION
	SELECT	UD.Id_UdcDettaglio,
			Id_Articolo,
			ISNULL(WBS_Riferimento,''),
			SUM(Quantita_Pezzi),
			NULL
	FROM	Udc_Dettaglio						UD
	JOIN	Udc_Testata							UT
	ON		UT.Id_Udc = UD.Id_Udc
	JOIN	Udc_Posizione						UP
	ON		UP.Id_Udc = UD.Id_Udc
	JOIN	Partizioni							P
	ON		P.Id_Partizione = UP.Id_Partizione
	WHERE	UT.Id_Udc = 702					--ESCLUDO MODULA
		OR	ISNULL(UT.Blocco_Udc,0) = 1		--ESCLUDO LE UDC BLOCCATE
		OR P.ID_TIPO_PARTIZIONE IN ('AT', 'KT', 'AP', 'US', 'OO')	--ESCLUDO LE UDC IN AREE TERRA/KITTING/PICKING
	GROUP
		BY	UD.Id_UdcDettaglio,
			Id_Articolo,
			ISNULL(WBS_Riferimento,'')
GO
