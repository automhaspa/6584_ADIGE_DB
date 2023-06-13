SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[sp_Avvia_OrdineSpecializzazione]
	--Id del Ddt Fake
	@ID					INT = NULL,
	@Id_Partizione		INT,
	@Id_Ddt_Fittizio	INT = NULL,
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
	SET @Nome_StoredProcedure = Object_Name(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT;

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		DECLARE @Stato			INT = 0
		DECLARE @CountUdc		INT = 0
		DECLARE @TotalCount		INT

		IF ISNULL(@Id_Partizione,0) = 0
			THROW 50011, 'Partizione di destinazione lista non definita', 1

		IF ISNULL(@ID, 0) = 0
			SET @ID = @Id_Ddt_Fittizio

		IF ISNULL(@ID,0) = 0
			THROW 50008, 'ID Codice ddt non definito', 1

		IF @Id_Partizione = 7685 AND EXISTS(SELECT TOP 1 1 FROM Udc_Testata WHERE Id_Ddt_Fittizio = @ID AND Id_Tipo_Udc <>'M')
			THROW 50001, 'IMPOSSIBILE AVVIARE LA SPECIALIZZAZIONE VERSO LA BAIA ADIGE 1 SE SONO PREVISTE UDC DI ADIGE 7',1

		SELECT	@Stato = Id_Stato
		FROM	Custom.AnagraficaDdtFittizi
		WHERE	ID = @ID

		IF @Stato = 2
			THROW 50009, 'Impossibile avviare un ordine già in esecuzione', 1
		ELSE IF @Stato IN (3,4)
			THROW 50010, 'Impossibile avviare un ordine già concluso', 1
		
		IF @Id_Partizione = 3101
			THROW 50012, 'ORDINI DI SPECIALIZZAZIONE AVVIABILI ESCLUSIVAMENTE DALLE BAIE DI SPECIALIZZAZIONE', 1

		--Recupero il numero di Udc entrate con quel codice
		SELECT	@CountUdc = COUNT(Id_Udc)
		FROM	Udc_Testata
		WHERE	Id_Ddt_Fittizio = @ID

		IF ISNULL(@CountUdc,0) = 0
			THROW 50013, 'NESSUNA UDC ASSOCIATA A QUESTO ORDINE DI SPECIALIZZAZIONE',1

		SELECT	@TotalCount = ISNULL(N_Udc_Tipo_A,0) + ISNULL(N_Udc_Tipo_B,0) + ISNULL(N_Udc_Ingombranti,0)
		FROM	Custom.AnagraficaDdtFittizi
		WHERE	ID = @ID

		IF @CountUdc < ISNULL(@TotalCount,0)
			THROW 50013, 'NON SONO STATE INSERITE A MAGAZZINO LE UDC DICHIARATE NEL DDT',1

		IF @Stato <> 5
		BEGIN
			DECLARE @Id_Udc							INT
			DECLARE @Id_Tipo_Udc					VARCHAR(1)
			DECLARE @Id_Partizione_Destinazione		INT
			
			DECLARE CursoreUdc CURSOR LOCAL FAST_FORWARD FOR
				SELECT	Id_Udc,
						Id_Tipo_Udc
				FROM	Udc_Testata
				WHERE	Id_Ddt_Fittizio = @ID
					AND Id_Tipo_Udc NOT IN ('I','M')

			OPEN CursoreUdc
			FETCH NEXT FROM CursoreUdc INTO
				@Id_Udc,
				@Id_Tipo_Udc

			WHILE @@FETCH_STATUS = 0
			BEGIN
				--In base al tipo_udc creo un record missione con destinazione diversa
				IF @Id_Tipo_Udc IN ('1','2','3')
					SET	@Id_Partizione_Destinazione = @Id_Partizione
				ELSE IF @Id_Tipo_Udc IN ('4','5','6') --Baia outbound 3B03
					SET @Id_Partizione_Destinazione = 3203
				ELSE
					THROW 50034, 'TIPO UDC NON DEFINITO',1

				IF NOT EXISTS(SELECT TOP 1 1 FROM Custom.MissioniSpecializzazioneDettaglio WHERE Id_Ddt_Fittizio = @ID AND Id_Udc = @Id_Udc)
				--Inserisco la missione di specializzazione in stato 1
					INSERT INTO Custom.MissioniSpecializzazioneDettaglio
					VALUES (@ID, @Id_Udc, @Id_Partizione_Destinazione, 0)

				FETCH NEXT FROM CursoreUdc INTO
					@Id_Udc,
					@Id_Tipo_Udc
			END
    
			CLOSE CursoreUdc
			DEALLOCATE CursoreUdc

			--Aggiorno lo stato dell'ordine di specializzazione
			UPDATE	Custom.AnagraficaDdtFittizi
			SET		Id_Stato = 2
			WHERE	ID = @ID

			DECLARE @Action XML = CONCAT('<Parametri><Id_Ddt_Fittizio>',@ID,'</Id_Ddt_Fittizio></Parametri>')
			--Se esiste materiale ingombrante avvio l'evento in baia imgombranti per la specializzazione
			IF EXISTS(SELECT TOP 1 1 FROM [AwmConfig].[vDdtFittizioUdcIngombranti] WHERE Id_Ddt_Fittizio = @ID AND Id_Tipo_Udc = 'I')
			BEGIN
				EXEC [dbo].[sp_Insert_Eventi]
					@Id_Tipo_Evento		= 42,	--GESTIONE INGOMBRANTI
					@Id_Partizione		= 7684,
					@Id_Tipo_Messaggio	= '1100',
					@XmlMessage			= @Action,
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Id_Utente			= @Id_Utente,
					@Errore				= @Errore			OUTPUT

				IF ISNULL(@Errore, '') <> ''
					RAISERROR(@Errore,12,1)
			END

			IF EXISTS(SELECT TOP 1 1 FROM [AwmConfig].[vDdtFittizioUdcIngombranti] WHERE Id_Ddt_Fittizio = @ID AND Id_Tipo_Udc = 'M')
			BEGIN
				EXEC [dbo].[sp_Insert_Eventi]
					@Id_Tipo_Evento		= 42,	--GESTIONE INGOMBRANTI
					@Id_Partizione		= 7685,
					@Id_Tipo_Messaggio	= '1100',
					@XmlMessage			= @Action,
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Id_Utente			= @Id_Utente,
					@Errore				= @Errore			OUTPUT

				IF ISNULL(@Errore, '') <> ''
					RAISERROR(@Errore,12,1)
			END
		END
		ELSE
		BEGIN
			UPDATE	Custom.AnagraficaDdtFittizi
			SET		Id_Stato = 2
			WHERE	ID = @ID

			UPDATE	M
			SET		M.Id_Partizione_Destinazione = @Id_Partizione
			FROM	Custom.MissioniSpecializzazioneDettaglio		M
			JOIN	Udc_Testata										UT
			ON		M.Id_udc = UT.Id_Udc
			WHERE	M.Id_Partizione_Destinazione IN (3301, 3302, 3501)
				AND M.Id_Ddt_Fittizio = @ID
				AND UT.Specializzazione_Completa <> 1
		END

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
