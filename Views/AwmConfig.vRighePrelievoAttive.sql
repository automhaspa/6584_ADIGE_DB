SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vRighePrelievoAttive] AS
SELECT	mpd.Id_Udc,
		mpd.Id_Articolo,
		tlp.ID														Id_Testata_Lista,
		rlp.ID														Id_Riga_Lista,
		tlp.ORDER_ID,
		tlp.ORDER_TYPE												Causale_Lista,
		a.Codice													CODICE_ARTICOLO,
		a.Descrizione												DESCRIZIONE_ARTICOLO,
		CASE
			WHEN up.Id_Partizione = 9101														THEN 'MODULA'
			WHEN (ISNULL(vdi.ID_PARTIZIONE, 0) <> 0) OR (ISNULL(vas.ID_PARTIZIONE, 0) <> 0)		THEN
				CASE
					WHEN UT.Id_Tipo_Udc = 'M' THEN 'INGOMBRANTI_M'
					ELSE 'INGOMBRANTI'
				END
			ELSE 'AUTOMHA'
		END															Nome_Magazzino,
		CASE
			WHEN up.Id_Partizione = 9101														THEN 'MAGAZZINO MODULA'
			--Ingombrante
			WHEN ISNULL(vdi.ID_PARTIZIONE, 0) <> 0												THEN CONCAT ('SCAFFALE: ', vdi.DESCRIZIONE, ' COLONNA: ', vdi.COLONNA , ' PIANO: ', vdi.PIANO)	  
			WHEN ISNULL(vas.Id_Partizione, 0) <> 0												THEN vas.DESCRIZIONE_AREA
			ELSE p.DESCRIZIONE
		END															Posizione_Articolo,
		SUM(mpd.Quantita)											QuantitaDaPrelevare,
		SUM(mpd.Qta_Prelevata)										QuantitaPrelevata,
		CASE
			WHEN SUM(mpd.Qta_Prelevata) = 0 THEN SUM(mpd.Quantita)
			ELSE SUM(mpd.Qta_Prelevata)
		END															QUANTITA_ETICHETTA,
		CASE--UDC NON ANCORA IN MISSIONE DI UNA DETERMINATA LISTA IN STATO SOSPESO
			WHEN tlp.Stato = 5								THEN 'LISTA SOSPESA'
			WHEN p.ID_TIPO_PARTIZIONE IN ('AS', 'MI')		THEN 'PRELIEVO IN ATTESA SU BAIA INGOMBRANTI'
			WHEN mpd.Id_Udc <> 702							THEN (SELECT Descrizione FROM Custom.Tipo_Stato_PrelievoAutomha WHERE Id_Tipo_Stato_PrelievoAutomha = mpd.Id_Stato_Missione)
			WHEN mpd.Id_Udc = 702							THEN (SELECT Descrizione FROM Custom.Tipo_Stato_PrelievoModula WHERE Id_Tipo_Stato_PrelievoModula = mpd.Id_Stato_Missione)
		END															Stato,
		rlp.PROD_ORDER												CODICE_PRODUZIONE_ERP,
		rlp.PROD_LINE												LINEA_PRODUZIONE_DESTINAZIONE,
		a.Unita_Misura												UDM,
		tlp.PFIN,
		CASE
			WHEN rlp.COMM_PROD IS NOT NULL THEN rlp.COMM_PROD
			ELSE tlp.COMM_PROD
		END															COMM_PROD,
		CASE
			WHEN rlp.COMM_SALE IS NOT NULL THEN rlp.COMM_SALE
			ELSE tlp.COMM_SALE
		END															COMM_SALE,
		tlp.FL_LABEL
FROM	Missioni_Picking_Dettaglio		mpd
JOIN	Custom.RigheListePrelievo		rlp
ON		mpd.Id_Riga_Lista = rlp.ID
	AND ISNULL(MPD.FL_MANCANTI,0) = 0
JOIN	Custom.TestataListePrelievo		tlp
ON		rlp.Id_Testata = tlp.ID
JOIN	Articoli						a
ON		a.Id_Articolo = mpd.Id_Articolo
JOIN	Udc_Posizione					up
ON		up.Id_Udc = mpd.Id_Udc
JOIN	Partizioni						p
ON		up.Id_Partizione = p.ID_PARTIZIONE
JOIN	dbo.Udc_Testata					UT
ON		UT.Id_Udc = MPD.Id_Udc
LEFT
JOIN	AwmConfig.vDestinazioniIngombranti	vdi
ON		vdi.ID_PARTIZIONE = up.Id_Partizione
LEFT
JOIN	AwmConfig.vPartizioniAreeATerraScomparto	vas
ON		vas.Id_Partizione = up.Id_Partizione
WHERE	mpd.Id_Stato_Missione <> 4
	AND ISNULL(tlp.FL_KIT, 0) <> 1
GROUP
	BY	tlp.ID, tlp.ORDER_ID, tlp.ORDER_TYPE, a.Codice, a.Descrizione, mpd.Id_Articolo,
		mpd.Id_Udc, tlp.Stato ,mpd.Id_Stato_Missione, rlp.PROD_ORDER, rlp.ID,UT.Id_Tipo_Udc,
		p.DESCRIZIONE, UP.Id_Partizione, vdi.ID_PARTIZIONE, vdi.DESCRIZIONE, vdi.COLONNA , vdi.PIANO, vas.Id_Partizione, vas.DESCRIZIONE_AREA,
		rlp.PROD_LINE , rlp.PROD_ORDER, a.Unita_Misura ,tlp.PFIN,rlp.COMM_PROD,tlp.COMM_PROD, rlp.COMM_SALE, tlp.COMM_SALE, tlp.FL_LABEL,p.ID_TIPO_PARTIZIONE
GO
