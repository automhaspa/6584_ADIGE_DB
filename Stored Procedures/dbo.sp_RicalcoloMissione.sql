SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[sp_RicalcoloMissione]
	@Id_Partizione	INT = NULL,
	@Id_Udc			INT = NULL,
	@Id_Missione	INT = NULL,
	-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(32),	
	@Errore			VARCHAR(500) OUTPUT
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT OFF;
	-- SET LOCK_TIMEOUT;

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure	VARCHAR(30);
	DECLARE @TranCount				INT;
	DECLARE @Return					INT;
	DECLARE @ErrLog					VARCHAR(500);

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure	= OBJECT_NAME(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount				= @@TRANCOUNT;

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @Id_Partizione_DaBloccare	INT
		DECLARE	@Id_Partizione_Destinazione INT
		DECLARE	@Descrizione_ErrorCode		VARCHAR(MAX)
		-- Inserimento del codice;
		-- Inizio col prendere le variabili che mi servono in base a ciò che mi è arrivato in input
		IF (@Id_Partizione IS NOT NULL)
			BEGIN
				SELECT	@Id_Udc = CASE WHEN @Id_Udc IS NULL THEN UP.Id_Udc ELSE @Id_Udc END,
						@Id_Missione = CASE WHEN @Id_Missione IS NULL THEN M.Id_Missione ELSE @Id_Missione END
				FROM	dbo.Udc_Posizione UP LEFT JOIN dbo.Missioni M ON M.Id_Udc = UP.Id_Udc
				WHERE	(M.Id_Stato_Missione IN ('NEW','ELA','ESE') OR M.Id_Stato_Missione IS NULL)
				AND		UP.Id_Partizione = @Id_Partizione
			END
		ELSE IF (@Id_Udc IS NOT NULL)
			BEGIN
				SELECT	@Id_Partizione = CASE WHEN @Id_Partizione IS NULL THEN UP.Id_Partizione ELSE @Id_Partizione END,
						@Id_Missione = CASE WHEN @Id_Missione IS NULL THEN M.Id_Missione ELSE @Id_Missione END
				FROM	dbo.Udc_Posizione UP LEFT JOIN dbo.Missioni M ON M.Id_Udc = UP.Id_Udc
				WHERE	(M.Id_Stato_Missione IN ('NEW','ELA','ESE') OR M.Id_Stato_Missione IS NULL)
				AND		UP.Id_Udc = @Id_Udc
			END
		ELSE IF (@Id_Missione IS NOT NULL)
			BEGIN
				SELECT	@Id_Udc = CASE WHEN @Id_Udc IS NULL THEN UP.Id_Udc ELSE @Id_Udc END,
						@Id_Partizione = CASE WHEN @Id_Partizione IS NULL THEN UP.Id_Partizione ELSE @Id_Partizione END
				FROM	dbo.Udc_Posizione UP INNER JOIN dbo.Missioni M ON M.Id_Udc = UP.Id_Udc
				WHERE	M.Id_Stato_Missione IN ('NEW','ELA','ESE')
				AND		M.Id_Missione = @Id_Missione
			END
		ELSE
			THROW 50001,'SpEx_NotEnoughInformations',1

		-- una volta raccimolate le informazioni che mi servono controllo nella fnTempo che ci siano delle righe con Id_Partizione_Baia = @Id_Partizione e che quelle righe siano abilitate
		IF EXISTS(SELECT 1 FROM dbo.fnTempo WHERE Id_Partizione_Baia = @Id_Partizione AND Flag_Attivo = 1)
			BEGIN
				--SE L'UDC E' IN UNA MISSIONE ALLORA ESEGUO QUESTE OPERAZIONI AGGIUNTIVE
				IF(@Id_Missione IS NOT NULL)
					BEGIN
						-- ricavo la vecchia partizione di destinazione da bloccare e l'eventuale ErrorCode da inserire come motivo di blocco
						SELECT		@Id_Partizione_DaBloccare = P.Id_Partizione_Destinazione,
									@Descrizione_ErrorCode = ISNULL(TEC.Descrizione,'')
						FROM		dbo.Percorso P LEFT JOIN dbo.Alarms A ON A.AlarmId = P.AlarmId
						LEFT JOIN	dbo.Tipo_ErrorCode TEC ON TEC.Id_ErrorCode = A.ErrorCodeId
						WHERE		P.Id_Percorso = @Id_Missione AND P.Id_Partizione_Sorgente = @Id_Partizione

						-- cancello la missione corrente
						EXEC dbo.sp_Update_Stato_Missioni @Id_Missione = @Id_Missione,		-- int
															@Id_Stato_Missione = 'DEL',		-- varchar(3)
															@Id_Processo = @Id_Processo,    -- varchar(30)
															@Origine_Log = @Origine_Log,    -- varchar(25)
															@Id_Utente = @Id_Utente,        -- varchar(16)
															@Errore = @Errore OUTPUT		-- varchar(500)
				
						-- blocco la vecchia partizione di destinazione
						EXEC dbo.sp_LockUnlock_Location @Id_Partizione = @Id_Partizione_DaBloccare,     -- int
														@LOCKED = 1,									-- bit
														@Motivo_Blocco = 'RICALCOLO',		-- varchar(max)
														@Id_Processo = @Id_Processo,					-- varchar(30)
														@Origine_Log = @Origine_Log,					-- varchar(25)
														@Id_Utente = @Id_Utente,						-- varchar(16)
														@Errore = @Errore OUTPUT						-- varchar(500)

					END

				--personalizzazione adige QUOTADEPOSITOX 
				DECLARE @QuotaDepositoX int;
				-- calcolo la nuova partizione di destinazione
				EXEC @Id_Partizione_Destinazione = dbo.sp_Output_PropostaUbicazione
														@ID_UDC = @Id_Udc,				-- int
														@QUOTADEPOSITOX = @QuotaDepositoX OUTPUT,
														@Id_Processo = @Id_Processo,	-- varchar(30)
														@Origine_Log = @Origine_Log,	-- varchar(25)
														@Id_Utente = @Id_Utente,		-- varchar(16)
														@Errore = @Errore OUTPUT		-- varchar(500)
				
				IF @Id_Partizione_Destinazione IS NOT NULL
				EXEC dbo.sp_Insert_CreaMissioni @Id_Udc = @Id_Udc,											-- varchar(max)
				                                @Id_Partizione_Destinazione = @Id_Partizione_Destinazione,	-- int
				                                @Id_Tipo_Missione = 'ING',									-- varchar(3)
												@QUOTADEPOSITOX = @QuotaDepositoX,
				                                @Id_Processo = @Id_Processo,							    -- varchar(30)
				                                @Origine_Log = @Origine_Log,							    -- varchar(25)
				                                @Id_Utente = @Id_Utente,								    -- varchar(16)
				                                @Errore = @Errore OUTPUT									-- varchar(500)
			END
		ELSE
			THROW 50001,'SpEx_RicalcoloNotPossible',1


		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION;
		-- Return 0 se tutto è andato a buon fine;
		RETURN 0;
	END TRY
	BEGIN CATCH
		-- Valorizzo l'errore con il nome della procedura corrente seguito dall'errore scatenato nel codice;
		SET @Errore = @Nome_StoredProcedure + ';' + ERROR_MESSAGE();
		-- Eseguo il rollback ed inserisco il log solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 
			BEGIN
				ROLLBACK TRANSACTION;

				EXEC dbo.sp_Insert_Log
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Proprieta_Log		= @Nome_StoredProcedure,
						@Id_Utente			= @Id_Utente,
						@Id_Tipo_Log		= 4,
						@Id_Tipo_Allerta	= 0,
						@Messaggio			= @Errore,
						@Errore				= @Errore OUTPUT;
			
				-- Return 1 se la procedura è andata in errore;
				RETURN 1;
			END
		ELSE
			THROW;
	END CATCH;
END;
GO
