SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vRigheKittingAttive] AS
SELECT	tlp.ID														Id_Testata,
		tlp.ORDER_ID												Codice_Lista,
		tlp.ORDER_TYPE												Causale_Lista,
		a.Codice													Codice_Articolo,
		a.Descrizione												Descrizione_Articolo,
		CASE
			WHEN mpd.Id_Udc = 702	THEN 'MAGAZZINO MODULA'
			WHEN mpd.Id_Udc <> 702	THEN p.DESCRIZIONE
		END															PosizioneArticolo,
		SUM(mpd.Quantita)											Qta_DaPrelevare, 
		SUM(mpd.Qta_Prelevata)										Qta_Prelevata,
		CASE
			WHEN mpd.Id_Udc = 702	THEN 'MODULA'
			WHEN mpd.Id_Udc <> 702	THEN 'MAGAZZINO AUTOMHA'
		END															Magazzino,
		--UDC NON ANCORA IN MISSIONE DI UNA DETERMINATA LISTA IN STATO SOSPESO
		CASE
			WHEN tlp.Stato = 5 AND mpd.Id_Stato_Missione = 1	THEN 'LISTA KITTING SOSPESA'
			WHEN mpd.Id_Udc <> 702								THEN (SELECT Descrizione FROM Custom.Tipo_Stato_PrelievoAutomha WHERE Id_Tipo_Stato_PrelievoAutomha = mpd.Id_Stato_Missione)
			WHEN mpd.Id_Udc = 702								THEN (SELECT Descrizione FROM Custom.Tipo_Stato_PrelievoModula WHERE Id_Tipo_Stato_PrelievoModula = mpd.Id_Stato_Missione)
		END															Stato,
		rlp.KIT_ID,
		rlp.PROD_ORDER												Codice_Produzione_Erp
FROM	Missioni_Picking_Dettaglio							mpd
JOIN	Custom.RigheListePrelievo							rlp
ON		mpd.Id_Riga_Lista = rlp.ID
JOIN	Custom.TestataListePrelievo							tlp
ON		rlp.Id_Testata = tlp.ID
JOIN	Articoli											a
ON		a.Id_Articolo = mpd.Id_Articolo
LEFT
JOIN	Udc_Posizione										up
on		up.Id_Udc = mpd.Id_Udc
LEFT
JOIN	Partizioni											p
on		up.Id_Partizione = p.ID_PARTIZIONE
WHERE	mpd.Id_Stato_Missione NOT IN (3,4)
	AND mpd.Kit_Id > 0
GROUP
	BY	tlp.ID, tlp.ORDER_ID, tlp.ORDER_TYPE, a.Codice, a.Descrizione, mpd.Id_Udc, tlp.Stato,
		mpd.Id_Stato_Missione, rlp.PROD_ORDER,p.DESCRIZIONE,rlp.KIT_ID
GO
