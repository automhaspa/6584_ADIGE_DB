SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





CREATE VIEW [dbo].[vEventi]
AS
	SELECT	TOP 100 PERCENT
			E.Id_Evento,
			NULLIF(E.Id_Tipo_Evento,0)										Id_Tipo_Evento,
			NULLIF(E.Id_Tipo_Stato_Evento,0)								Id_Tipo_Stato_Evento,
			NULLIF(E.Id_Partizione,0)										Id_Partizione,
			ISNULL(Pc.Ip,'')												Ip,
			E.JSON_PARAM,
			NULLIF(TE.Id_Tipo_Gestore_Eventi,'')							Id_Tipo_Gestore_Eventi,
			CONCAT(TE.Descrizione, ' - ', SUBSTRING(P.Descrizione,1,4))		Descrizione_Evento,
			CASE E.Id_Tipo_Evento
				WHEN 14 THEN '#Rejection'
				ELSE TE.Azione_Evento
			END																Azione_Evento,
			UT.Codice_Udc,
			UT.Id_Udc,
			B.Descrizione													Descrizione_Baia
	FROM	dbo.Eventi			E
	JOIN	dbo.Tipo_Eventi		TE
	ON		E.Id_Tipo_Evento = TE.Id_Tipo_Evento
	JOIN	dbo.Partizioni		P
	ON		E.Id_Partizione = P.Id_Partizione
	JOIN	dbo.Baie			B
	ON		P.Id_Partizione = B.Id_Partizione
	JOIN	dbo.Pc
	ON		B.Id_Pc = Pc.Id_Pc
	LEFT
	JOIN	dbo.Udc_Testata		UT
	ON		E.Xml_Param.value('data(//Parametri//Id_Udc)[1]','NUMERIC(18,0)') = UT.Id_Udc
	WHERE	E.Id_Tipo_Stato_Evento = 1
	ORDER
		BY	ROW_NUMBER() OVER (ORDER BY CASE WHEN ISNULL(E.Id_Evento_Padre,0) = 0 THEN E.Id_Evento ELSE e.Id_Evento * -1 END)
	--OFFSET 0 ROWS
GO
