SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vPartizioniAreeATerraScomparto]
AS 
	SELECT	P.ID_PARTIZIONE											Id_Partizione,
			CONCAT( nsc.Codice_Area, ' - ', npa.Codice_Sottoarea)	DESCRIZIONE_AREA
	FROM	Custom.NomenclaturaPartizAreeTerra		NPA
	JOIN	Partizioni								P
	ON		NPA.Id_Partizione = P.ID_PARTIZIONE
	JOIN	Custom.NomenclaturaSottoCompAreeTerra	NSC
	ON		NSC.Id_Sottocomponente = P.ID_SOTTOCOMPONENTE
GO
