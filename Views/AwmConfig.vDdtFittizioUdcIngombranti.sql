SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vDdtFittizioUdcIngombranti] AS
SELECT	ut.Id_Ddt_Fittizio,
		ut.Id_Udc,
		up.Id_Partizione,
		ad.Codice_DDT,
		ut.Codice_Udc,
		ad.DataOra_Creazione,
		p.DESCRIZIONE				POSIZIONE_STOCCAGGIO,
		UT.Id_Tipo_Udc
FROM	Udc_Testata					ut
JOIN	Custom.AnagraficaDdtFittizi ad
ON		ut.Id_Ddt_Fittizio = ad.ID
JOIN	Udc_Posizione				up
ON		up.Id_Udc = ut.Id_Udc
JOIN	Partizioni					p
ON		up.Id_Partizione = p.ID_PARTIZIONE
WHERE	ut.Id_Tipo_Udc IN ('I','M')
	AND ISNULL(ut.Specializzazione_Completa, 0) = 0
GO
