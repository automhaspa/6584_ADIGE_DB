SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
create view [AwmConfig].[vTipo_Stati_DdtReale]
as 
SELECT Id_Stato_Riga , Descrizione FROM Custom.Tipo_Stato_Testata_OrdiniEntrata
GO
