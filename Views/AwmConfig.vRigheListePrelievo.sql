SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





CREATE VIEW [AwmConfig].[vRigheListePrelievo]
AS
SELECT	RLP.Id_Testata,
		RLP.ID,
		TLP.ORDER_ID,
		TLP.ORDER_TYPE,
		RLP.LINE_ID,
		RLP.ITEM_CODE,
		RLP.PROD_ORDER,
		RLP.PROD_LINE,
		RLP.QUANTITY																QUANTITA_RICHIESTA,
		ISNULL(SUM(mpd.Qta_Prelevata), 0)											QUANTITA_PRELEVATA,
		CASE
			WHEN ISNULL(RLP.Magazzino,'')<>'0020' THEN RLP.COMM_PROD
			ELSE CONCAT(RLP.COMM_PROD, ' - MAG ', RLP.Magazzino, ' NC ', RLP.Motivo_Nc)
		END																			COMM_PROD,
		ISNULL(VAA.QUANTITY,0)														QUANTITA_DISPONIBILE
FROM	Custom.RigheListePrelievo		RLP
JOIN	Custom.TestataListePrelievo		TLP
ON		RLP.Id_Testata = TLP.ID
JOIN	Articoli						A
ON		RLP.ITEM_CODE = A.Codice
LEFT
JOIN	l3integration.vArticoliAutomha	VAA
ON		A.Codice = VAA.ITEM_CODE
LEFT
JOIN	Missioni_Picking_Dettaglio		mpd
ON		mpd.Id_Testata_Lista = TLP.ID
	AND mpd.Id_Riga_Lista = RLP.ID
	AND ISNULL(mpd.FL_MANCANTI,0) = 0
--Raggruppo nel caso abbia 2 record della Missioni_Picking_Dettaglio della stessa riga ma distribuiti in modula-automha
GROUP
	BY	RLP.Id_Testata,
		RLP.ID,
		TLP.ORDER_ID,
		TLP.ORDER_TYPE,
		RLP.LINE_ID,
		RLP.ITEM_CODE,
		RLP.PROD_ORDER,
		RLP.QUANTITY,
		ISNULL(VAA.QUANTITY,0),
		CASE
			WHEN ISNULL(RLP.Magazzino,'')<>'0020' THEN RLP.COMM_PROD
			ELSE CONCAT(RLP.COMM_PROD, ' - MAG ', RLP.Magazzino, ' NC ', RLP.Motivo_Nc)
		END,
		RLP.PROD_LINE
GO
