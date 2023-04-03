SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vUdcDettControlloCq] 
AS
SELECT	vdc.Id_Udc,
		vdc.Id_Articolo,
		vdc.Id_UdcDettaglio,
		vdc.Descrizione,
		vdc.Codice_Udc,
		vdc.Codice_Articolo,
		vdc.Quantita_Pezzi,
		vdc.MotivoQualita,
		vdc.CONTROL_LOT
FROM	Eventi									ev
JOIN	AwmConfig.vUdcDettaglioControllare		vdc
ON		vdc.Id_Udc = ev.Xml_Param.value('data(//Parametri//Id_Udc)[1]','INT')
WHERE	Id_Tipo_Evento = 37
	AND Id_Tipo_Stato_Evento = 1
GO
