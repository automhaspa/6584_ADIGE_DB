SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vContenutoUdc] AS
SELECT	ud.Id_Udc,
		ud.Id_UdcDettaglio,
		a.Codice, 
		a.Descrizione, 
		CAST(ud.Quantita_Pezzi AS NUMERIC(10,2)) Quantita_Pezzi,
		a.Unita_Misura
FROM	Udc_Dettaglio	UD
JOIN	Articoli		A
ON		A.Id_Articolo = UD.Id_Articolo
GO
