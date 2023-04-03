SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vArticoliUdcAllocazioniPref] AS
SELECT	Id_Udc,
		ud.Id_Articolo,
		npa.Id_Partizione,
		a.Codice,
		a.Descrizione,
		CONCAT(nsc.Codice_Area, ' - ', npa.Codice_Sottoarea)		AREA_ALLOCAZIONE_PREFERENZIALE
FROM	Eventi				ev
JOIN	Udc_Dettaglio		ud
ON		ud.Id_Udc = ev.Xml_Param.value('data(//Parametri//Id_Udc)[1]','INT')
JOIN	Articoli			a
ON		a.Id_Articolo = ud.Id_Articolo
LEFT
JOIN	Custom.AllocazionePreferenzAreeTerra	alt
ON		ud.Id_Articolo = alt.Id_Articolo
LEFT
JOIN	Custom.NomenclaturaPartizAreeTerra		npa
ON		npa.Id_Partizione = alt.Id_Partizione
LEFT
JOIN	Partizioni								p
ON		npa.Id_Partizione = p.ID_PARTIZIONE
LEFT
JOIN	Custom.NomenclaturaSottoCompAreeTerra	nsc
ON		nsc.Id_Sottocomponente = p.ID_SOTTOCOMPONENTE
WHERE	ISNULL(alt.Id_Partizione, 0) <> 0
GROUP
	BY	Id_Udc,
		ud.Id_Articolo,
		npa.Id_Partizione,
		a.Codice,
		a.Descrizione,
		nsc.Codice_Area,
		npa.Codice_Sottoarea
GO
