SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vTIPO_MOVIMENTI]
AS
	SELECT	tcm.Id_Tipo_Causale
			,TCM.Descrizione
	FROM	dbo.Tipo_Causali_Movimenti AS tcm
	WHERE	tcm.Id_Tipo_Causale IN(1,2,3,5,6,7)

GO
