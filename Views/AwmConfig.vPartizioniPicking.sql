SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE view [AwmConfig].[vPartizioniPicking] as
SELECT Id_Partizione, DESCRIZIONE FROM Partizioni WHERE Id_Partizione IN (3404, 3604)
GO
