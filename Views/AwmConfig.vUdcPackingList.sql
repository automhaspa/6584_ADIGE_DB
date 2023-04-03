SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE view [AwmConfig].[vUdcPackingList] AS 
SELECT 
ut.Id_Udc, 
pl.Id_Testata_Lista_Prelievo, 
plut.Id_Packing_List, 
pl.Nome_Packing_List, 
ut.Codice_Udc, 
p.Descrizione as Posizione_Udc,
plut.Flag_Completa, 
COUNT(ud.Id_UdcDettaglio) AS Numero_Articoli_Caricati FROM Custom.PackingLists_UdcTestata plut
INNER JOIN Custom.PackingLists pl ON pl.Id_Packing_List = plut.Id_Packing_List
INNER JOIN Udc_Testata ut ON ut.Id_Udc = plut.Id_Udc_Packing_List
INNER JOIN Udc_Posizione up ON up.Id_Udc = ut.Id_Udc
INNER JOIN Partizioni p ON p.ID_PARTIZIONE = up.Id_Partizione
LEFT JOIN Udc_Dettaglio ud ON ud.Id_Udc = ut.Id_Udc
GROUP BY ut.Id_Udc, pl.Id_Testata_Lista_Prelievo,plut.Id_Packing_List, pl.Nome_Packing_List, ut.Codice_Udc, plut.Flag_Completa, p.DESCRIZIONE
GO
