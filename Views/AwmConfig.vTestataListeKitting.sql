SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vTestataListeKitting] AS 
SELECT tlp.ID,
tlp.ORDER_ID, 
tlp.ORDER_TYPE, 
tlp.DT_EVASIONE, 
tlp.PRIORITY,
tlp.NR_KIT,
tlp.FL_KIT_CALC,
tlp.COMM_SALE,
tlp.DES_PREL_CONF,
tlp.PROD_LINE,
tlp.DETT_ETI,
tlp.FL_LABEL,
tstl.Descrizione AS Stato
FROM Custom.TestataListePrelievo tlp
INNER JOIN  Custom.Tipo_Stato_Testata_ListePrelievo tstl ON tlp.Stato = tstl.Id_Stato_Testata
WHERE ISNULL(tlp.FL_KIT, 0) = 1
GO
