SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
create view [AwmConfig].[vTipoUdcBase] as 
SELECT 1 AS Id_Opzione, 'TIPO A' AS Descrizione
UNION
SELECT 2 , 'TIPO B'  
GO
