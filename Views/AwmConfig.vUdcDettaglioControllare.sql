SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW [AwmConfig].[vUdcDettaglioControllare] AS

WITH Mancanti AS
(
	SELECT	UD.Id_UdcDettaglio,
			AM.Id_Articolo,
			SUM(AM.Qta_Mancante)				Qta_Mancante
	FROM	Custom.AnagraficaMancanti		AM
	JOIN	dbo.Udc_Dettaglio				ud
	ON		ud.Id_Articolo = AM.Id_Articolo
		AND ISNULL(AM.Qta_Mancante,0)>0
	GROUP 
		BY	UD.Id_UdcDettaglio,
			AM.Id_Articolo
)
SELECT	UT.Id_Udc,
		UD.Id_Articolo,
		UD.Id_UdcDettaglio,
		UT.Codice_Udc,
		P.DESCRIZIONE									PosizioneUdc,
		A.Descrizione,
		A.Codice										Codice_Articolo,
		CQ.Quantita										Quantita_Pezzi,
		CQ.MotivoQualita,
		ISNULL(CQ.CONTROL_LOT, '')						CONTROL_LOT,
		ISNULL(TOE.DES_SUPPLIER_CODE,'DA PRODUZIONE')	DES_SUPPLIER_CODE,
		TOE.SUPPLIER_DDT_CODE,
		TOE.DT_RECEIVE_BLM,
		ISNULL(CQ.DOPPIO_STEP_QM,0)						DOPPIO_STEP_QM,
		ISNULL(UD.WBS_Riferimento,'')					WBS_RIFERIMENTO,
		ISNULL(CQ.Id_Utente, '')						USERNAME,
		CAST(
				CASE
					WHEN AM.Id_Articolo IS NULL THEN 0
					ELSE 1
				END		AS BIT
			)											Articolo_Mancante
FROM	Udc_Dettaglio		UD
JOIN	Udc_Testata			UT
ON		UT.Id_Udc = UD.Id_Udc
JOIN	Udc_Posizione		UP
ON		UP.Id_Udc = UT.Id_Udc
JOIN	Partizioni			P
ON		P.ID_PARTIZIONE = UP.Id_Partizione
JOIN	Articoli			A
ON		A.Id_Articolo = UD.Id_Articolo
JOIN	Custom.ControlloQualita			CQ
ON		UD.Id_UdcDettaglio = CQ.Id_UdcDettaglio
LEFT
JOIN	Custom.RigheOrdiniEntrata		ROE
ON		ROE.Id_Testata = UD.Id_Ddt_Reale
	AND ROE.LOAD_LINE_ID = UD.Id_Riga_Ddt
LEFT
JOIN	Custom.TestataOrdiniEntrata		TOE
ON		TOE.ID = ROE.Id_Testata
LEFT
JOIN	Mancanti						AM
ON		AM.Id_UdcDettaglio = UD.Id_UdcDettaglio
	AND ISNULL(AM.Qta_Mancante,0)>0
WHERE	ISNULL(CQ.Quantita, 0) > 0
GO
