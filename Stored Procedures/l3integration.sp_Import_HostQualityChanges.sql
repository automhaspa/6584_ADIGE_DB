SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROC [l3integration].[sp_Import_HostQualityChanges]
	-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(32),
	@Errore			VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT OFF;

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure	VARCHAR(100)
	DECLARE @TranCount				INT
	DECLARE @Return					INT
	DECLARE @ErrLog					VARCHAR(500)

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		DECLARE @START DATETIME = GETDATE()

		DECLARE @Id_Articolo		INT
		
		-- Dichiarazioni Variabili;
		DECLARE @PRG_MSG_C			INT
		DECLARE @CONTROL_LOT_C		VARCHAR(40)
		DECLARE @ITEM_CODE_C		VARCHAR(18)
		DECLARE @QUANTITY_C			INT
		DECLARE @STAT_QUAL_NEW_C	VARCHAR(4)
		DECLARE @STAT_QUAL_OLD_C	VARCHAR(4)


		--Carico gli articoli da elaborare
		DECLARE Cursore_QualChanges CURSOR LOCAL STATIC FOR
			SELECT	PRG_MSG,
					CONTROL_LOT,
					ITEM_CODE,
					QUANTITY,
					STAT_QUAL_OLD,
					STAT_QUAL_NEW
			FROM	L3INTEGRATION.dbo.HOST_QUALITY_CHANGES
			WHERE	STATUS = 0
			ORDER
				BY	PRG_MSG,
					DT_INS

		--Elaboro ogni Testata ordine 
		OPEN Cursore_QualChanges
		FETCH NEXT FROM Cursore_QualChanges INTO
			@PRG_MSG_C,
			@CONTROL_LOT_C,
			@ITEM_CODE_C,
			@QUANTITY_C,
			@STAT_QUAL_OLD_C,
			@STAT_QUAL_NEW_C

		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				SET @Id_Articolo = NULL

				--RECUPERO L'ARTICOLO SOTTOPOSTO A CQ
				SELECT	@Id_Articolo = Id_Articolo
				FROM	dbo.Articoli
				WHERE	Codice = @ITEM_CODE_C
					
				IF @Id_Articolo IS NULL
					THROW 50009, 'ANAGRAFICA ARTICOLO NON REGISTRATA', 1

				INSERT INTO l3integration.Quality_Changes
				(
					TimeStamp,
					Id_Tipo_Stato_Messaggio,
					CONTROL_LOT,
					Id_Articolo,
					QUANTITY,
					[STAT_QUAL_OLD],
					[STAT_QUAL_NEW]
				)
				VALUES
				(GETDATE(),1,@CONTROL_LOT_C,@Id_Articolo,@QUANTITY_C,@STAT_QUAL_OLD_C,@STAT_QUAL_NEW_C)

				--Aggiorno lo stato
				UPDATE	L3INTEGRATION.dbo.HOST_QUALITY_CHANGES
				SET		STATUS = 1,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG = @PRG_MSG_C
			END TRY
			BEGIN CATCH
				DECLARE @Msg VARCHAR(MAX)

				--Aggiorno lo stato
				UPDATE	L3INTEGRATION.dbo.HOST_QUALITY_CHANGES
				SET		STATUS = 2,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG = @PRG_MSG_C

				SET @Msg = CONCAT('ERRORE NEL PROCESSARE RECORD HOST QUALITY CHANGES PRG_MSG: ', @PRG_MSG_C,
									' ITEM CODE: ', @ITEM_CODE_C, ' CONTROL LOT: ', @CONTROL_LOT_C, ' MOTIVO: ', ERROR_MESSAGE())
				EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 4,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @Msg,
							@Errore				= @Errore OUTPUT;
			END CATCH

			FETCH NEXT FROM Cursore_QualChanges INTO
				@PRG_MSG_C,
				@CONTROL_LOT_C,
				@ITEM_CODE_C,
				@QUANTITY_C,
				@STAT_QUAL_OLD_C,
				@STAT_QUAL_NEW_C
		END

		CLOSE Cursore_QualChanges
		DEALLOCATE Cursore_QualChanges

		DECLARE @TEMPO INT = DATEDIFF(MILLISECOND,@START,GETDATE())

		IF @TEMPO > 500
		BEGIN
			DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Import Quality Changes - TEMPO IMPIEGATO ', @TEMPO)
			EXEC dbo.sp_Insert_Log
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Proprieta_Log		= 'Tempistiche',
					@Id_Utente			= @Id_Utente,
					@Id_Tipo_Log		= 16,
					@Id_Tipo_Allerta	= 0,
					@Messaggio			= @MSG_LOG,
					@Errore				= @Errore OUTPUT;
		END

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

				EXEC sp_Insert_Log
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
