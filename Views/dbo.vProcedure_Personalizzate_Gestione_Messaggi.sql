SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [dbo].[vProcedure_Personalizzate_Gestione_Messaggi] AS
SELECT ppgm.Id_Partizione,
p.DESCRIZIONE NomePartizione,
       ppgm.Id_Tipo_Messaggio,
	   tm.Descrizione AS NomeMessaggio,
       ppgm.Procedura,
       ppgm.Id_Partizione_OK,
	   pOk.DESCRIZIONE AS NomePartizioneOk,
       ppgm.Id_Partizione_OUT,
	   pOut.DESCRIZIONE AS NomePartizoneOut,
       ppgm.Id_Partizione_DEF,
	   pDef.DESCRIZIONE AS NomePartizioneDef
FROM 
dbo.Procedure_Personalizzate_Gestione_Messaggi AS ppgm
INNER JOIN  dbo.Partizioni AS p ON p.ID_PARTIZIONE = ppgm.Id_Partizione
INNER JOIN  dbo.Tipo_Messaggi AS tm ON tm.Id_Tipo_Messaggio = ppgm.Id_Tipo_Messaggio
LEFT OUTER JOIN dbo.Partizioni AS pOk ON ppgm.Id_Partizione_OK = pOk.ID_PARTIZIONE
LEFT OUTER JOIN dbo.Partizioni AS pOut ON ppgm.Id_Partizione_OUT = pOut.ID_PARTIZIONE
LEFT OUTER JOIN dbo.Partizioni AS pDef ON ppgm.Id_Partizione_DEF = pDef.ID_PARTIZIONE
GO
