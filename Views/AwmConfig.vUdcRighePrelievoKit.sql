SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE view [AwmConfig].[vUdcRighePrelievoKit] AS
SELECT      mpd.Id_Riga_Lista , 
			ut.Id_Udc,
			mpd.Id_Testata_Lista,  
			a.Id_Articolo,
			tlp.ORDER_ID, 
			tlp.ORDER_TYPE, 
			mpd.Kit_Id KIT_ID,
			rlp.PROD_LINE AS LINEA_PRODUZIONE_DESTINAZIONE, 
			rlp.PROD_ORDER as CODICE_PRODUZIONE_ERP,
			a.Codice AS CODICE_ARTICOLO, 			
			a.Descrizione AS DESCRIZIONE_ARTICOLO, 
			mpd.Quantita AS QuantitaDaPrelevare, 
            mpd.Qta_Prelevata AS QuantitaPrelevata, 
			ut2.Id_Udc AS Id_Udc_Destinazione,
			ut2.Codice_Udc AS Codice_Udc_Destinazione,	
			p2.Descrizione AS Rulliera_Destinazione,
			tlp.FL_LABEL,
			a.Unita_Misura AS UDM,
			tlp.PFIN,
			rlp.COMM_PROD,
			rlp.COMM_SALE
FROM            dbo.Eventi AS ev 
				INNER JOIN dbo.Udc_Dettaglio ut ON ut.Id_Udc = ev.Xml_Param.value('data(//Parametri//Id_Udc)[1]', 'NUMERIC(18,0)') 					
				INNER JOIN dbo.Missioni_Picking_Dettaglio mpd ON (mpd.Id_Udc = ut.Id_Udc AND mpd.Id_Testata_Lista = ev.Xml_Param.value('data(//Parametri//Id_Testata_Lista)[1]', 'INT'))								
				INNER JOIN Custom.OrdineKittingBaia okb ON (okb.Id_Testata_Lista = mpd.Id_Testata_Lista AND okb.Kit_Id = mpd.Kit_Id)
				INNER JOIN Custom.OrdineKittingUdc oku ON (oku.Id_Testata_Lista = okb.Id_Testata_Lista AND oku.Kit_Id = okb.Kit_Id)
				INNER JOIN dbo.Udc_Testata ut2  ON ut2.Id_Udc = oku.Id_Udc
				INNER JOIN dbo.Udc_Posizione up2 ON ut2.Id_Udc = up2.Id_Udc
				INNER JOIN dbo.Partizioni p2 ON p2.Id_Partizione = up2.Id_Partizione
				INNER JOIN dbo.Articoli a ON mpd.Id_Articolo = a.Id_Articolo
				INNER JOIN Custom.RigheListePrelievo rlp ON mpd.Id_Riga_Lista = rlp.ID
				INNER JOIN Custom.TestataListePrelievo tlp ON rlp.Id_Testata = tlp.ID				
WHERE        (ev.Id_Tipo_Evento = 39) AND (ev.Id_Tipo_Stato_Evento = 1) AND (mpd.Qta_Prelevata < mpd.Quantita) AND (mpd.Id_Stato_Missione NOT IN (3,4))
			 AND (oku.Stato_Udc_Kit = 1)
GROUP BY  mpd.Id_Riga_Lista , 
			ut.Id_Udc,
			mpd.Id_Testata_Lista,  
			a.Id_Articolo,
			tlp.ORDER_ID, 
			tlp.ORDER_TYPE, 
			mpd.Kit_Id ,
			rlp.PROD_LINE, 
			rlp.PROD_ORDER ,
			a.Codice, 			
			a.Descrizione , 
			mpd.Quantita, 
            mpd.Qta_Prelevata , 
			ut2.Id_Udc ,
			ut2.Codice_Udc ,	
			p2.Descrizione,
			tlp.FL_LABEL,
			a.Unita_Misura ,
			tlp.PFIN,
			rlp.COMM_PROD,
			rlp.COMM_SALE
GO
