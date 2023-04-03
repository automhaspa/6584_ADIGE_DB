SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Insert_DdtNS]
	@N_Udc_Tipo_A			INT = 0,
	@N_Udc_Tipo_B			INT = 0,
	@N_Udc_Ingombranti		INT = 0,
	@N_Udc_Ingombranti_M	INT = 0,
	-- Parametri Standard;
	@Id_Processo		VARCHAR(30),
	@Origine_Log		VARCHAR(25),
	@Id_Utente			VARCHAR(32),
	@Errore				VARCHAR(500) OUTPUT
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
		DECLARE @CodiceFittizioDdt		VARCHAR(11)
		DECLARE @ReservedNumberLenght	INT = 10
		DECLARE @PaddingZeroLenght		INT
		DECLARE @Id_Progressivo			INT

		--Stato 1 perchè si tratta di Udc da specializzare
		DECLARE @Stato					INT = 1;
		
		--Se mi arriva un DDT con 0 udc lancio un'eccezione
		IF (@N_Udc_Tipo_A + @N_Udc_Tipo_B +  @N_Udc_Ingombranti + @N_Udc_Ingombranti_M <= 0)
			THROW 51000, 'Numero di UDC per il DDT minore o uguale a 0 ', 1

		--Genero un numero progressivo a 8 cifre paddandolo
		SET @Id_Progressivo = ISNULL(IDENT_CURRENT('Custom.AnagraficaDdtFittizi'),0) + 1
		SET @PaddingZeroLenght = @ReservedNumberLenght - LEN(@Id_Progressivo)

		--Setto il codice fittizio con Prefisso 'DN',  non posso definire dinamicamente una grandezza in
		SET @CodiceFittizioDdt = CONCAT('B',REPLICATE('0',@PaddingZeroLenght), CAST(@Id_Progressivo AS varchar(MAX)))

		--Inserisco Codice Ddt nella tabella custom per le anagrafiche
		INSERT INTO [Custom].[AnagraficaDdtFittizi]
			(Codice_DDT, DataOra_Creazione, N_Udc_Tipo_A, N_Udc_Tipo_B, N_Udc_Ingombranti, N_Udc_Ingombranti_M, Id_Stato)
		VALUES
			(@CodiceFittizioDdt, GETDATE(), @N_Udc_Tipo_A, @N_Udc_Tipo_B, @N_Udc_Ingombranti,@N_Udc_Ingombranti_M, @Stato)

		--Integrazione L3 --> inserisco un nuovo record nella Host Load Bill
		INSERT INTO [L3INTEGRATION].[dbo].[HOST_LOAD_BILL]
           ([DT_INS],[STATUS],[DT_ELAB],[USERNAME],[LOAD_BILL_ID],[DATA_REGISTRAZIONE])
	    VALUES
           (GETDATE(), 0, NULL, @Id_Utente, @CodiceFittizioDdt, GETDATE())
		
		DECLARE @Contatore		INT = 0
		DECLARE @Id_Udc			INT

		--ISTANZIO LE UDC INGOMBRANTI NELL AREA DEDICATA
		IF @N_Udc_Ingombranti > 0
		BEGIN
			WHILE @Contatore < @N_Udc_Ingombranti
			BEGIN
				--CREO L'UDC IN 5A05
				EXEC dbo.sp_Insert_Crea_Udc
							@Id_Tipo_Udc	= 'I',
							@Id_Partizione	= 7684,
							@Id_Udc			= @Id_Udc			OUTPUT,
							@Id_Processo	= @Id_Processo,
							@Origine_Log	= @Origine_Log,
							@Id_Utente		= @Id_Utente,
							@Errore			= @Errore			OUTPUT

				UPDATE	Udc_Testata
				SET		Id_Ddt_Fittizio = @Id_Progressivo
				WHERE	Id_Udc = @Id_Udc

				SET @Contatore += 1
			END
		END

		IF @N_Udc_Ingombranti_M > 0
		BEGIN
			SET @Contatore	= 0
			SET @Id_Udc		= 0

			WHILE @Contatore < @N_Udc_Ingombranti_M
			BEGIN
				--CREO L'UDC IN 5A05
				EXEC dbo.sp_Insert_Crea_Udc
						@Id_Tipo_Udc	= 'M',
						@Id_Partizione	= 7685,
						@Id_Udc			= @Id_Udc			OUTPUT,
						@Id_Processo	= @Id_Processo,
						@Origine_Log	= @Origine_Log,
						@Id_Utente		= @Id_Utente,
						@Errore			= @Errore			OUTPUT

				UPDATE	Udc_Testata
				SET		Id_Ddt_Fittizio = @Id_Progressivo
				WHERE	Id_Udc = @Id_Udc

				SET @Contatore += 1
			END
		END

		EXEC Printer.sp_AddPrinterRequest
				@TemplateName			= 'etichettaDdtAdige',
				@CODICE_DDT				= @CodiceFittizioDdt,
				@Id_Processo			= @Id_Processo,
				@Id_Utente				= @Id_Utente,
				@Origine_Log			= @Origine_Log,
				@Errore					= @Errore			OUTPUT

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
