SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Avvia_Ordine_Kitting]
	--Id testata kitting
	@ID				INT,
	@Id_Partizione	INT,
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
	SET @Nome_StoredProcedure = Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		DECLARE @Stato				INT		= 0
		DECLARE @Data_Evasione		DATE	= NULL
		DECLARE @Count_Baie_Libere	INT
		DECLARE @Count_Kit			INT
		
		IF ISNULL(@ID,0) = 0
			THROW 50008, 'ID lista non definito', 1

		IF ISNULL(@Id_Partizione,0) = 0
			THROW 50011, 'Partizione di destinazione lista non definita', 1

		SELECT	@Stato = Stato,
				@Data_Evasione = DT_EVASIONE
		FROM	Custom.TestataListePrelievo
		WHERE	ID = @ID
		
		IF @Stato = 2
			THROW 50009, 'Impossibile evadere un ordine già in esecuzione', 1
		ELSE IF @Stato IN (3,4)
			THROW 50010, 'Impossibile evadere un ordine già concluso', 1

		SELECT	@Count_Kit = COUNT(1)
		FROM	Custom.RigheListePrelievo
		WHERE	Id_Testata = @ID

		SELECT  @Count_Baie_Libere = (4 - COUNT(1))
		FROM	AwmConfig.vBaieKitting
		WHERE	Id_Testata_Lista = @ID

		IF @Count_Kit > @Count_Baie_Libere
			THROW 50008, 'NON CI SONO ABBASTANZA BAIE LIBERE PER I KIT DELLA LISTA',1

		--Se la lista non è stata ancora avviata
		IF @Stato = 1
		BEGIN
			DECLARE @Id_Tipo_Evento INT = 38
			DECLARE @XmlParam		XML = CONCAT('<Parametri><Id_Testata_Lista>',@ID,'</Id_Testata_Lista></Parametri>')

			--Evento per associare un kit alla baia
			EXEC @Return = sp_Insert_Eventi
						@Id_Tipo_Evento		= @Id_Tipo_Evento,
						@Id_Partizione		= @Id_Partizione,
						@Id_Tipo_Messaggio	= 1100,
						@XmlMessage			= @XmlParam,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore			OUTPUT

			IF @Return <> 0
				RAISERROR(@Errore,12,1)
		END

		--Avvio la lista di prelievo con flag Kitting
		EXEC [dbo].[sp_Avvia_Lista_Prelievo]
					@ID				= @ID,
					@FlagKit		= 1,
					@Id_Partizione	= @Id_Partizione,
					@Id_Processo	= @Id_Processo,
					@Origine_Log	= @Origine_Log,
					@Id_Utente		= @Id_Utente,
					@Errore			= @Errore			OUTPUT

		IF (ISNULL(@Errore, '') <> '')
			RAISERROR(@Errore, 1, 1)
		
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
