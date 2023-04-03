SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vCausaliMovimentiManuali] AS
SELECT	Id_Causale,
		Tipo_Causale,
		Descrizione_Causale
FROM	Custom.CausaliMovimentazione
WHERE	Tipo_Causale = 'MOV_SUM'
	AND Attivo = 1
GO
