SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vBolleFittizieCompleta] AS
--CTE CON QUELLO CHE C'è NELLE SOTTOQUERY GROUP BY ID DDT
SELECT	ID,
		Codice_DDT												CODICE_DDT,
		DataOra_Creazione										DATA_CREAZIONE,
		N_Udc_Tipo_A -	(
							SELECT	COUNT(1)
							FROM    Udc_Posizione		up
							JOIN	Udc_Testata			ut
							ON		up.Id_Udc = ut.Id_Udc
							WHERE   (up.Id_Partizione <> 3101)
								AND (ut.Id_Ddt_Fittizio = ID)
								AND ut.Id_Tipo_Udc IN ('1','2','3')
						)										UDC_TIPO_A_DA_ANAGRAFARE,
		N_Udc_Tipo_B -	(
							SELECT	COUNT(1)
							FROM	Udc_Posizione		up
							JOIN	Udc_Testata			ut
							ON		up.Id_Udc = ut.Id_Udc
							WHERE	(up.Id_Partizione <> 3101)
								AND (ut.Id_Ddt_Fittizio = ID)
								AND ut.Id_Tipo_Udc IN ('4','5','6')
						)
																UDC_TIPO_B_DA_ANAGRAFARE
FROM	Custom.AnagraficaDdtFittizi
WHERE	Id_Stato = 1
GO
