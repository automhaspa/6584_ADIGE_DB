SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO










CREATE VIEW [AwmConfig].[vTIPO_UDC]
AS
	SELECT	tu.Id_Tipo_Udc
			,tu.Descrizione
	FROM	dbo.Tipo_Udc AS tu
	WHERE	tu.Id_Tipo_Udc <> 'N'

GO
