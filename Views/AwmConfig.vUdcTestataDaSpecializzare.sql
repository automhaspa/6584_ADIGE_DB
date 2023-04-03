SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vUdcTestataDaSpecializzare] as 
--Salvo Id_UDc e Id_evento
SELECT ut.Codice_Udc AS BARCODE_PALLET, adf.Codice_DDT AS CODICE_DDT_FITTIZIO, tu.Descrizione AS TIPO_UDC FROM Eventi ev
INNER JOIN Udc_Testata ut ON ut.Id_Udc = ev.Xml_Param.value('data(//Parametri//Id_Udc)[1]','NUMERIC(18,0)')
INNER JOIN Tipo_Udc tu ON ut.Id_Tipo_Udc = tu.Id_Tipo_Udc
INNER JOIN Custom.AnagraficaDdtFittizi adf ON adf.ID = ut.Id_Ddt_Fittizio
WHERE ev.Id_Tipo_Evento = 31 AND ev.Id_Tipo_Stato_Evento = 1
GO
