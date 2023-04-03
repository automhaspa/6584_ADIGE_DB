SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Rientro_Udc_ControlloQualita]
	@Codice_Udc		VARCHAR(40),
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
	SET @Nome_StoredProcedure	= Object_Name(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount				= @@TRANCOUNT;

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		DECLARE @IdPartizioneAreaTerraCq	INT = 7683
		DECLARE @IdPartizioneBaiaCq			INT = 3701
		DECLARE @Id_Udc						INT = NULL

		SELECT	@Id_Udc = Id_Udc
		FROM	Udc_Testata
		WHERE	Codice_Udc = @Codice_Udc

		IF @Id_Udc IS NULL
			THROW 50006, 'UDC CON IL CODICE SPECIFICATO INESISTENTE',1

		IF NOT EXISTS	(
							SELECT	TOP(1) 1
							FROM	Udc_Testata		UT
							JOIN	Udc_Posizione	UP
							ON		UT.Id_Udc = UP.Id_Udc
							WHERE	UT.Id_Udc = @Id_Udc
								AND UP.Id_Partizione = @IdPartizioneAreaTerraCq
						)
			THROW 50007, 'UDC NON PRESENTE IN AREA A TERRA 5A04',1

		IF EXISTS	(
						SELECT	TOP(1) 1
						FROM	Udc_Posizione
						WHERE	Id_Partizione = @IdPartizioneBaiaCq
					)
			THROW 50008, 'E'' GIA PRESENTE UN UDC SULLA BAIA CONTROLLO QUALITA',1;

		IF EXISTS	(
						SELECT	TOP(1) 1
						FROM	Missioni
						WHERE	Id_Stato_Missione IN ('ELA', 'ESE', 'NEW')
							AND Id_Partizione_Destinazione = @IdPartizioneBaiaCq
					)
			THROW 50009, ' IMPOSSIBILE POSIZIONARE L''UDC, C''E GIA UNA MISSIONE IN ARRIVO IN BAIA',1;

		--Se supera i controlli creo la missione di ingresso
		UPDATE	Udc_Posizione
		SET		Id_Partizione = @IdPartizioneBaiaCq
		WHERE	Id_Udc = @Id_Udc
		
		DECLARE @Id_Partizione_Destinazione INT = 2110;
		DECLARE @Id_Tipo_Missione			VARCHAR(3) = 'ING'
		
		EXEC @Return = dbo.sp_Insert_CreaMissioni
								@Id_Udc = @Id_Udc
								,@Id_Partizione_Destinazione = @Id_Partizione_Destinazione                                                            
								,@XML_PARAM = ''
								,@Id_Tipo_Missione = @Id_Tipo_Missione
								,@Id_Processo = @Id_Processo
								,@Origine_Log = @Origine_Log
								,@Id_Utente = @Id_Utente
								,@Errore = @Errore OUTPUT	
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
