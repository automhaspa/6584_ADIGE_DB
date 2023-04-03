SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vPartizioni] 
AS
	SELECT	A.ID_AREA,
			C.ID_SOTTOAREA,
			C.ID_COMPONENTE,
			P.ID_SOTTOCOMPONENTE,
			P.ID_PARTIZIONE,
			CASE
				WHEN (ISNULL(nsa.Codice_Area,'') <> '' AND ISNULL(npa.Codice_Sottoarea,'') <> '') THEN CONCAT(nsa.Codice_Area, ' ' ,NPA.Codice_Sottoarea)
				WHEN (ISNULL(nsa.Codice_Area,'') <> '' AND ISNULL(npa.Codice_Sottoarea,'') = '') THEN nsa.Codice_Area
				ELSE A.CODICE_ABBREVIATO + SA.CODICE_ABBREVIATO + C.CODICE_ABBREVIATO + '.' + SC.CODICE_ABBREVIATO + '.' + P.CODICE_ABBREVIATO
			END										CODPLC,
			P.ID_TIPO_PARTIZIONE,
			P.DESCRIZIONE,
			SC.COLONNA,
			SC.PIANO,
			P.LOCKED,
			P.Motivo_Blocco,
			CAST(CASE WHEN COUNT(UP.ID_UDC) = 0 THEN 1 ELSE 0 END AS BIT)				VUOTA,
			COUNT(UP.ID_UDC)															NAROLI_LuNo,
			CAST(CASE WHEN ISNULL(MAX(CAST(FT.Flag_Attivo AS INT)),0) = 0 THEN 0 ELSE 1 END AS BIT)	ricalcoloAvailable,
			A.Codice_Abbreviato + SA.Codice_Abbreviato + C.Codice_Abbreviato ASI,
			SC.Codice_Abbreviato SUBITEM,
			P.Codice_Abbreviato [PARTITION],
			P.Altezza,
			P.Larghezza,
			P.Profondita,
			P.PESO,
			C.ID_TIPO_COMPONENTE,
			TP.DESCRIZIONE				TIPO_PARTIZIONE
	FROM	dbo.Partizioni							P
	JOIN	dbo.Tipo_Partizioni						TP
	ON		TP.ID_TIPO_PARTIZIONE = P.ID_TIPO_PARTIZIONE
	JOIN	dbo.SottoComponenti						SC
	ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
	JOIN	dbo.Componenti							C
	ON		C.ID_COMPONENTE = SC.ID_COMPONENTE
	JOIN	dbo.SottoAree							SA
	ON		SA.ID_SOTTOAREA = C.ID_SOTTOAREA
	JOIN	dbo.Aree								A
	ON		A.ID_AREA = SA.ID_AREA
	LEFT
	JOIN	Custom.NomenclaturaPartizAreeTerra		NPA
	ON		NPA.Id_Partizione = P.ID_PARTIZIONE
	LEFT
	JOIN	Custom.NomenclaturaSottoCompAreeTerra	NSA
	ON		NSA.Id_Sottocomponente = P.ID_SOTTOCOMPONENTE
	LEFT
	JOIN	Udc_Posizione							UP
	ON		UP.Id_Partizione = P.ID_PARTIZIONE
	LEFT
	JOIN	fnTempo									FT
	ON		FT.Id_Partizione_Baia = P.ID_PARTIZIONE
	WHERE	P.ID_TIPO_PARTIZIONE <> 'OO'
		AND	P.CODICE_ABBREVIATO <> '0000'
	GROUP
		BY	A.ID_AREA,
			C.ID_SOTTOAREA,
			C.ID_COMPONENTE,
			P.ID_SOTTOCOMPONENTE,
			P.ID_PARTIZIONE,
			CASE
				WHEN ISNULL(NSA.Codice_Area,'') <> '' AND ISNULL(NPA.Codice_Sottoarea,'') <> ''	THEN CONCAT(nsa.Codice_Area, ' ' ,NPA.Codice_Sottoarea)
				WHEN ISNULL(nsa.Codice_Area,'') <> '' AND ISNULL(npa.Codice_Sottoarea,'') = ''	THEN nsa.Codice_Area
				ELSE A.CODICE_ABBREVIATO + SA.CODICE_ABBREVIATO + C.CODICE_ABBREVIATO + '.' + SC.CODICE_ABBREVIATO + '.' + P.CODICE_ABBREVIATO
			END,
			P.ID_TIPO_PARTIZIONE,
			P.DESCRIZIONE,
			SC.COLONNA,
			SC.PIANO,
			P.LOCKED,
			P.Motivo_Blocco,
			A.Codice_Abbreviato + SA.Codice_Abbreviato + C.Codice_Abbreviato,
			SC.Codice_Abbreviato,
			P.Codice_Abbreviato,
			P.Altezza,
			P.Larghezza,
			P.Profondita,
			P.PESO,
			C.ID_TIPO_COMPONENTE,
			TP.DESCRIZIONE
GO
