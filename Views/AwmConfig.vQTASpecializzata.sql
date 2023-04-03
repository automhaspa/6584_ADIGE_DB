SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vQTASpecializzata] AS
	SELECT	ud.Id_Ddt_Reale,
			ud.Id_Articolo,
			ud.Id_Riga_Ddt,
			ISNULL(CAST(SUM(Quantita_Pezzi) AS NUMERIC(10,2)),0)	Qta
	FROM	Udc_Testata		ut
	JOIN	Udc_Dettaglio	ud ON ud.Id_Udc = ut.Id_Udc
	JOIN	Udc_Posizione	up ON up.Id_Udc = ut.Id_Udc
	WHERE	ISNULL(ud.Id_Ddt_Reale, -1) <> -1
		AND ISNULL(ud.Id_Riga_Ddt, -1) <> -1
		AND up.Id_Partizione IN (9104, 9105, 9106)
	--AND EXISTS (SELECT 1 FROM Missioni WHERE Id_Tipo_Missione = 'MTM' AND Id_Stato_Missione IN ('NEW', 'ELA', 'ESE') AND Id_Udc = ut.Id_Udc)
	GROUP
		BY	ud.Id_Ddt_Reale,
			ud.Id_Articolo,
			ud.Id_Riga_Ddt
UNION
	SELECT	toe.ID,
			roe.LOAD_LINE_ID,
			a.Id_Articolo,
			ISNULL(CAST(SUM(his.ACTUAL_QUANTITY) AS numeric(10,2)), 0)	Qta
	FROM	L3INTEGRATION.dbo.HOST_INCOMING_SUMMARY his
	JOIN	Articoli		a
	ON		his.ITEM_CODE = a.Codice
	JOIN	Custom.TestataOrdiniEntrata toe ON (toe.LOAD_ORDER_ID = his.LOAD_ORDER_ID AND toe.LOAD_ORDER_TYPE = his.LOAD_ORDER_TYPE)
		AND TOE.Stato <> 1
	JOIN	Custom.RigheOrdiniEntrata roe ON (roe.Id_Testata = toe.ID AND roe.LOAD_LINE_ID = his.LOAD_LINE_ID)
		AND ROE.Stato <> 1
	GROUP
		BY	toe.ID,
			roe.LOAD_LINE_ID,
			a.Id_Articolo
GO
