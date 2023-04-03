SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vUdcTestataSpostamento] AS
SELECT 
ut.Id_Udc, 
Codice_Udc, 
p.DESCRIZIONE AS Posizione
FROM Udc_Testata ut
INNER JOIN Udc_Posizione up ON ut.Id_Udc = up.Id_Udc
INNER JOIN Partizioni p ON p.ID_PARTIZIONE = up.Id_Partizione
WHERE ut.Id_Udc <> 702 AND ID_TIPO_PARTIZIONE <> 'MA'
GO
