SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW [AwmConfig].[vAnagraficheDdt_Storico]
AS
WITH DDT_ATTIVI AS
(
	SELECT	Id_Ddt_Fittizio
	FROM	Custom.TestataOrdiniEntrata
	WHERE	Stato IN (1,2)
)
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
	LEFT
	JOIN	DDT_ATTIVI						DA
	ON		DA.Id_Ddt_Fittizio = addt.ID
	WHERE	ADDT.Codice_DDT NOT LIKE 'WBS%'
		AND ADDT.Id_Stato NOT IN (1,2)
		AND DA.Id_Ddt_Fittizio IS NULL
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
