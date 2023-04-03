SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[sp_WBS_Cambia_Qta]
	@Id_UdcDettaglio		INT,
	@Id_Udc					INT,
	@ID_WBS					VARCHAR(25),
	@Id_Articolo			INT,
	@NewQty					INT,
	-- Parametri Standard;
	@Id_Processo			VARCHAR(30),
	@Origine_Log			VARCHAR(25),
	@Id_Utente				VARCHAR(32),
	@Errore					VARCHAR(500) OUTPUT
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT OFF;
	-- SET LOCK_TIMEOUT;

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure	VARCHAR(30)
	DECLARE @TranCount				INT
	DECLARE @Return					INT
	DECLARE @ErrLog					VARCHAR(500)

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		DECLARE @Qta_Nuova_UdcDettaglio			INT
		DECLARE @Id_UdcDettaglio_DaAggiornare	INT
		DECLARE @Qta_UdcDettaglio_DaAggiornare	INT
		DECLARE @Quantita_Attuale				INT

		SET @ID_WBS = SUBSTRING(@ID_WBS,2,LEN(@ID_WBS))

		IF @NewQty = 0
			THROW 50009,'Quantità specificata uguale a 0. Se si intendere rimuovere l''UDC dalla WBS selezionare il pulsante di cancellazione', 1

		SELECT	@Id_UdcDettaglio_DaAggiornare = Id_UdcDettaglio,
				@Qta_UdcDettaglio_DaAggiornare = Quantita_Pezzi
		FROM	Udc_Dettaglio
		WHERE	Id_Articolo = @Id_Articolo
			AND ISNULL(WBS_Riferimento,'') = ''
			AND Id_Udc = @Id_Udc
			AND Id_UdcDettaglio <> @Id_UdcDettaglio
		SELECT	@Quantita_Attuale = Quantita_Pezzi
		FROM	Udc_Dettaglio
		WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
		
		IF @Quantita_Attuale > @NewQty
			SET @Qta_Nuova_UdcDettaglio = @Quantita_Attuale - @NewQty
		ELSE
		BEGIN
			IF @Quantita_Attuale + ISNULL(@Qta_UdcDettaglio_DaAggiornare,0) < @NewQty
				THROW 50009, 'Quantità specificata maggiore di quella presente nell''UDC impossibile procedere',0
			ELSE
				SET @Qta_Nuova_UdcDettaglio = @NewQty
		END

		--controllo se ho un dettaglio dello stesso articolo non a progetto e nel caso unisco, altrimenti splitto.
		IF @Id_UdcDettaglio_DaAggiornare IS NULL
		BEGIN
			--creo una nuova udc con la quantita' wbs, mentre quella corrente la aggiorno con la differenza
			UPDATE	Udc_Dettaglio
			SET		Quantita_Pezzi = @Qta_Nuova_UdcDettaglio,
					WBS_Riferimento = ''
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
			
			EXEC sp_Update_Aggiorna_Contenuto_Udc
					@ID_UDC					= @ID_UDC,
					@ID_ARTICOLO			= @ID_ARTICOLO,
					@Qta_Pezzi_Input		= @NewQty,
					@WBS_CODE				= @ID_WBS,
					@Id_Causale_Movimento	= 3,
					@Id_Processo			= @Id_Processo,
					@Origine_Log			= @Origine_Log,
					@Id_Utente				= @Id_Utente,
					@Errore					= @Errore			OUTPUT
		END
		ELSE
		BEGIN
			DECLARE @Id_UdcDettaglio_Sorgente	INT = @Id_UdcDettaglio

			--SE QUELLA DA AGGIORNARE HA UNA QUANTITA' MINORE PASSO LA SUA IN AGGIUNTA, ALTRIMENTI PASSO LA MIA 
			IF ISNULL(@Qta_UdcDettaglio_DaAggiornare,0) < @Qta_Nuova_UdcDettaglio
			BEGIN
				SET @Id_UdcDettaglio_Sorgente = @Id_UdcDettaglio_DaAggiornare
				SET @Id_UdcDettaglio_DaAggiornare = @Id_UdcDettaglio 
				
				SET @Qta_Nuova_UdcDettaglio = @Qta_UdcDettaglio_DaAggiornare
			END

			EXEC sp_WBS_Gestisci_Dettagli
						@Id_UdcDettaglio_Sorgente		= @Id_UdcDettaglio_Sorgente,
						@Id_UdcDettaglio_Destinazione	= @Id_UdcDettaglio_DaAggiornare,
						@Qta_DaAggiungere				= @Qta_Nuova_UdcDettaglio,
						@Id_Processo					= @Id_Processo,
						@Origine_Log					= @Origine_Log,
						@Id_Utente						= @Id_Utente,
						@Errore							= @Errore			OUTPUT

			--AGGIORNO LA QUANTITA RIMUOVENDO DA QUELLA SORGENTE
			UPDATE	Udc_Dettaglio
			SET		Quantita_Pezzi -= @Qta_Nuova_UdcDettaglio
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio_Sorgente

			IF EXISTS (SELECT TOP 1 1 FROM Udc_Dettaglio WHERE Id_UdcDettaglio = @Id_UdcDettaglio_Sorgente AND Quantita_Pezzi = 0)
				EXEC sp_Update_Aggiorna_Contenuto_Udc
							@Id_Udc					= @Id_Udc,
							@Id_UdcDettaglio		= @Id_UdcDettaglio_Sorgente,
							@Id_Causale_Movimento	= 6,
							@Id_Processo			= @Id_Processo,
							@Origine_Log			= @Origine_Log,
							@Id_Utente				= @Id_Utente,
							@Errore					= @Errore OUTPUT
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
