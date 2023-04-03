SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vMagazzini] AS

SELECT	Id_Magazzino,
		Descrizione
FROM	Custom.Magazzini

GO
