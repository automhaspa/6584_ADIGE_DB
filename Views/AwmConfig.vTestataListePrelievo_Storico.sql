SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO






CREATE VIEW [AwmConfig].[vTestataListePrelievo_Storico]
AS
WITH Prod_Order_ToShow AS
(
	SELECT	TLP.ID,
			CASE
				WHEN COUNT(DISTINCT RLP.PROD_ORDER) = 1 THEN MIN(RLP.PROD_ORDER)
				ELSE ''
			END				Prod_Order
	FROM	Custom.TestataListePrelievo		TLP
	JOIN	Custom.RigheListePrelievo		RLP
	ON		RLP.Id_Testata = TLP.ID
		AND ISNULL(tlp.FL_KIT, 0) = 0
	GROUP
		BY	TLP.ID
),
PRIMA_RIGA AS
(
SELECT	Id_Testata, MIN(LINE_ID) MIN_RIGA
FROM	Custom.RigheListePrelievo
GROUP BY Id_Testata
)
SELECT	DISTINCT
		TLP.ID,
		TLP.ORDER_ID,
		TLP.ORDER_TYPE,
		TLP.DT_EVASIONE,
		TLP.FL_KIT,
		TLP.PRIORITY,
		TSTL.Descrizione		Stato,
		TLP.COMM_SALE,
		TLP.DES_PREL_CONF,
		ISNULL(TLP.PROD_LINE,RLP.PROD_LINE)		PROD_LINE,
		TLP.DETT_ETI,
		ISNULL(RLP.DOC_NUMBER,'')				N_TICKET,
		CASE
			WHEN TLP.ORDER_TYPE = 'STS' THEN ISNULL(CTOP.DESCRIZIONE,TLP.RAD)
			ELSE ''
		END										TIPO_ORDINE,
		PTS.Prod_Order,
		RLP.LINE_ID
FROM	Custom.TestataListePrelievo					TLP
JOIN	Custom.Tipo_Stato_Testata_ListePrelievo		TSTL
ON		TLP.Stato = TSTL.Id_Stato_Testata
JOIN	Custom.RigheListePrelievo					RLP
ON		RLP.Id_Testata = tlp.ID
JOIN	PRIMA_RIGA	PR
ON		PR.Id_Testata = RLP.Id_Testata
	AND PR.MIN_RIGA = RLP.LINE_ID
JOIN	Prod_Order_ToShow							PTS
ON		PTS.ID = TLP.ID
LEFT
JOIN	Custom.Tipo_Ordini_Prelievo					CTOP
ON		CTOP.CODICE = TLP.RAD
WHERE	ISNULL(TLP.FL_KIT, 0) = 0
	AND	(
			TLP.Stato NOT IN (1,2,5)
			AND
			NOT (TLP.Stato = 3 AND TLP.ID IN (SELECT Id_Testata FROM Custom.AnagraficaMancanti WHERE Qta_Mancante > 0))
		)
GO
