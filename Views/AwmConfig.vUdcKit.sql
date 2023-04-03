SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE view [AwmConfig].[vUdcKit]
as
SELECT	oku.Id_Udc, 
		up.Id_Partizione, 
		tlp.ORDER_ID,
		oku.Id_Testata_Lista, 
		ut.Codice_Udc,
		Kit_Id, 
		p.DESCRIZIONE  
FROM	Custom.OrdineKittingUdc oku
JOIN	Udc_Testata ut ON  oku.Id_Udc = ut.Id_Udc
JOIN	Custom.TestataListePrelievo tlp ON tlp.ID = oku.Id_Testata_Lista
JOIN	Udc_Posizione up ON up.Id_Udc = ut.Id_Udc
JOIN	Partizioni p ON p.ID_PARTIZIONE = up.Id_Partizione
WHERE	Stato_Udc_Kit = 4
GO
