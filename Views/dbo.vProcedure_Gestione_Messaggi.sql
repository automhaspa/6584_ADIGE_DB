SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[vProcedure_Gestione_Messaggi] AS
SELECT pgm.ID_TIPO_MESSAGGIO,
tm.Descrizione AS NomeMessaggio,
       pgm.PROCEDURA
FROM 
dbo.Procedure_Gestione_Messaggi AS pgm
INNER JOIN  dbo.Tipo_Messaggi AS tm ON tm.Id_Tipo_Messaggio = pgm.Id_Tipo_Messaggio
GO
