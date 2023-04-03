SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
create view [AwmConfig].[vTipo_Stati_DdtFittizi] as
SELECT 1 AS Id_Stato_Ddt, 'Non Specializzato' AS Descrizione
UNION
SELECT 2, 'Ordine di specializzazione in corso'
UNION
SELECT 3, 'Specializzazione Completata'
UNION
SELECT 5 , 'Specializzazione Sospesa'
GO
