SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





CREATE VIEW [AwmConfig].[vUdcDettaglioConforme_2QM] AS

SELECT	uc.Id_Udc,
		uc.Id_Articolo,
		uc.Id_UdcDettaglio,
		uc.Codice_Udc,
		uc.PosizioneUdc,
		uc.Descrizione,
		uc.Codice_Articolo,
		uc.Quantita_Pezzi,
		uc.MotivoQualita,
		uc.CONTROL_LOT,
		concat('|',uc.CONTROL_LOT)		Control_Lot_Filtro,
		uc.DES_SUPPLIER_CODE,
		uc.SUPPLIER_DDT_CODE,
		uc.DT_RECEIVE_BLM,
		uc.DOPPIO_STEP_QM,
		uc.WBS_RIFERIMENTO,
		uc.USERNAME,
		uc.Articolo_Mancante,
		QC.QUANTITY					Qta_Da_Bloccare_Totale
FROM	AwmConfig.vUdcDettaglioControllare		uc
JOIN	l3integration.Quality_Changes			QC
ON		QC.CONTROL_LOT = uc.CONTROL_LOT
	AND QC.Id_Articolo = uc.Id_Articolo
	AND QC.STAT_QUAL_NEW = 'DISP'



GO
