SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE   PROCEDURE [dbo].[sp_Seleziona_DdtReale]
	--ID TESTATA DDT REALE
	@ID int,
	@Id_Udc int,
	@Id_Evento int,
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
		DECLARE @Id_Partizione_Udc int, @Stato int
		-- Dichiarazioni Variabili;
		IF (@ID IS NULL)
			THROW 50008, 'NESSUN DDT REALE SELEZIONATO', 1;				
		SELECT @Stato = Stato FROM Custom.TestataOrdiniEntrata WHERE ID = @ID
		IF (@Stato NOT IN (1,2))
			THROW 50009, 'DDT  GIA'' SPECIALIZZATO',1;
		--Recupero la partizione in cui si trova l'udc (3C01 o 3C02)
		SELECT @Id_Partizione_Udc = Id_Partizione FROM Udc_Posizione WHERE Id_Udc = @Id_Udc		
		--Apro un nuovo evento di specializzione righe ddt per quell'Udc
		IF (EXISTS(SELECT 1 FROM Eventi e WHERE Id_Tipo_Evento = 32 AND Id_Partizione = @Id_Partizione_Udc))
			THROW 50005, ' Chiudere l'' evento DI SPECIALIZZAZIONE RIGHE già attivo IN BAIA,  E RIPROVARE', 1;
		--Lancio evento specializzazione righe Ddt
		DECLARE @Id_Tipo_Evento int = 32;
		
        DECLARE @XmlParam XML = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc><Id_Ddt_Reale>',@ID,'</Id_Ddt_Reale></Parametri>');												
		-- Creazione dell'evento solo se la  missione è terminata,altrimenti do il Confirm.
		EXEC @Return = sp_Insert_Eventi
						@Id_Tipo_Evento		= @Id_Tipo_Evento,
						@Id_Partizione		= @Id_Partizione_Udc,
						@Id_Tipo_Messaggio	= 1100,
						@XmlMessage			= @XmlParam,
						@Id_Evento_Padre	= @Id_Evento,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore OUTPUT;
		IF @Return <> 0 RAISERROR(@Errore,12,1);

		--Se non ho errori elimino l'evento di selezione 
		--DELETE FROM Eventi WHERE Id_Evento = @Id_Evento;
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
