SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vOpzioniMagazzino] AS 
SELECT	1			Id_Magazzino,
		'AUTOMHA'	Descrizione
UNION
SELECT	2,
		'MODULA'
UNION
SELECT	3,
		'INGOMBRANTI'
GO