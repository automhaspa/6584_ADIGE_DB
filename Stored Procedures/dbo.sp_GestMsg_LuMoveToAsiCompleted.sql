SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROC [dbo].[sp_GestMsg_LuMoveToAsiCompleted]
@Id_Messaggio	INT
-- Parametri Standard;
,@Id_Processo		VARCHAR(30)	
,@Origine_Log		VARCHAR(25)	
,@Id_Utente			VARCHAR(32)		
,@Errore			VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
	SET LOCK_TIMEOUT 5000

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @XmlMessage xml
		DECLARE @Asi Varchar(4)
		DECLARE @ErrorCode Int
		DECLARE @Id_Partizione Int
		DECLARE @Esistenza_Parametro Bit
		DECLARE @ErrorCode_Desc Varchar(MAX)
		DECLARE @Cursore CURSOR
		DECLARE @Sequenza_Percorso Int
		DECLARE @MissionResult Bit
		DECLARE @Id_Missione Int
		DECLARE @Gmove_Id Int
		DECLARE @CODPLC_ORIG VARCHAR(14)
		DECLARE @ID_UDC INT		
		DECLARE @ID_TIPO_CELLA VARCHAR(2)
		DECLARE @LU_NO INT
		DECLARE @ALARMID INT
		DECLARE @DIRECTION VARCHAR(1)
		DECLARE @QUOTADEPOSITOX INT

		-- Inserimento del codice;
		SELECT	@xmlMessage = Messaggio FROM dbo.Messaggi_Ricevuti WHERE Id_Messaggio = @Id_Messaggio

		SET @Asi = @XmlMessage.value('data(//Asi)[1]','Varchar(4)')
		SET @Gmove_Id = @XmlMessage.value('data(//LU_MOVE_ID)[1]','Int')	
		SET @ErrorCode = @XmlMessage.value('data(//MISSION_ERROR)[1]','Int')	
		SET @MissionResult = @XmlMessage.value('data(//MISSION_RESULT)[1]','Bit')	
				
		-- Ricavo la posizione in cui mi trovo dal passo del percorso appena eseguito e i parametri della missione.
		SET @Cursore = CURSOR LOCAL FAST_FORWARD FOR
		SELECT	M.Id_Percorso
				,M.Sequenza_Percorso
				,A.CODICE_ABBREVIATO + SA.CODICE_ABBREVIATO + C.CODICE_ABBREVIATO + '.' + SC.CODICE_ABBREVIATO + '.' + PT.CODICE_ABBREVIATO
				,M.ID_UDC
				,PT.ID_TIPO_PARTIZIONE
				,P.DIREZIONE
		FROM	dbo.Messaggi_Percorsi M
				INNER JOIN dbo.Percorso P ON P.Id_Percorso = M.Id_Percorso AND M.Sequenza_Percorso = P.Sequenza_Percorso  
				INNER JOIN dbo.Partizioni PT ON PT.ID_PARTIZIONE = P.ID_PARTIZIONE_DESTINAZIONE
				INNER JOIN dbo.SottoComponenti SC ON SC.ID_SOTTOCOMPONENTE = PT.ID_SOTTOCOMPONENTE
				INNER JOIN dbo.Componenti C ON C.ID_COMPONENTE = SC.ID_COMPONENTE
				INNER JOIN dbo.SottoAree SA ON SA.ID_SOTTOAREA = C.ID_SOTTOAREA
				INNER JOIN dbo.Aree A ON A.ID_AREA = SA.ID_AREA
		WHERE	M.Id_Messaggio = @Gmove_Id			
				
		OPEN @Cursore	
		
		FETCH NEXT FROM @Cursore INTO
		@Id_Missione
		,@Sequenza_Percorso
		,@CODPLC_ORIG
		,@ID_UDC
		,@ID_TIPO_CELLA
		,@DIRECTION 
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @MissionResult = 1
			BEGIN
				SET @LU_NO = @XmlMessage.value('data(//LU_NO)[1]','Int')	

				-- CONTROLLO CHE LA DESTINAZIONE NEL COMPLETED SIA UGUALE A QUELLA ORIGINALMENTE ISTANZIATA NEL PERCORSO, SE COSI' NON FOSSE
				-- PASSO ALL'AGGIORNA POSIZIONE L'OVERRIDE DELL'ID_PARTIIZONE.
				WHILE	@LU_NO <> 0
						AND @ID_TIPO_CELLA = 'MA'
				BEGIN
					SELECT @QUOTADEPOSITOX = QUOTADEPOSITOX FROM dbo.Missioni WHERE Id_Missione = @Id_Missione
					
					-- è UNO SCHIFO COME STO RECUPERANDO I DATI AL MOMENTO, MA PER COM'è COMPOSTO L'XML NON POSSO FARE ALTRO.
					-- TODO: RIVEDERE COMPOSIZIONE XML NEL PCM E QUESTO PEZZO INSIEME.
					DECLARE @sql NVARCHAR(MAX)
					DECLARE @LU_ID_MSG INT = NULL

					DECLARE @XMLPATH VARCHAR(100) = N'data(//LU_NO_' + CONVERT(VARCHAR,@LU_NO) + ')[1]'

					SET @sql = N'SET @LU_ID_MSG = @doc.value(''' + @XMLPATH + ''',''Int'')'
					EXEC sp_executesql @sql, N'@doc XML, @LU_ID_MSG INT OUTPUT', @XmlMessage, @LU_ID_MSG OUTPUT

					IF @LU_ID_MSG = @ID_UDC
					BEGIN
						DECLARE @FINAL_ASI VARCHAR(4) = NULL,
								@FINAL_SUBITEM VARCHAR(4) = NULL,
								@FINAL_PARTITION VARCHAR(4) = NULL

						DECLARE @XMLPATH_ASI VARCHAR(100) = N'data(//LU_FINAL_POS_ASI_' + CONVERT(VARCHAR,@LU_NO) + ')[1]'
						DECLARE @XMLPATH_SUBITEM VARCHAR(100) = N'data(//LU_FINAL_POS_SUBITEM_' + CONVERT(VARCHAR,@LU_NO) + ')[1]'
						DECLARE @XMLPATH_PARTITION VARCHAR(100) = N'data(//LU_FINAL_POS_PARTITION_' + CONVERT(VARCHAR,@LU_NO) + ')[1]'
						
						SET @sql = N'	SET @FINAL_ASI = @doc.value(''' + @XMLPATH_ASI + ''',''VARCHAR(4)'') 
										SET @FINAL_SUBITEM = @doc.value(''' + @XMLPATH_SUBITEM + ''',''VARCHAR(4)'') 
										SET @FINAL_PARTITION = @doc.value(''' + @XMLPATH_PARTITION + ''',''VARCHAR(4)'')'

						EXEC sp_executesql @sql, N'@doc XML, @FINAL_ASI VARCHAR(4) OUTPUT, @FINAL_SUBITEM VARCHAR(4) OUTPUT, @FINAL_PARTITION VARCHAR(4) OUTPUT', @XmlMessage, @FINAL_ASI OUTPUT, @FINAL_SUBITEM OUTPUT, @FINAL_PARTITION OUTPUT 
												
						--DECLARE @FINALDEST VARCHAR(14) = @FINAL_ASI + '.' + @FINAL_SUBITEM + '.' + @FINAL_PARTITION

						--IF @FINALDEST <> @CODPLC_ORIG
						--BEGIN
						--	SELECT	@ID_PARTIZIONE = ID_PARTIZIONE 
						--	FROM	VISTA_CODIFICA_PARTIZIONI	
						--	WHERE	CODPLC = @FINALDEST
						--END

						DECLARE @QuotaDeposito INT
						SET @QuotaDeposito = CONVERT(Int,/* CONVERT(Varbinary(2),'0x' +*/ @FINAL_PARTITION,1) * 10

						BREAK
					END

					SET @LU_NO = @LU_NO - 1
				END

				EXEC @Return = dbo.sp_Update_Aggiorna_Posizione_Udc	@Id_Missione = @Id_Missione
																	,@Sequenza_Percorso = @Sequenza_Percorso
																	,@Id_Stato_Percorso = 3
																	,@Id_Partizione = @Id_Partizione
																	,@QuotaDepositoX = @QUOTADEPOSITOX
																	,@QuotaDeposito = @QuotaDeposito
																	,@DIRECTION = @DIRECTION
																	,@Id_Processo = @Id_Processo
																	,@Origine_Log = @Origine_Log
																	,@Id_Utente = @Id_Utente
																	,@Errore = @Errore OUTPUT
				IF @Return <> 0 RAISERROR(@Errore,12,1)		
			END	
			ELSE
			BEGIN
				IF @ALARMID IS NULL
				BEGIN
					INSERT INTO dbo.Alarms (ERRORCODEID, [STATUS], ResourceName)
					VALUES (@ErrorCode, 1, 'ErrorCode' + CONVERT(VARCHAR,@ErrorCode))

					SELECT @ALARMID = SCOPE_IDENTITY()
				END
				
				UPDATE	dbo.Percorso
				SET		ALARMID = @ALARMID
				WHERE	ID_PERCORSO = @Id_Missione
						AND SEQUENZA_PERCORSO = @SEQUENZA_PERCORSO

				IF @ErrorCode IN (184549445,207683589)--,193003522)
				BEGIN
					EXEC dbo.sp_RicalcoloMissione @Id_Missione = @Id_Missione,        -- int
					                              @Id_Processo = @Id_Processo,       -- varchar(30)
					                              @Origine_Log = @Origine_Log,       -- varchar(25)
					                              @Id_Utente = @Id_Utente,         -- varchar(16)
					                              @Errore = @Errore OUTPUT -- varchar(500)
                END	
			END
			
			FETCH NEXT FROM @Cursore INTO
			@Id_Missione
			,@Sequenza_Percorso
			,@CODPLC_ORIG
			,@ID_UDC
			,@ID_TIPO_CELLA
			,@DIRECTION 
		END
			
		CLOSE @Cursore
		DEALLOCATE @Cursore 
		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION
		-- Return 1 se tutto è andato a buon fine;
		RETURN 0
	END TRY
	BEGIN CATCH
		-- Valorizzo l'errore con il nome della procedura corrente seguito dall'errore scatenato nel codice;
		SET @Errore = @Nome_StoredProcedure + ';' + ERROR_MESSAGE()
		-- Eseguo il rollback ed inserisco il log solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 
		BEGIN
			ROLLBACK TRANSACTION
			
			EXEC dbo.sp_Insert_Log	@Id_Processo = @Id_Processo
									,@Origine_Log = @Origine_Log
									,@Proprieta_Log = @Nome_StoredProcedure
									,@Id_Utente = @Id_Utente
									,@Id_Tipo_Log = 4
									,@Id_Tipo_Allerta = 0
									,@Messaggio = @Errore
									,@Errore = @Errore OUTPUT

			-- Return 0 se la procedura è andata in errore;
			RETURN 1
		END ELSE THROW
	END CATCH
END




GO
