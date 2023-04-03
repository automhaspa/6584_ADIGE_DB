SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO











CREATE VIEW [AwmConfig].[vTIPO_PRIORITA]
AS
	SELECT	tp.Priorita ,
            tp.Descrizione
	FROM	dbo.Tipo_Priorita AS tp
GO
