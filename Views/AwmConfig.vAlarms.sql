SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO











CREATE VIEW [AwmConfig].[vAlarms]
AS
	SELECT	Alarms.AlarmId
			,Percorso.Direzione
			,Id_Missione
			,Percorso.Sequenza_Percorso
			,ErrorCodeId
			,ResourceName
			,CASE 
				WHEN SS.Piano IS NULL THEN SUBSTRING(PS.Descrizione,1,4) 
				ELSE PS.Descrizione + ' (Liv:' + CONVERT(VARCHAR,SS.Piano) + ' Col:' + CONVERT(VARCHAR,SS.Colonna) + ')' 
			 END Sorgente
			,CASE 
				WHEN SD.Piano IS NULL THEN SUBSTRING(PD.Descrizione,1,4) 
				ELSE PD.Descrizione +  ' (Liv:' + CONVERT(VARCHAR,SD.Piano) + ' Col:' + CONVERT(VARCHAR,SD.Colonna) + ')' 
			 END Destinazione
			,UDC_TESTATA.Codice_Udc
			,Missioni.Id_Udc
	FROM	Alarms
			INNER JOIN Tipo_ErrorCode TE ON TE.Id_ErrorCode = Alarms.ErrorCodeId
			INNER JOIN Percorso ON Percorso.AlarmId = Alarms.AlarmId
			INNER JOIN Missioni ON PERCORSO.ID_PERCORSO = MISSIONI.ID_MISSIONE
			INNER JOIN UDC_TESTATA ON UDC_TESTATA.ID_UDC = MISSIONI.ID_UDC
			INNER JOIN Partizioni PS ON Percorso.Id_Partizione_Sorgente = PS.Id_Partizione
			INNER JOIN SottoComponenti SS ON SS.Id_SottoComponente = PS.Id_SottoComponente
			INNER JOIN Partizioni PD ON Percorso.Id_Partizione_Destinazione = PD.Id_Partizione
			INNER JOIN SottoComponenti SD ON SD.Id_SottoComponente = PD.Id_SottoComponente
	WHERE	Percorso.Id_Tipo_Stato_Percorso = 2



GO
