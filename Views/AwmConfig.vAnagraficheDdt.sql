SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE VIEW [AwmConfig].[vAnagraficheDdt]
AS
	SELECT	addt.ID,
			addt.Codice_DDT,
			CAST(addt.DataOra_Creazione AS DATE)		DataCreazione,
			addt.N_Udc_Tipo_A,
			addt.N_Udc_Tipo_B,
			addt.N_Udc_Ingombranti,
			addt.N_Udc_Ingombranti_M,
			COUNT(toe.ID)								Numero_Ddt_Erp_Associati,
			ta.Descrizione								Stato
	FROM	Custom.AnagraficaDdtFittizi		addt
	JOIN	Custom.TipoStatoAnagrafica		ta
	ON		addt.Id_Stato = ta.ID
	LEFT
	JOIN	Custom.TestataOrdiniEntrata		toe
	ON		addt.ID = toe.Id_Ddt_Fittizio
	WHERE	ADDT.Codice_DDT NOT LIKE 'WBS%'
		AND	ADDT.Codice_DDT NOT LIKE 'AWM%'
		AND ADDT.Id_Stato IN (1,2,5)
	GROUP
		BY	addt.ID,
			addt.Codice_DDT,
			addt.DataOra_Creazione,
			addt.N_Udc_Tipo_A,
			addt.N_Udc_Tipo_B,
			addt.N_Udc_Ingombranti,
			addt.N_Udc_Ingombranti_M,
			ta.Descrizione
GO
