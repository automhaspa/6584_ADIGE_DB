SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vUdcDaCompattare]
AS

SELECT	DISTINCT
		UT.Id_Udc,
		UT.Codice_Udc,
		TU.Descrizione		Tipo_Udc,
		P.Descrizione		Posizione,
		UT.Id_Ddt_Fittizio,
		UT.Altezza,
		UT.Larghezza,
		UT.Profondita,
		UT.Peso,
		UP.QuotaDepositoX QuotaDeposito,
		UT.Blocco_Udc,
		UT.emptyUdc,
		SC.PIANO,
		SC.COLONNA,
		C.ID_SOTTOAREA
FROM	dbo.Udc_Testata			UT
JOIN	dbo.Udc_Posizione		UP
ON		UT.Id_Udc = UP.Id_Udc
	AND UT.Id_Tipo_Udc NOT IN ('I','M')
	AND ISNULL(UT.Da_Compattare,0) = 1
JOIN	dbo.Partizioni			P
ON		UP.Id_Partizione = P.Id_Partizione
JOIN	dbo.SottoComponenti		SC
ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
JOIN	dbo.Componenti			C
ON		C.ID_COMPONENTE = SC.ID_COMPONENTE
JOIN	dbo.Tipo_Udc			TU
ON		UT.Id_Tipo_Udc = TU.Id_Tipo_Udc
WHERE	p.Id_Tipo_Partizione NOT IN ('AT','AP')

GO
