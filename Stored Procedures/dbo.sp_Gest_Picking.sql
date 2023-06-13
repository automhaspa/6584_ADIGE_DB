SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_Gest_Picking]
	@Id_Evento			INT,
	@Id_Udc				INT,
	@CODICE_ARTICOLO	VARCHAR(30),
	@Qta_Prelevata		NUMERIC(10,2)	= NULL,
	@Id_Riga_Lista		INT				= NULL,
	@Id_Testata_Lista	INT				= NULL,
	-- Parametri Standard;
	@Id_Processo		VARCHAR(30),
	@Origine_Log		VARCHAR(25),
	@Id_Utente			VARCHAR(32),
	@Errore				VARCHAR(500)	OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		-- Dichiarazioni Variabili;
		DECLARE	@IdArticoloAutomha	INT
		DECLARE @WBS_RIGA_LISTA		VARCHAR(MAX)

		DECLARE @IdUdcDettaglio		INT
		DECLARE @QdRigaLista		INT

		SELECT	@IdArticoloAutomha = Id_Articolo
		FROM	Articoli
		WHERE	Codice = @CODICE_ARTICOLO
		
		IF @Id_Riga_Lista IS NULL
			SELECT	@Id_Riga_Lista = ISNULL(Id_Riga_Lista,0),
					@Id_Testata_Lista = ISNULL(Id_Testata_Lista,0)
			FROM	Missioni_Picking_Dettaglio
			WHERE	Id_Udc = @Id_Udc
				AND Id_Articolo = @IdArticoloAutomha
				AND Id_Stato_Missione = 2
		
		SELECT	@WBS_RIGA_LISTA = CASE WHEN ISNULL(Vincolo_WBS,0) = 0 THEN NULL ELSE WBS_Riferimento END
		FROM	Custom.RigheListePrelievo
		WHERE	ID = @Id_Riga_Lista

		SELECT	@IdUdcDettaglio = Id_UdcDettaglio
		FROM	Udc_Dettaglio
		WHERE	Id_Udc = @Id_Udc
			AND Id_Articolo = @IdArticoloAutomha
			AND ISNULL(WBS_RIFERIMENTO,'') = ISNULL(@WBS_RIGA_LISTA,'')

		--AGGIUNGO IL RECORD PER LA STAMPA AUTOMATICA PRIMA DI PERDERE UN QUALSIASI DATO
		EXEC [Printer].[sp_InsertAdditionalRequest_Picking]
				@Id_Evento			= @Id_Evento,
				@Id_Articolo		= @IdArticoloAutomha,
				@Quantita_Articolo	= @Qta_Prelevata,
				@Id_Riga_Lista		= @Id_Riga_Lista,
				@Id_Testata_Lista	= @Id_Testata_Lista,
				@Id_Processo		= @Id_Processo,
				@Origine_Log		= @Origine_Log,
				@Id_Utente			= @Id_Utente,
				@Errore				= @Errore				OUTPUT

		--Causale 1 picking da lista
		EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
				@Id_Udc					= @Id_Udc,
				@Id_UdcDettaglio		= @IdUdcDettaglio,
				@Id_Articolo			= @IdArticoloAutomha,
				@Qta_Pezzi_Input		= @Qta_Prelevata,
				@Id_Causale_Movimento	= 1,
				@Id_Riga_Lista			= @Id_Riga_Lista,
				@Id_Testata_Lista		= @Id_Testata_Lista,
				@Id_Processo			= @Id_Processo,
				@Origine_Log			= @Origine_Log,
				@Id_Utente				= @Id_Utente,
				@Errore					= @Errore			OUTPUT
							
		--Controllo packing list
		EXEC [dbo].[sp_Gest_Packing_List]
				@Id_Testata_Lista_Prelievo	= @Id_Testata_Lista,
				@Quantita					= @Qta_Prelevata,
				@Id_Articolo				= @IdArticoloAutomha,
				@Id_Evento_Picking			= @Id_Evento,
				@Id_Processo				= @Id_Processo,
				@Origine_Log				= @Origine_Log,
				@Id_Utente					= @Id_Utente,
				@Errore						= @Errore			OUTPUT

		IF ISNULL(@Errore, '') <> ''
			RAISERROR(@Errore, 12, 1)

		--CONTROLLO SE E' FINITA LA LISTA PER QUELL'UDC
		DECLARE	@ArticoliUdcDaPrelevare INT
		DECLARE @ArticoliUdcPrelevati	INT

		SELECT	@ArticoliUdcDaPrelevare = COUNT(1)
		FROM	Missioni_Picking_Dettaglio
		WHERE	Id_Udc = @Id_Udc
			AND Id_Testata_Lista = @Id_Testata_Lista

		SELECT	@ArticoliUdcPrelevati = COUNT(1)
		FROM	Missioni_Picking_Dettaglio
		WHERE	Id_Udc = @Id_Udc
			AND Id_Testata_Lista = @Id_Testata_Lista
			AND	Id_Stato_Missione = 4

		--Se ho completato la lista per l'udc la stocco in automatico
		IF @ArticoliUdcDaPrelevare = @ArticoliUdcPrelevati
		BEGIN
			DECLARE @Id_Partizione	INT
			SELECT	@Id_Partizione = Id_Partizione
			FROM	Udc_Posizione
			WHERE	Id_Udc = @Id_Udc

			--Se mi trovo nelle baie di picking
			IF @Id_Partizione <> 3203
			BEGIN
				DECLARE	@return_value INT
				EXEC @return_value = [dbo].[sp_Stocca_Udc]
								@Id_Udc				= @Id_Udc,
								@Id_Testata_Lista	= @Id_Testata_Lista,
								@Id_Evento			= @Id_Evento,
								@Id_Processo		= @Id_Processo,
								@Origine_Log		= @Origine_Log,
								@Id_Utente			= @Id_Utente,
								@Errore				= @Errore		OUTPUT
			END
			ELSE
				--Elimino l'evento di Picking Lista 
				DELETE	Eventi
				WHERE	Id_Evento = @Id_Evento
		END

		--EVENTO TEMPORANEO PER AVVISARE LA DELLA FINE LISTA
		DECLARE	@RigheTot		INT
		DECLARE @RigheComplete	INT

		SELECT	@RigheTot = COUNT(1)
		FROM	Missioni_Picking_Dettaglio
		WHERE	Id_Udc <> 702
			AND Id_Testata_Lista = @Id_Testata_Lista
		
		SELECT	@RigheComplete = COUNT(1)
		FROM	Missioni_Picking_Dettaglio
		WHERE	Id_Udc <> 702
			AND Id_Testata_Lista = @Id_Testata_Lista
			AND Id_Stato_Missione = 4

		IF NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	Missioni_Picking_Dettaglio
							WHERE	Id_Testata_Lista = @Id_Testata_Lista
								AND Id_Riga_Lista = @Id_Riga_Lista
								AND Id_Stato_Missione <> 4
						)
			UPDATE	Custom.RigheListePrelievo
			SET		Stato = 4
			WHERE	Id_Testata = @Id_Testata_Lista
				AND ID = @Id_Riga_Lista

		IF @RigheTot = @RigheComplete
		BEGIN
			DECLARE @TestataLista	VARCHAR(30)
			DECLARE @CAUSALELISTA	VARCHAR(3)

			SELECT	@TestataLista = ORDER_ID,
					@CAUSALELISTA = ORDER_TYPE
			FROM	Custom.TestataListePrelievo
			WHERE	ID = @Id_Testata_Lista

			DECLARE @Id_Evento_RigheAttive INT
			SELECT	@Id_Evento_RigheAttive = Id_Evento
			FROM	EVENTI
			WHERE	Id_Tipo_Evento = 7
				AND Xml_Param.value('data(//Parametri//Id_Testata_Lista)[1]','int') = @Id_Testata_Lista

			IF @Id_Evento_RigheAttive IS NOT NULL
				DELETE	EVENTI
				WHERE	Id_Evento = @Id_Evento_RigheAttive
			
			SET @Errore = CONCAT ('Picking eseguito, LISTA CONCLUSA LATO AUTOMHA, ORDER ID : ', @TestataLista, ' CAUSALE: ', @CAUSALELISTA)
		END

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION
		-- Return 1 se tutto è andato a buon fine;
		RETURN 0
	END TRY
	BEGIN CATCH
		-- Valorizzo l'errore con il nome della procedura corrente seguito dall'errore scatenato nel codice;
		SET @Errore = @Nome_StoredProcedure + ';' + ERROR_MESSAGE()
		-- Eseguo il rollback ed inserisco il log solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 
		BEGIN
			ROLLBACK TRANSACTION
			
			EXEC sp_Insert_Log	@Id_Processo = @Id_Processo
								,@Origine_Log = @Origine_Log
								,@Proprieta_Log = @Nome_StoredProcedure
								,@Id_Utente = @Id_Utente
								,@Id_Tipo_Log = 4
								,@Id_Tipo_Allerta = 0
								,@Messaggio = @Errore
								,@Errore = @Errore OUTPUT
		END
		-- Return 0 se la procedura è andata in errore;
		RETURN 1
	END CATCH
END

GO
