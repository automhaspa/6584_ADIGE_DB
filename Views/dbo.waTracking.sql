SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO













CREATE VIEW [dbo].[waTracking]
AS
SELECT	C.DESCRIZIONE + '.' + SC.CODICE_ABBREVIATO + '.' + PT.CODICE_ABBREVIATO SORG
		,UT.Id_Udc
		,UT.Codice_Udc
		,RS.Id_Percorso
		,RS.Id_Tipo_Messaggio
		,RS.Id_Tipo_Stato_Percorso
		,RS.DEST
FROM	Partizioni PT
		INNER JOIN SottoComponenti SC ON SC.ID_SOTTOCOMPONENTE = PT.ID_SOTTOCOMPONENTE
		INNER JOIN Componenti C ON C.Id_Componente = SC.ID_COMPONENTE
		LEFT JOIN Udc_Posizione UP ON UP.Id_Partizione = PT.Id_Partizione
		LEFT JOIN Udc_Testata UT ON UT.Id_Udc = UP.Id_Udc		
		LEFT JOIN (
			SELECT	Id_Udc
					,Id_Percorso
					,Id_Tipo_Messaggio
					,CASE
						CS.Id_Tipo_Componente
						WHEN 'S' THEN 
							(
								SELECT	Id_Partizione
								FROM	Partizioni
										INNER JOIN SottoComponenti ON SottoComponenti.ID_SOTTOCOMPONENTE = Partizioni.ID_SOTTOCOMPONENTE
								WHERE	Id_Componente = SS.Id_Componente
										AND Partizioni.Codice_Abbreviato = '0000'
							)
						ELSE P.Id_Partizione_Sorgente
					END ID_PART_SORG
					,CASE
						CD.Id_Tipo_Componente
						WHEN 'S' THEN
							(
								SELECT	Id_Partizione
								FROM	Partizioni
										INNER JOIN SottoComponenti ON SottoComponenti.ID_SOTTOCOMPONENTE = Partizioni.ID_SOTTOCOMPONENTE
								WHERE	Id_Componente = SD.Id_Componente
										AND Partizioni.Codice_Abbreviato = '0000'
							)
						ELSE P.Id_Partizione_Destinazione
					END ID_PART_DEST
					,CASE ISNULL(A.AlarmId,0)
						WHEN 0 THEN 2
						ELSE 4
						END Id_Tipo_Stato_Percorso
					,SD.DESCRIZIONE + '.' + SD.CODICE_ABBREVIATO + '.' + PPD.CODICE_ABBREVIATO DEST
			FROM		Percorso P
					INNER JOIN Missioni M ON M.Id_Missione = P.Id_Percorso
					INNER JOIN Partizioni PPS ON PPS.Id_Partizione = P.Id_Partizione_Sorgente
					INNER JOIN SottoComponenti SS ON SS.ID_SOTTOCOMPONENTE = PPS.ID_SOTTOCOMPONENTE
					INNER JOIN Componenti CS ON SS.Id_Componente = CS.Id_Componente
					INNER JOIN Partizioni PPD ON PPD.Id_Partizione = P.Id_Partizione_Destinazione
					INNER JOIN SottoComponenti SD ON SD.ID_SOTTOCOMPONENTE  = PPD.ID_SOTTOCOMPONENTE
					INNER JOIN Componenti CD ON CD.ID_COMPONENTE = SD.ID_COMPONENTE
					LEFT JOIN Alarms A ON A.AlarmId = P.AlarmId 
			WHERE		Id_Tipo_Stato_Percorso = 2
		) RS ON	PT.Id_Partizione  = RS.ID_PART_SORG
WHERE	C.Id_Tipo_Componente <> 'S' OR PT.Codice_Abbreviato = '0000'













GO
