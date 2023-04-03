SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_SendInsideWithBarcode_3A01]
	@Id_Evento		INT,
	@Barcode		VARCHAR(17),
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
		-- Dichiarazioni Variabili;
		DECLARE	@Id_Missione	INT,
				@Id_Udc			NUMERIC(18,0),
				@Xml_Param		XML;

		-- Inserimento del codice;
		--Se l'evento non è nello stato 1 vado in errore.
		IF EXISTS( SELECT 1 FROM dbo.Eventi WHERE Id_Evento = @Id_Evento AND Id_Tipo_Stato_Evento <> 1)
			THROW 50001, 'SpEx_EventNotActive', 1

		IF LEN(@Barcode) > 17
			THROW 50001, 'Lunghezza barcode supera i 17 caratteri', 1

		IF TRY_PARSE(@Barcode AS INT) IS NULL
			THROW 50001, 'Barcode con caratteri non validi', 1

		--tolgo l'evento e mando dentro
		EXEC dbo.sp_Update_Stato_Eventi @Id_Evento = @Id_Evento,
		                                @Id_Tipo_Stato_Evento = 3,
		                                @Id_Processo = @Id_Processo,
		                                @Origine_Log = @Origine_Log,
		                                @Id_Utente = @Id_Utente,
		                                @Errore = @Errore OUTPUT

		--preparo i dati per la misisone
		SET @Xml_Param = CONCAT('<Codice_Udc>',@Barcode,'</Codice_Udc>');
		SELECT	@Id_Udc = UP.Id_Udc
		FROM	dbo.Eventi E INNER JOIN dbo.Udc_Posizione UP ON UP.Id_Partizione = E.Id_Partizione
		WHERE	E.Id_Evento = @Id_Evento

		-- Creo la missione per l'Udc
		EXEC @Return = dbo.sp_Insert_CreaMissioni
							@Id_Udc						= @Id_Udc,
							@Id_Partizione_Destinazione = 3102,
							@Id_Tipo_Missione			= 'ING',
							@Id_Missione				= @Id_Missione	OUTPUT,
							@Xml_Param					= @Xml_Param,
							@Id_Processo				= @Id_Processo,
							@Origine_Log				= @Origine_Log,
							@Id_Utente					= @Id_Utente,
							@Errore						= @Errore		OUTPUT
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
