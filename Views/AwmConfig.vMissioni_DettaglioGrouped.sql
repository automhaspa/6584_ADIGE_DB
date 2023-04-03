SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW [AwmConfig].[vMissioni_DettaglioGrouped]
AS
SELECT	Missioni_Dettaglio.Id_Udc,
		UT.Codice_Udc,
        lhg.Id_Gruppo_Lista,
		lhg.Descrizione VIAGGIO,
        lt.Id_Lista ,
		lt.Codice_Lista,
        Missioni_Dettaglio.Id_Dettaglio ,
        Missioni_Dettaglio.Id_Articolo ,
		a.Codice,
		a.Descrizione AS Descrizione_Articolo,
        Missioni_Dettaglio.Lotto ,
        Quantita ,
        Missioni_Dettaglio.Id_Stato_Articolo,
		tsa.Descrizione Stato,
        Qta_Orig ,
        Missioni_Dettaglio.Id_UdcDettaglio ,
		ud.Id_UdcContainer
FROM	Missioni_Dettaglio
		INNER JOIN dbo.Articoli AS a ON a.Id_Articolo = Missioni_Dettaglio.Id_Articolo
		INNER JOIN dbo.Udc_Testata UT ON UT.Id_Udc = Missioni_Dettaglio.Id_Udc
		INNER JOIN dbo.Udc_Dettaglio AS ud ON ud.Id_UdcDettaglio = Missioni_Dettaglio.Id_UdcDettaglio
		INNER JOIN dbo.Lista_Host_Gruppi AS lhg ON lhg.Id_Gruppo_Lista = Missioni_Dettaglio.Id_Gruppo_Lista
		INNER JOIN dbo.Liste_Testata AS lt ON lt.Id_Lista = Missioni_Dettaglio.Id_Lista 
		INNER JOIN dbo.Tipo_Stato_Articolo AS tsa ON tsa.Id_Stato_Articolo = Missioni_Dettaglio.Id_Stato_Articolo
UNION
SELECT DISTINCT	Missioni_Dettaglio.Id_Udc ,
				UT.Codice_Udc,
				lhg.Id_Gruppo_Lista ,
				'',
				0,
				'',
				0,
				Missioni_Dettaglio.Id_Articolo,
				a.Codice,
				a.Descrizione AS Descrizione_Articolo,
				Missioni_Dettaglio.Lotto,
				SUM(Quantita) OVER (PARTITION BY Missioni_Dettaglio.Id_Articolo,Missioni_Dettaglio.Lotto),
				CASE WHEN NOT EXISTS (SELECT * FROM dbo.Missioni_Dettaglio AS md WHERE md.Id_Udc = Missioni_Dettaglio.Id_Udc AND md.Id_Stato_Articolo <> 5 AND md.Id_Gruppo_Lista = Missioni_Dettaglio.Id_Gruppo_Lista) THEN 5 ELSE 4 END,
				''
				,SUM(Qta_Orig ) OVER (PARTITION BY Missioni_Dettaglio.Id_Articolo,Missioni_Dettaglio.Lotto),
				0,
				Id_UdcContainer
FROM	Missioni_Dettaglio 
		INNER JOIN dbo.Udc_Testata UT ON UT.Id_Udc = Missioni_Dettaglio.Id_Udc
		INNER JOIN dbo.Udc_Dettaglio AS ud ON ud.Id_UdcDettaglio = Missioni_Dettaglio.Id_UdcDettaglio
		INNER JOIN dbo.Articoli AS a ON a.Id_Articolo = Missioni_Dettaglio.Id_Articolo
		INNER JOIN dbo.Lista_Host_Gruppi AS lhg ON lhg.Id_Gruppo_Lista = Missioni_Dettaglio.Id_Gruppo_Lista
GO
