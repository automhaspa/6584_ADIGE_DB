SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

	CREATE VIEW [AwmConfig].[vUdcDettaglioNc] as
	SELECT	UT.Id_Udc,
			UT.Codice_Udc,
			A.Codice,
			A.Descrizione,
			NC.Quantita,
			P.DESCRIZIONE			Posizione_Udc,
			NC.MotivoNonConformita,
			ISNULL(NC.CONTROL_LOT, '')						CONTROL_LOT,
			ISNULL(TOE.DES_SUPPLIER_CODE,'DA PRODUZIONE')	DES_SUPPLIER_CODE,
			TOE.SUPPLIER_DDT_CODE,
			TOE.DT_RECEIVE_BLM,
			ISNULL(UD.WBS_Riferimento,'')					WBS_Riferimento,
			UD.Id_UdcDettaglio
	FROM	Custom.NonConformita		NC
	JOIN	Udc_Dettaglio				UD
	ON		UD.Id_UdcDettaglio = NC.Id_UdcDettaglio
	JOIN	Articoli					A
	ON		A.Id_Articolo = UD.Id_Articolo
	JOIN	Udc_Testata					UT
	ON		UT.Id_Udc = UD.Id_Udc
	JOIN	Udc_Posizione				UP
	ON		UP.Id_Udc = UT.Id_Udc
	JOIN	Partizioni					P
	ON		P.ID_PARTIZIONE = UP.Id_Partizione
	LEFT
	JOIN	Custom.RigheOrdiniEntrata		ROE
	ON		ROE.Id_Testata = UD.Id_Ddt_Reale
		AND ROE.LOAD_LINE_ID = UD.Id_Riga_Ddt
	LEFT
	JOIN	Custom.TestataOrdiniEntrata		TOE
	ON		TOE.ID = ROE.Id_Testata
	WHERE	NC.Quantita > 0
GO
