SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vTipoOpzioniSpecializzazione]
AS
	SELECT	1 AS ID_OPZIONE , 'SPECIALIZZA UDC' AS DESCRIZIONE_OPERAZIONE UNION 
	SELECT  2,  'STOCCA UDC' 
GO
