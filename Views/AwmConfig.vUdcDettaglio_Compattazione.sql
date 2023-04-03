SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [AwmConfig].[vUdcDettaglio_Compattazione] AS
SELECT	Id_Udc,
		Id_UdcDettaglio,
		Codice_Articolo,
		Descrizione_Articolo,
		Quantita_Pezzi,
		WBS_Riferimento,
		Unita_Misura,
		FlagControlloQualita,
		MotivoControlloQualita,
		Doppio_Step_QM,
		FlagNonConformita,
		MotivoNonConformita,
		Control_Lot,
		Id_Partizione,
		Id_Tipo_Udc
FROM	AwmConfig.vUdcDettaglio
GO
