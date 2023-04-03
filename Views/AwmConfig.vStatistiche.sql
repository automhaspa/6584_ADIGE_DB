SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vStatistiche]
AS

SELECT	ISNULL(ROW_NUMBER() OVER (ORDER BY PVT.DATA ASC),0) Id,
		DATA												Data_Ora,
		SUM(PVT.ING)										numING,
		SUM(PVT.OUP)										numOUP,
		SUM(PVT.OUL)										numOUL,
		SUM(PVT.MTM)										numMTM,
		SUM(PVT.SPC)										numSPC,
		SUM(PVT.SCA)										numSCA,
		--,SUM(PVT.RCS) numRCS
		DATEDIFF(HOUR,MIN(PVT.MinData),MAX(PVT.MaxData))	HH
FROM	(
			SELECT	CONVERT(DATE,Data)	DATA,
					COUNT(Id_Missione)	#,
					Id_Tipo_Missione,
					MIN(Data)			MinData,
					MAX(Data)			MaxData
			FROM	dbo.Missioni_Storico
			JOIN	dbo.Partizioni PS ON ID_PARTIZIONE_SORGENTE = PS.ID_PARTIZIONE
			JOIN	dbo.Partizioni PD ON PD.ID_PARTIZIONE = ID_PARTIZIONE_DESTINAZIONE
			WHERE	'MA' IN (PS.ID_TIPO_PARTIZIONE, PD.ID_TIPO_PARTIZIONE)
				AND Stato_Missione = 'TOK'
			GROUP
				BY	CONVERT(DATE,Data),Id_Tipo_Missione
		) T
		PIVOT
		(
			SUM(#)
			FOR Id_Tipo_Missione IN (ING, OUP, OUL, OUC, MTM, SPC, SCA)
		) PVT
GROUP BY PVT.DATA
GO
