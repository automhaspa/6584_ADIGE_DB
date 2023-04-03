SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE VIEW [AwmConfig].[vUdcDettaglioNonConforme_2QM] AS

SELECT	UC.Id_Udc,
		UC.Id_Articolo,
		UC.Id_UdcDettaglio,
		UC.Codice_Udc,
		UC.PosizioneUdc,
		UC.Descrizione,
		UC.Codice_Articolo,
		UC.Quantita_Pezzi,
		UC.MotivoQualita,
		UC.CONTROL_LOT,
		concat('|',uc.CONTROL_LOT)		Control_Lot_Filtro,
		UC.DES_SUPPLIER_CODE,
		UC.SUPPLIER_DDT_CODE,
		UC.DT_RECEIVE_BLM,
		UC.DOPPIO_STEP_QM,
		UC.WBS_RIFERIMENTO,
		UC.USERNAME,
		UC.Articolo_Mancante,
		QC.QUANTITY					Qta_Da_Bloccare_Totale
FROM	AwmConfig.vUdcDettaglioControllare		uc
JOIN	l3integration.Quality_Changes			QC
ON		QC.CONTROL_LOT = uc.CONTROL_LOT
	AND QC.Id_Articolo = uc.Id_Articolo
	AND QC.STAT_QUAL_NEW = 'BLOC'
GO
