SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vTipoStatiListePrelievo] AS 
SELECT Id_Stato_Testata, Descrizione FROM Custom.Tipo_Stato_Testata_ListePrelievo
GO
