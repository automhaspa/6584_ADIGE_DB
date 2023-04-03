SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [l3integration].[vArticoliModulaSincro]
AS
	--Articoli presenti in modula che potrebbero non essere registrati in automha con giacenza maggiore di 0
	SELECT		hss.GIA_ARTICOLO, 
				hss.GIA_GIAC, 
				hss.GIA_VER, 
				hss.GIA_PRE, 0 AS FLAG_ELIMINA, 
				ud.Id_UdcDettaglio, 
				a.Id_Articolo  
	FROM		MODULA.HOST_IMPEXP.dbo.HOST_STOCK_SUMMARY hss WITH(NOLOCK)
	INNER JOIN	Articoli a ON a.Codice = hss.GIA_ARTICOLO
	LEFT JOIN	Udc_Dettaglio ud ON (ud.Id_Articolo = a.Id_Articolo AND ud.Id_Udc = 702)
	UNION 
	--Articoli registrati in automha NON presenti in MODULA
	SELECT		hss.GIA_ARTICOLO, 
				hss.GIA_GIAC, 
				hss.GIA_VER, 
				hss.GIA_PRE, 
				1 AS FLAG_ELIMINA, 
				ud.Id_UdcDettaglio, 
				ud.Id_Articolo 
	FROM		Udc_Dettaglio ud
	INNER JOIN	Articoli a ON a.Id_Articolo = ud.Id_Articolo
	LEFT JOIN	MODULA.HOST_IMPEXP.dbo.HOST_STOCK_SUMMARY hss WITH(NOLOCK) ON hss.GIA_ARTICOLO = a.Codice
	WHERE		Id_Udc = 702 
	AND			hss.GIA_GIAC IS NULL
GO
