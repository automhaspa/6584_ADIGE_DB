SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vUdcPackingListDisp] AS
SELECT 
put.Id_Udc_Packing_List AS Id_Udc,
pl.Id_Testata_Lista_Prelievo, 
a.Codice as Codice_Articolo,
pl.Id_Packing_List, 
pl.Nome_Packing_List, 
ut.Codice_Udc, 
p.DESCRIZIONE as Posizione_Udc
FROM  Eventi ev
INNER JOIN Custom.PackingLists pl ON pl.Id_Testata_Lista_Prelievo = ev.Xml_Param.value('data(//Parametri//Id_Testata_Lista_Prelievo)[1]', 'INT')
INNER JOIN Articoli a ON a.Id_Articolo = ev.Xml_Param.value('data(//Parametri//Id_Articolo)[1]', 'INT')
INNER JOIN Custom.PackingLists_UdcTestata put ON put.Id_Packing_List = pl.Id_Packing_List
INNER JOIN Udc_Testata ut ON put.Id_Udc_Packing_List = ut.Id_Udc
INNER JOIN Udc_Posizione up ON ut.Id_Udc = up.Id_Udc
INNER JOIN Partizioni p ON up.Id_Partizione = p.ID_PARTIZIONE
WHERE put.Flag_Completa = 0
GROUP BY put.Id_Udc_Packing_List, pl.Id_Testata_Lista_Prelievo, a.Codice, pl.Id_Packing_List, pl.Nome_Packing_List, ut.Codice_Udc, p.DESCRIZIONE
GO
