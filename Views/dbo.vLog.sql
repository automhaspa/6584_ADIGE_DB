SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW [dbo].[vLog]
AS
	SELECT	ISNULL(T.Id,0)											AS Id,
			NULLIF(ISNULL(T.DATA_ORA,GETDATE()),GETDATE())			AS DATA_ORA,
			ISNULL(CONVERT(VARCHAR(500),T.logTYPE),'')				AS logType,
			T.subType,
			SUBSTRING(P.DESCRIZIONE,1,4)							AS Asi,
			T.Id_Udc,
			UT.Codice_Udc,
			CAST (T.XmlContent AS XML)								AS XmlContent,
			T.[Status],
			T.Summary
	FROM	(
				SELECT	MI.ID_MESSAGGIO																																AS Id,
						MI.DATA_ORA,
						'MSG SND'																																	AS logTYPE,
						MI.ID_TIPO_MESSAGGIO																														AS subType,
						CONVERT(VARCHAR(MAX),MI.Messaggio)																											AS XmlContent,
						MI.ID_PARTIZIONE,
						MI.MESSAGGIO.value('data(//LU_ID_1)[1]','INT')																								AS Id_Udc,
						CASE MI.ID_TIPO_STATO_MESSAGGIO 
							WHEN 3 THEN 'PROCESSED' 
							WHEN 2 THEN 'RUNNING' 
							WHEN 1 THEN 'WAITING'
							WHEN 9 THEN 'ERROR'
						END																																			AS [Status],
						CASE MI.ID_TIPO_MESSAGGIO --.MESSAGGIO.value('(//TypeMessage/@id)[1]', 'varchar(5)')
							------------------------------------------------------------------------------------------------------------
							WHEN 12020 THEN		+ 'SORG: ' + MI.MESSAGGIO.value('data(//LU_SOURCE_ASI_1)[1]','Varchar(4)') + '.' 
												+ MI.MESSAGGIO.value('data(//LU_SOURCE_SUBITEM_1)[1]','Varchar(4)') + '.' 
												+ MI.MESSAGGIO.value('data(//LU_SOURCE_PARTITION_1)[1]','Varchar(4)')
												+ ' - DEST: ' + MI.MESSAGGIO.value('data(//LU_DEST_ASI_1)[1]','Varchar(4)') + '.' 
												+ MI.MESSAGGIO.value('data(//LU_DEST_SUBITEM_1)[1]','Varchar(4)') + '.' 
												+ MI.MESSAGGIO.value('data(//LU_DEST_PARTITION_1)[1]','Varchar(4)')
							------------------------------------------------------------------------------------------------------------
							WHEN 12031 THEN		+ 'Richiesta dati a LIV 1' 
							------------------------------------------------------------------------------------------------------------
						END																																			AS Summary 
				FROM	Messaggi_Inviati																								AS MI	WITH(NOLOCK) 
				WHERE	DATEPART(DAY,DATA_ORA) = DATEPART(DAY,GETDATE())
				/**********************************************************************************************************************************************************************************/
				UNION 
				/**********************************************************************************************************************************************************************************/
				SELECT	MR.ID_MESSAGGIO																																AS Id,
						MR.DATA_ORA,
						'MSG RCV'																																	AS logTYPE,
						MR.ID_TIPO_MESSAGGIO																														AS subType,
						CONVERT(VARCHAR(MAX),MR.Messaggio)																											AS XmlContent,
						MR.ID_PARTIZIONE,
						MR.MESSAGGIO.value('data(//LU_NO_1)[1]','INT')																								AS Id_Udc,
						CASE MR.ID_TIPO_STATO_MESSAGGIO 
							WHEN 3 THEN 'PROCESSED' 
							WHEN 2 THEN 'RUNNING' 
							WHEN 1 THEN 'WAITING' 
							WHEN 9 THEN 'ERROR'
						END																																			AS [Status],
						CASE MR.ID_TIPO_MESSAGGIO
							------------------------------------------------------------------------------------------------------------
							WHEN 11031 THEN		'LU_CODE: ' + MR.MESSAGGIO.value('data(//LU_CODE)[1]','Varchar(50)')
												+ ' - HEIGHT: ' + MR.MESSAGGIO.value('data(//LU_HEIGHT)[1]','Varchar(50)') + 
												+ ' - WIDTH: ' + MR.MESSAGGIO.value('data(//LU_WIDTH)[1]','Varchar(50)') + 
												+ ' - LENGTH: ' + MR.MESSAGGIO.value('data(//LU_LENGTH)[1]','Varchar(50)')
							------------------------------------------------------------------------------------------------------------
							WHEN 11023 THEN		'RESULT: ' + MR.MESSAGGIO.value('data(//MISSION_RESULT)[1]','Varchar(1)') 
												+ ' - ERROR: ' + MR.MESSAGGIO.value('data(//MISSION_ERROR)[1]','Varchar(50)') + 
												+ ' - DEST: ' + ISNULL(MR.MESSAGGIO.value('data(//LU_FINAL_POS_ASI_1)[1]','Varchar(4)'),'') + '.' 
												+ ISNULL(MR.MESSAGGIO.value('data(//LU_FINAL_POS_SUBITEM_1)[1]','Varchar(4)'),'') + '.' 
												+ ISNULL(MR.MESSAGGIO.value('data(//LU_FINAL_POS_PARTITION_1)[1]','Varchar(4)'),'')
							------------------------------------------------------------------------------------------------------------
						END																																			AS Summary
				FROM	Messaggi_Ricevuti																								AS MR	WITH(NOLOCK) 
				WHERE	DATEPART(DAY,DATA_ORA) = DATEPART(DAY,GETDATE())
				/**********************************************************************************************************************************************************************************/
				UNION 
				/**********************************************************************************************************************************************************************************/
				SELECT	MS.Id_Missione																																AS Id,
						MS.Data																																		AS DATA_ORA,
						'MISSIONE'																																	AS logTYPE,
						MS.Id_Tipo_Missione																															AS subType,
						''																																			AS XmlContent,
						NULL																																		AS ID_PARTIZIONE,
						MS.Id_Udc,
						CASE Stato_Missione 
							WHEN 'TOK' THEN 'PROCESSED' 
							WHEN 'DEL' THEN 'DELETED' 
							WHEN 'IMP' THEN 'ERROR' 
						END																																			AS [Status], 
						--'SORG: ' + CAST(ID_PARTIZIONE_SORGENTE AS VARCHAR(14))  + ' - ' + 'DEST: ' + CAST(ID_PARTIZIONE_DESTINAZIONE AS VARCHAR(14))				AS Summary
						'SORG: ' + SUBSTRING(PS.DESCRIZIONE,1,4)  + ' - ' + 'DEST: ' + SUBSTRING(PD.DESCRIZIONE,1,4)				AS Summary
				FROM	Missioni_Storico														AS MS	WITH(NOLOCK)
				JOIN	Partizioni																AS PS	WITH(NOLOCK)
				ON		PS.ID_PARTIZIONE = MS.ID_PARTIZIONE_SORGENTE
				JOIN	Partizioni																AS PD	WITH(NOLOCK)
				ON		PD.ID_PARTIZIONE = MS.ID_PARTIZIONE_DESTINAZIONE
				WHERE	DATEPART(MONTH,Data) >= DATEPART(MONTH,GETDATE())
					AND MS.Id_Udc IN (SELECT ID_UDC FROM Udc_Testata)
					AND 'MA' IN (PD.ID_TIPO_PARTIZIONE,PS.ID_TIPO_PARTIZIONE)
				/**********************************************************************************************************************************************************************************/
				UNION 
				/**********************************************************************************************************************************************************************************/
				SELECT	ROW_NUMBER() OVER (ORDER BY L.DataOra_Log ASC)		AS Id,
						L.DataOra_Log										AS DATA_ORA,
						'LOG'												AS logTYPE,
						CASE Id_Tipo_Log
							WHEN 16 THEN 'ACTION'
							WHEN 4 THEN 'ERROR'
						END													AS subType,
						''													AS XmlContent,
						NULL												AS ID_PARTIZIONE,
						NULL												AS Id_Udc,
						NULL												AS [Status],
						CASE 
							WHEN L.Origine_Log LIKE '%l3integration%' THEN CONCAT('PROCEDURA: ', L.Proprietà_Log ,'   ', CONVERT(VARCHAR(MAX),Messaggio))
							ELSE CONVERT(VARCHAR(MAX),Messaggio)
						END						AS Summary
				FROM	Log																AS L	WITH(NOLOCK) 
				WHERE	L.Origine_Log NOT IN ('sp_Elabora_Missioni')
					AND L.Proprietà_Log NOT IN ('TEMPISTICHE')
					AND DATEPART(MONTH,DataOra_Log) >= DATEPART(MONTH,GETDATE())-1
		) T 
		LEFT 
		JOIN	dbo.Udc_Testata			UT 
		ON		UT.Id_Udc = T.Id_Udc
		LEFT 
		JOIN	Partizioni	P 
		ON		P.ID_PARTIZIONE = T.ID_PARTIZIONE
GO
