SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vPackingLists] AS 
SELECT	pl.Id_Packing_List,
		pl.Id_Testata_Lista_Prelievo,
		pl.Nome_Packing_List,
		tlp.ORDER_ID,
		tlp.ORDER_TYPE,
		COUNT(plut.Id_Udc_Packing_List)		Numero_Udc_Packing,
		pl.Data_Creazione
FROM	Custom.PackingLists				pl
JOIN	Custom.TestataListePrelievo		tlp
ON		tlp.ID = pl.Id_Testata_Lista_Prelievo
LEFT
JOIN	Custom.PackingLists_UdcTestata	plut
ON		pl.Id_Packing_List = plut.Id_Packing_List
GROUP
	BY	pl.Id_Packing_List, pl.Id_Testata_Lista_Prelievo,
		tlp.ORDER_ID, tlp.ORDER_TYPE, pl.Nome_Packing_List, pl.Data_Creazione
GO
