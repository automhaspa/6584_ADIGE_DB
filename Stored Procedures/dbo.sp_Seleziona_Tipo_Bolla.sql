SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROC [dbo].[sp_Seleziona_Tipo_Bolla]
	@Id_Udc			INT,
	@Id_Evento		INT,
	@Tipo_Udc		VARCHAR(1),
	@ID_TIPO		INT,
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

	-- Se il numero di transazioni � 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @Id_Partizione	INT
		DECLARE @Action			XML = NULL;
		DECLARE @Id_Tipo_Evento INT = 27

		--Seleziono partizione conoscendo id_udc (Appena creata)
		SELECT	@Id_Partizione = Id_Partizione
		FROM	Udc_Posizione
		WHERE	Id_Udc = @Id_Udc

		IF @ID_TIPO = 1	--vTipoBolla 1 = Fittizia
			SET @Action = CONCAT	(
										'<StoredProcedure ProcedureKey="associaUdcDdtFake">
											<ActionParameter>
											<Parameter>
												<ParameterName>Id_Udc</ParameterName>
												<ParameterValue>',@Id_Udc,'</ParameterValue>
											</Parameter>
											<Parameter>
												<ParameterName>Tipo_Udc</ParameterName>
												<ParameterValue>',@Tipo_Udc,'</ParameterValue>
											</Parameter>
											</ActionParameter>
										</StoredProcedure>'
									);

		ELSE IF @ID_TIPO = 2 --Bolla reale		
			SET @Action = CONCAT(
									'<StoredProcedure ProcedureKey="associaUdcDdtReale">
										<ActionParameter>
										<Parameter>
											<ParameterName>Id_Udc</ParameterName>
											<ParameterValue>',@Id_Udc,'</ParameterValue>
										</Parameter>
										<Parameter>
											<ParameterName>Tipo_Udc</ParameterName>
											<ParameterValue>',@Tipo_Udc,'</ParameterValue>
										</Parameter>
										</ActionParameter>
									</StoredProcedure>'
								);

		ELSE IF @ID_TIPO = 3 --Faccio selezionare il codice articolo  all'utente
			SET @Action = CONCAT(
									'<StoredProcedure ProcedureKey="associaArticoloManualmente">
										<ActionParameter>
										<Parameter>
											<ParameterName>Id_Udc</ParameterName>
											<ParameterValue>',@Id_Udc,'</ParameterValue>
										</Parameter>
										</ActionParameter>
									</StoredProcedure>'
								);
		--Rientro da Area a terra 
		ELSE IF @ID_TIPO = 4
		BEGIN
			--SONO ANCORA NELLA SEZIONE LU_ON_ASI
			DECLARE @Id_Partizione_Destinazione INT
			DECLARE @ID_MISSIONE				INT

			SELECT	@Id_Partizione_Destinazione = Id_Partizione_OK
			FROM	dbo.Procedure_Personalizzate_Gestione_Messaggi
			WHERE	Id_Tipo_Messaggio = '11000'

			-- Creo la missione per l'Udc			
			EXEC @Return = dbo.sp_Insert_CreaMissioni
					@Id_Udc						= @Id_Udc,
					@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
					--INGRESSO DA AREA A TERRA
					@Id_Tipo_Missione			= 'INT',
					@Id_Missione				= @ID_MISSIONE OUTPUT,
					@Id_Processo				= @Id_Processo,
					@Origine_Log				= @Origine_Log,
					@Id_Utente					= @Id_Utente,
					@Errore						= @Errore OUTPUT

			IF	@ID_MISSIONE = 0
					OR
				ISNULL(@Errore, '') <> ''
				THROW 50001, 'IMPOSSIBILE CREARE MISSIONE DI INGRESSO PER L''UDC', 1
		END
		ELSE IF @ID_TIPO = 5
		BEGIN
			SELECT	@Id_Partizione_Destinazione = Id_Partizione_OK
			FROM	dbo.Procedure_Personalizzate_Gestione_Messaggi
			WHERE	Id_Tipo_Messaggio = '11000'
				AND Id_Partizione = 3101

			-- Creo la missione per l'Udc			
			EXEC @Return = dbo.sp_Insert_CreaMissioni
					@Id_Udc						= @Id_Udc,
					@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
					@Id_Tipo_Missione			= 'INT',
					@Id_Missione				= @ID_MISSIONE OUTPUT,
					@Id_Processo				= @Id_Processo,
					@Origine_Log				= @Origine_Log,
					@Id_Utente					= @Id_Utente,
					@Errore						= @Errore OUTPUT

			IF	@ID_MISSIONE = 0
					OR
				ISNULL(@Errore, '') <> ''
				THROW 50001, 'IMPOSSIBILE CREARE MISSIONE DI INGRESSO PER L''UDC', 1
		END
		ELSE
			THROW 50001, 'TIPO DI BOLLA NON DEFINITO', 1

		IF @Action IS NOT NULL
			EXEC [dbo].[sp_Insert_Eventi]
				@Id_Tipo_Evento		= @Id_Tipo_Evento,
				@Id_Partizione		= @Id_Partizione,
				@Id_Tipo_Messaggio	= '11000',
				@XmlMessage			= @Action,
				@id_evento_padre	= @Id_Evento,
				@Id_Processo		= @Id_Processo,
				@Origine_Log		= @Origine_Log,
				@Id_Utente			= @Id_Utente,
				@Errore				= @Errore			OUTPUT



		--Elimino evento di selezione tipo bolla
		DELETE FROM Eventi WHERE Id_Evento = @Id_Evento
		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION;
		-- Return 0 se tutto � andato a buon fine;
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
			
				-- Return 1 se la procedura � andata in errore;
				RETURN 1;
			END
		ELSE
			THROW;
	END CATCH;
END;
GO
