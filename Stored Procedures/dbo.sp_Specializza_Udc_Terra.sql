SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Specializza_Udc_Terra]
	@ID				INT,
	@Id_Partizione	INT = 3101,
	@Codice_Udc		VARCHAR(50),
	@Id_Opzione		INT,
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
	SET @Nome_StoredProcedure = Object_Name(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT;

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		-- Dichiarazioni Variabili;		
		DECLARE @IdPartizioneTerraAdiacente INT = 9103
		DECLARE @Id_Udc						INT
		DECLARE @IdTipoUdc					VARCHAR(1) = CASE
															WHEN @Id_Opzione = 1 THEN '1'
															ELSE '4'
														 END

		IF (@Id_Partizione <> 3101)
			THROW 50001, ' SPECIALIZZAZIONE A TERRA AVVIABILE ESCLUSIVAMENTE IN AREA DI INBOUND', 1;

		--SE ESISTE NELL'AREA A TERRA ED E' VUOTA
		IF EXISTS	(
						SELECT	TOP 1 1
						FROM	Udc_Testata		UT
						LEFT
						JOIN	Udc_Posizione	UP
						ON		UP.Id_Udc = UT.Id_Udc
						LEFT
						JOIN	Udc_Dettaglio	UD
						ON		UD.Id_Udc = UT.Id_Udc
						WHERE	UT.Codice_Udc = @Codice_Udc
							AND UP.Id_Partizione = @IdPartizioneTerraAdiacente
							AND UD.Id_Udc IS NULL
					)
			SELECT	@Id_Udc = Id_Udc
			FROM	Udc_Testata
			WHERE	Codice_Udc = @Codice_Udc
		ELSE
			IF NOT EXISTS	(
								SELECT	1
								FROM	Udc_Testata
								WHERE	Codice_Udc = @Codice_Udc
							)
			BEGIN
				EXEC dbo.sp_Insert_Crea_Udc		
									@Id_Tipo_Udc	= @IdTipoUdc,
									@Codice_Udc		= @Codice_Udc,
									@Id_Partizione	= @IdPartizioneTerraAdiacente,
									@Id_Udc			= @Id_Udc				OUTPUT,
									@Id_Processo	= @Id_Processo,
									@Origine_Log	= @Origine_Log,
									@Id_Utente		= @Id_Utente,
									@Errore			= @Errore				OUTPUT

				IF (ISNULL(@Errore, 0) <> 0)
					THROW 50004, @Errore,1;
			END
		ELSE
			THROW 50006, 'BARCODE GIA'' PRESENTE SU UN ALTRA UDC IN MAGAZZINO', 1;
		
		UPDATE	Udc_Testata
		SET		Id_Ddt_Fittizio = @ID
		WHERE	Id_Udc = @Id_Udc

        DECLARE @XmlParam XML = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc></Parametri>');

		EXEC @Return = sp_Insert_Eventi
				@Id_Tipo_Evento		= 33,
				@Id_Partizione		= @IdPartizioneTerraAdiacente,
				@Id_Tipo_Messaggio	= 1100,
				@XmlMessage			= @XmlParam,
				@Id_Processo		= @Id_Processo,
				@Origine_Log		= @Origine_Log,
				@Id_Utente			= @Id_Utente,
				@Errore				= @Errore OUTPUT;

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
