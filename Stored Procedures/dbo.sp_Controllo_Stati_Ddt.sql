SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Controllo_Stati_Ddt]
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
		DECLARE @START DATETIME = GETDATE()

		--Aggiorno lo stato riga per tutti gli articoli
		UPDATE	roe
		SET		Stato = 2
		FROM	Custom.RigheOrdiniEntrata		roe
		JOIN	AwmConfig.vQtaRimanentiRigheDdt vqr
		ON		vqr.Id_Testata = roe.Id_Testata
			AND vqr.Id_Riga = roe.LOAD_LINE_ID
		WHERE	vqr.Quantita_Rimanente_Da_Specializzare = 0
			AND ROE.Stato <> 2

		DECLARE @Id_Testata_DdtR INT,
				@Id_Testata_DdtF INT,
				@Count_Righe INT

		DECLARE DdtRealiAperti CURSOR LOCAL FAST_FORWARD FOR
		--per gli ordini in corso o sospesi o già evasi con Mancanti che potrebbero essere inclusi da ingombranti
			SELECT	DISTINCT ID
			FROM	Custom.TestataOrdiniEntrata  WITH (NOLOCK)
			WHERE	Stato = 1
		
		OPEN DdtRealiAperti	
		FETCH NEXT FROM DdtRealiAperti INTO
			@Id_Testata_DdtR

		WHILE @@FETCH_STATUS = 0
		BEGIN		
			SELECT	@Count_Righe = COUNT(1)
			FROM	Custom.RigheOrdiniEntrata
			WHERE	Id_Testata = @Id_Testata_DdtR

			--SE NON HO RIGHE APERTE NEL DDT ALLORA AGGIORNO LO STATO A CHIUSO
			IF @Count_Righe > 0
					AND
				NOT EXISTS(SELECT TOP 1 1 FROM Custom.RigheOrdiniEntrata WHERE Id_Testata = @Id_Testata_DdtR AND Stato = 1)
				UPDATE	Custom.TestataOrdiniEntrata
				SET		Stato = 3
				WHERE	ID = @Id_Testata_DdtR

			FETCH NEXT FROM DdtRealiAperti INTO
				@Id_Testata_DdtR
		END
		
		CLOSE DdtRealiAperti
		DEALLOCATE DdtRealiAperti
		
		--Dopo aver aggiornato gli Stati Dei DDT reali aggiorno lo stato dei DDT fittizi
		DECLARE DdtFittiziAperti CURSOR LOCAL FAST_FORWARD FOR
			SELECT	DISTINCT ID
			FROM	Custom.AnagraficaDdtFittizi  WITH (NOLOCK)
			WHERE	Id_Stato IN (1,2)

		OPEN DdtFittiziAperti
		FETCH NEXT FROM DdtFittiziAperti INTO
			@Id_Testata_DdtF

		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF NOT EXISTS
			(
				SELECT	TOP 1 1
				FROM	dbo.Udc_Testata							UT
				JOIN	dbo.Udc_Posizione						UP
				ON		UP.Id_Udc = UT.Id_Udc
				JOIN	AwmConfig.vDestinazioniSpecializzazione	DS
				ON		DS.Id_Partizione = UP.Id_Partizione
				WHERE	UT.Id_Ddt_Fittizio = @Id_Testata_DdtF
			)
			BEGIN
				EXEC [dbo].[sp_Update_Stati_OrdiniSpecializzazione]
						@Id_Ddt_Fittizio	= @Id_Testata_DdtF,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore			OUTPUT

				IF (ISNULL(@Errore, '') <> '')
					THROW 50001, @Errore, 1;
			END

			FETCH NEXT FROM DdtFittiziAperti INTO
				@Id_Testata_DdtF
		END

		CLOSE DdtFittiziAperti
		DEALLOCATE DdtFittiziAperti
		
		DECLARE @TEMPO INT = DATEDIFF(MILLISECOND,@START,GETDATE())

		IF @TEMPO > 500
		BEGIN
			DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Gestione DDT Fittizi - TEMPO IMPIEGATO ',@TEMPO)
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
