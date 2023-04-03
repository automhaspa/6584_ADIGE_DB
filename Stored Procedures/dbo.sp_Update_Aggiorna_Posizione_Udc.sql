SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE	 [dbo].[sp_Update_Aggiorna_Posizione_Udc]
	@Id_Udc				INT			= NULL,
	@Id_Partizione		INT			= NULL,
	@Sequenza_Percorso	INT			= NULL,
	@Id_Stato_Percorso	INT			= NULL,
	@Id_Raggruppa_Udc	INT			= NULL,
	@Id_Missione		INT			= NULL,
	@Direction			VARCHAR(1)	= NULL,
	@QuotaDeposito		INT			= 0,
	@QuotaDepositoX		INT			= NULL,
	-- Parametri Standard;
	@Id_Processo		VARCHAR(30),	
	@Origine_Log		VARCHAR(25),
	@Id_Utente			VARCHAR(16),	
	@SavePoint			VARCHAR(32) = '',
	@Errore				VARCHAR(500) OUTPUT
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT OFF;

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure	VARCHAR(30);
	DECLARE @TranCount				INT;
	DECLARE @Return					INT;

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT;
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY	
		-- Dichiarazioni Variabili;

		DECLARE @Cursore_Agg	CURSOR;
		DECLARE @Cursore		CURSOR;
		
		-- Dichiarazione Procedure;

		-- Inserimento del codice;
		IF	@Id_Raggruppa_Udc IS NOT NULL
			AND @Sequenza_Percorso IS NOT NULL
			BEGIN	
				SET @Cursore_Agg = CURSOR LOCAL STATIC FOR
				SELECT	Id_Missione,
						@Sequenza_Percorso,
						Id_Udc,
						CASE 
							WHEN @Id_Partizione IS NOT NULL THEN @Id_Partizione
							WHEN @Id_Stato_Percorso = 1 THEN Percorso.Id_Partizione_Sorgente
							WHEN @Id_Stato_Percorso = 3 THEN Percorso.Id_Partizione_Destinazione 
						END as Id_Partizione	
				FROM	Missioni
						INNER JOIN Percorso ON
							Percorso.Id_Percorso = Missioni.Id_Missione
				WHERE	Missioni.Id_Raggruppa_Udc = @Id_Raggruppa_Udc
						AND Percorso.Sequenza_Percorso = @Sequenza_Percorso;
			END
		ELSE IF @Id_Udc IS NOT NULL
				AND @Id_Partizione IS NOT NULL
		BEGIN		
			SET @Cursore_Agg = CURSOR LOCAL STATIC FOR
				SELECT @Id_Missione, @Sequenza_Percorso, @Id_Udc, @Id_Partizione
		END
		ELSE IF @Id_Missione IS NOT NULL
				AND @Sequenza_Percorso IS NOT NULL
		BEGIN
			SET @Cursore_Agg = CURSOR LOCAL STATIC FOR
			SELECT	Id_Missione
					,@Sequenza_Percorso
					,Id_Udc
					,CASE 
						WHEN @Id_Partizione IS NOT NULL THEN @Id_Partizione
						WHEN @Id_Stato_Percorso = 1 THEN Percorso.Id_Partizione_Sorgente
						WHEN @Id_Stato_Percorso = 3 THEN Percorso.Id_Partizione_Destinazione 
					 END as Id_Partizione	
			FROM	Missioni
					INNER JOIN Percorso ON Percorso.Id_Percorso = Missioni.Id_Missione
			WHERE	Missioni.Id_Missione = @Id_Missione
					AND Percorso.Sequenza_Percorso = @Sequenza_Percorso		
		END		
		ELSE RAISERROR ('Nessuna informazione per effettuare aggiornamento',12,1)
		
		OPEN @Cursore_Agg

		
		FETCH NEXT FROM @Cursore_Agg INTO
		@Id_Missione
		,@Sequenza_Percorso
		,@Id_Udc
		,@Id_Partizione
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			-- Aggiorno la posizione solo se la partizione è valorizzata, altrimenti mi occupo solo della missione e dei passi.
			-- (tipo quando arrivo dall'esecuzione di una procedura).
			IF	@Id_Partizione IS NOT NULL
			BEGIN
				IF	(SELECT	Count(0) FROM Udc_Posizione WHERE Id_Partizione = @Id_Partizione AND Id_Udc <> @Id_Udc) >= (SELECT Capienza FROM Partizioni WHERE Id_Partizione = @Id_Partizione)		
				BEGIN			
					SET @Errore = 'La Capienza massima della partizone "' + CONVERT(Varchar,@Id_Partizione) + '" è stata superata'
					RAISERROR(@Errore,12,1)		
				END

				IF	(SELECT Id_Tipo_Componente
						 FROM	Partizioni 
								INNER JOIN SottoComponenti ON SottoComponenti.ID_SOTTOCOMPONENTE = Partizioni.ID_SOTTOCOMPONENTE
								INNER JOIN Componenti ON Componenti.ID_COMPONENTE = SottoComponenti.ID_COMPONENTE
						 WHERE Id_Partizione = @Id_Partizione) = 'S'
				BEGIN
					IF (@QuotaDeposito IS NULL OR ISNULL(@DIRECTION,'A') = 'D')
					BEGIN
						DECLARE @PROFONDITA_UDC INT

						IF ISNULL	(@DIRECTION,'A') = 'D'
						SELECT	@PROFONDITA_UDC = PROFONDITA 
						FROM	UDC_TESTATA 
						WHERE	ID_UDC = @ID_UDC

						IF @QuotaDeposito IS NULL
						BEGIN
							SELECT @QuotaDeposito =	CASE ISNULL(@DIRECTION,'A')
														WHEN 'A' THEN MIN(P.QuotaDeposito - T.PROFONDITA - 50) 
														WHEN 'D' THEN MAX(P.QuotaDeposito + @PROFONDITA_UDC  + 50) 
													END
							FROM	UDC_POSIZIONE P
									INNER JOIN UDC_TESTATA T ON T.ID_UDC = P.ID_UDC
							WHERE	ID_PARTIZIONE = @ID_PARTIZIONE
					
							IF @QUOTADEPOSITO IS NULL
							SELECT @QUOTADEPOSITO = CASE ISNULL(@DIRECTION,'A')
														WHEN 'A' THEN (SELECT PROFONDITA FROM Partizioni WHERE ID_PARTIZIONE = @ID_PARTIZIONE)
														WHEN 'D' THEN (@PROFONDITA_UDC)
													END
						END				
						ELSE 
						SELECT	@QUOTADEPOSITO = Partizioni.PROFONDITA - CASE 
																		WHEN @QUOTADEPOSITO > Partizioni.PROFONDITA THEN Partizioni.PROFONDITA - @PROFONDITA_UDC
																		ELSE @QUOTADEPOSITO - @PROFONDITA_UDC
																	END
						FROM	Partizioni
						WHERE	ID_PARTIZIONE = @ID_PARTIZIONE
					END

					IF ISNULL(@QuotaDepositoX,0)=0 
						SELECT @QuotaDepositoX = QUOTADEPOSITOX FROM dbo.Missioni WHERE Id_Missione = @Id_Missione
				END
				
				UPDATE	Udc_Posizione
				SET		Id_Partizione = @Id_Partizione
						,QuotaDeposito = @QuotaDeposito
						,QuotaDepositoX = CASE WHEN @Id_Stato_Percorso = 1 THEN QuotaDepositoX ELSE	@QuotaDepositoX END
				WHERE	Id_Udc = @Id_Udc

				--IF @Id_Stato_Percorso = 3
				--BEGIN
				--	DECLARE @PARTIZIONE_ORIG INT
				--	SELECT  @PARTIZIONE_ORIG = P.ID_PARTIZIONE_DESTINAZIONE
				--	FROM	PERCORSO P
				--	WHERE	ID_PERCORSO = @ID_MISSIONE
				--			AND SEQUENZA_PERCORSO = @SEQUENZA_PERCORSO

				--	IF @PARTIZIONE_ORIG <> @ID_PARTIZIONE
				--	UPDATE	PERCORSO 
				--	SET		ID_PARTIZIONE_SORGENTE = @ID_PARTIZIONE
				--	WHERE	ID_PERCORSO = @ID_MISSIONE
				--			AND ID_PARTIZIONE_SORGENTE = @PARTIZIONE_ORIG
				--END
			END				
			IF	@Id_Missione IS NOT NULL
				AND @Sequenza_Percorso IS NOT NULL
			BEGIN	
				UPDATE	Percorso
				SET		Id_Tipo_Stato_Percorso = @Id_Stato_Percorso
						,AlarmId = NULL
				WHERE	Id_Percorso = @Id_Missione
						AND ((Sequenza_Percorso >= @Sequenza_Percorso AND @Id_Stato_Percorso = 1)
						OR	(Sequenza_Percorso <= @Sequenza_Percorso AND @Id_Stato_Percorso = 3))								
				IF (SELECT	Count(0) 
					FROM	Percorso
					WHERE	Percorso.Id_Percorso = @Id_Missione
							AND Id_Tipo_Stato_Percorso <> 3) = 0	
				BEGIN

					EXEC  @Return = sp_Update_Stato_Missioni	@Id_Missione = @Id_Missione
																,@Id_Stato_Missione = 'TOK'
																,@Id_Processo = @Id_Processo
																,@Origine_Log = @Origine_Log
																,@Id_Utente = @Id_Utente
																,@Errore = @Errore OUTPUT	
					IF @Return <> 0 RAISERROR(@Errore,12,1)	
		
				END					
			END
			
			-- Aggiorno le sorgenti delle missioni solo se la partizione è valorizzata
			-- (tipo quando arrivo dall'esecuzione di una procedura).

			IF	@Id_Partizione IS NOT NULL
			BEGIN
				SET @Cursore = CURSOR LOCAL STATIC FOR
				SELECT	Id_Missione 
				FROM	Missioni	
				WHERE	Id_Udc = @Id_Udc 
						AND (Id_Stato_Missione IN ('ELA','NEW'))
						AND Id_Missione <> ISNULL(@Id_Missione,0)

				OPEN @Cursore

				FETCH NEXT FROM @Cursore INTO
				@Id_Missione
				WHILE @@FETCH_STATUS = 0
				BEGIN
					UPDATE	Missioni
					SET		Id_Partizione_Sorgente = @Id_Partizione
					WHERE	Id_Missione = @Id_Missione

					EXEC  @Return = sp_Update_Stato_Missioni	@Id_Missione = @Id_Missione
																,@Id_Stato_Missione = 'NEW'
																,@Id_Processo = @Id_Processo
																,@Origine_Log = @Origine_Log
																,@Id_Utente = @Id_Utente
																,@Errore = @Errore OUTPUT	
					IF @Return <> 0 RAISERROR(@Errore,12,1)

					FETCH NEXT FROM @Cursore INTO
					@Id_Missione
				END

				CLOSE @Cursore
				DEALLOCATE @Cursore
			END	
			
			FETCH NEXT FROM @Cursore_Agg INTO
			@Id_Missione
			,@Sequenza_Percorso
			,@Id_Udc
			,@Id_Partizione
		END	
		
		CLOSE @Cursore_Agg
		DEALLOCATE @Cursore_Agg
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
			EXEC sp_Insert_Log	@Id_Processo = @Id_Processo
								,@Origine_Log = @Origine_Log
								,@Proprieta_Log = @Nome_StoredProcedure
								,@Id_Utente = @Id_Utente
								,@Id_Tipo_Log = 4
								,@Id_Tipo_Allerta = 0
								,@Messaggio = @Errore
								,@Errore = @Errore OUTPUT
			
			-- Return 0 se la procedura è andata in errore;
			RETURN 1
		END else throw

	END CATCH
END


GO
