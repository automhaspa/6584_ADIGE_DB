SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [AwmConfig].[vRigheListeKitting]
AS
SELECT        
rlp.Id_Testata,
rlp.ID, 
tlp.ORDER_ID, 
tlp.ORDER_TYPE, 
rlp.ITEM_CODE, 
rlp.KIT_ID,
rlp.PROD_ORDER, 
rlp.QUANTITY,
 (CASE 
	--Escludo le quantità già impegnate in altre liste di prelievo, Escludo anche Outbound?
	--WHEN rpa.Qta_DaPrelevare IS NOT NULL AND vaa.QUANTITY > rpa.Qta_DaPrelevare THEN  vaa.QUANTITY - rpa.Qta_DaPrelevare
	--Se non ho disposnibilita
	WHEN vaa.QUANTITY IS NULL THEN 0
	ELSE vaa.QUANTITY
	END
 ) AS QUANTITA_DISPONIBILE , 
 rlp.COMM_PROD, 
 rlp.PROD_LINE, 
 rlp.DOC_NUMBER,
 rlp.SAP_DOC_NUM
FROM Custom.RigheListePrelievo rlp
INNER JOIN Custom.TestataListePrelievo tlp ON rlp.Id_Testata = tlp.ID
INNER JOIN Articoli a ON rlp.ITEM_CODE = a.Codice
LEFT JOIN l3integration.vArticoliAutomha vaa ON a.Codice = vaa.ITEM_CODE
GO
