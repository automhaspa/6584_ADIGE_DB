SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE VIEW [AwmConfig].[vMancanti_Storico] AS
SELECT	ISNULL(tlp.ID,AM.Id_Testata)										Id_Testata,
		am.Id_Riga															Id_Riga,
		ISNULL(tlp.ORDER_ID,AM.ORDER_ID)									ORDER_ID,
		ISNULL(tlp.ORDER_TYPE, AM.ORDER_TYPE)								ORDER_TYPE,
		ISNULL(tlp.DT_EVASIONE,AM.DT_EVASIONE)								DT_EVASIONE,
		ISNULL(tlp.COMM_PROD,AM.COMM_PROD)									COMM_PROD,
		ISNULL(tlp.COMM_SALE,AM.COMM_SALE)									COMM_SALE,
		AM.PROD_LINE														PROD_LINE,
		ISNULL(AM.PROD_ORDER,'')											PROD_ORDER,
		A.Codice															Codice_Articolo,
		A.Descrizione														Descrizione_Articolo
FROM	Custom.AnagraficaMancanti		am
JOIN	dbo.Articoli					a
ON		a.Id_Articolo = am.Id_Articolo
LEFT
JOIN	Custom.TestataListePrelievo		tlp
ON		am.Id_Testata = tlp.ID
WHERE	am.Qta_Mancante <= 0
GROUP
	BY	ISNULL(tlp.ID,AM.Id_Testata),
		am.Id_Riga,
		ISNULL(tlp.ORDER_ID,AM.ORDER_ID),
		ISNULL(tlp.ORDER_TYPE, AM.ORDER_TYPE),
		ISNULL(tlp.DT_EVASIONE,AM.DT_EVASIONE),
		ISNULL(tlp.COMM_PROD,AM.COMM_PROD),
		ISNULL(tlp.COMM_SALE,AM.COMM_SALE),
		AM.PROD_LINE,
		ISNULL(AM.PROD_ORDER,''),
		A.Codice,
		A.Descrizione
GO
