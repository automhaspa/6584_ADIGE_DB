SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW [Compartment].[vAvailableContainersInUdc]
AS
	SELECT		SA.ID_AREA,
				UT.Id_Udc,
				UT.Codice_Udc,
				Cont.Id_Container,
				Cont.Description,
				NULLIF(Cont.Width,0) AS Width,
				NULLIF(Cont.Depth,0) AS Depth,
				Cont.Height,
				UC.Id_UdcContainer
	FROM		dbo.Udc_Testata AS UT
	INNER JOIN	Compartment.UdcContainer AS UC ON UC.Id_Udc = UT.Id_Udc
	INNER JOIN  Compartment.Container AS Cont ON Cont.Id_Container = UC.Id_Container
	INNER JOIN	dbo.Udc_Posizione UP ON UP.Id_Udc = UT.Id_Udc
	INNER JOIN	dbo.Partizioni P ON P.ID_PARTIZIONE = UP.Id_Partizione
	INNER JOIN	dbo.SottoComponenti SC ON SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
	INNER JOIN	dbo.Componenti C ON C.ID_COMPONENTE = SC.ID_COMPONENTE
	INNER JOIN	dbo.SottoAree SA ON SA.ID_SOTTOAREA = C.ID_SOTTOAREA
	WHERE		NOT EXISTS (SELECT 1 FROM dbo.Udc_Dettaglio AS UD WHERE UC.Id_UdcContainer = UD.Id_UdcContainer AND UT.Id_Udc = UD.Id_Udc)
GO
