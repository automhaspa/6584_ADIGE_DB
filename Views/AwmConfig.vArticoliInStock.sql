SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vArticoliInStock]
AS
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
		UD.Qta_Persistenza,
		CONT.Description				Descrizione_Scomparto,
		ISNULL(UD.WBS_Riferimento,'')	WBS_Riferimento,
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
WHERE	P.ID_TIPO_PARTIZIONE <> 'AP'
GO
