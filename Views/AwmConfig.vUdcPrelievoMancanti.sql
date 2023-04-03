SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vUdcPrelievoMancanti] AS
SELECT	ud.Id_Udc,
		a.Id_Articolo,
		ud.Id_UdcDettaglio,
		am.Id_Testata, 
		am.Id_Riga, 
		ISNULL(tlp.ORDER_ID, '')	ORDER_ID,
		ISNULL(tlp.ORDER_TYPE,'')	ORDER_TYPE,
		am.PROD_LINE,
		CAST(ISNULL(tlp.DT_EVASIONE,GETDATE()) AS date)	DT_EVASIONE,
		ISNULL(AM.PROD_ORDER,'')		PROD_ORDER,
		a.Codice						CODICE_ARTICOLO, 
		a.Descrizione					DESCRIZIONE,
		SUM(am.Qta_Mancante)			QUANTITA_MANCANTE,
		CAST(ud.Quantita_Pezzi - ISNULL(cq.Quantita, 0) - ISNULL(NC.Quantita,0) AS numeric(10,2))		QUANTITA_PRESENTE_SU_UDC,
		CASE
			WHEN SUM(am.Qta_Mancante) > (ud.Quantita_Pezzi - ISNULL(cq.Quantita, 0) - ISNULL(NC.Quantita,0)) THEN (ud.Quantita_Pezzi - ISNULL(cq.Quantita, 0) - ISNULL(NC.Quantita,0))
			WHEN SUM(am.Qta_Mancante) <= (ud.Quantita_Pezzi - ISNULL(cq.Quantita, 0) - ISNULL(NC.Quantita,0)) THEN SUM(am.Qta_Mancante)	   
		END								QUANTITA_ETICHETTA,
		tlp.FL_LABEL,
		a.Unita_Misura					UDM,
		tlp.PFIN,
		ISNULL(AM.COMM_PROD,tlp.COMM_PROD)	COMM_PROD,
		ISNULL(AM.COMM_SALE,tlp.COMM_SALE)	COMM_SALE,
		cast(null as varchar(40))			DOC_NUMBER, --rlp.DOC_NUMBER,
		ISNULL(ud.Id_Ddt_Reale, 0)			Id_Ddt_Reale,
		ISNULL(ud.Id_Riga_Ddt,0)			Id_Riga_Ddt
FROM	Eventi e
JOIN	Udc_Dettaglio ud ON (ud.Id_Udc = e.Xml_Param.value('data(//Parametri//Id_Udc)[1]','INT') AND ud.Id_Articolo = e.Xml_Param.value('data(//Parametri//Id_Articolo)[1]','INT'))
JOIN	Custom.AnagraficaMancanti am ON am.Id_Articolo = e.Xml_Param.value('data(//Parametri//Id_Articolo)[1]','INT')
JOIN	Articoli a ON a.Id_Articolo = am.Id_Articolo
LEFT
JOIN	Custom.TestataListePrelievo tlp ON am.Id_Testata = tlp.ID
--JOIN	Custom.RigheListePrelievo rlp ON am.Id_Riga = rlp.ID
LEFT	JOIN Custom.ControlloQualita cq ON cq.Id_UdcDettaglio = ud.Id_UdcDettaglio
LEFT	JOIN Custom.NonConformita nc ON nc.Id_UdcDettaglio  = ud.Id_UdcDettaglio
WHERE	am.Qta_Mancante > 0 AND ud.Quantita_Pezzi > 0
GROUP
	BY	ud.Id_Udc, a.Id_Articolo,
		ud.Id_UdcDettaglio, am.Id_Testata, am.Id_Riga,tlp.DT_EVASIONE, tlp.ORDER_ID, tlp.ORDER_TYPE, AM.PROD_LINE, AM.PROD_ORDER, a.Codice, a.Descrizione,
		ud.Quantita_Pezzi, cq.Quantita, NC.Quantita, A.Unita_Misura, tlp.PFIN, AM.PROD_ORDER,
		ISNULL(AM.COMM_PROD,tlp.COMM_PROD),
		ISNULL(AM.COMM_SALE,tlp.COMM_SALE),
		ud.Id_Ddt_Reale,
		ud.Id_Riga_Ddt, tlp.FL_LABEL--, RLP.DOC_NUMBER
GO
