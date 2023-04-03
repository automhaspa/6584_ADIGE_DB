SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE PROCEDURE [dbo].[sp_Gest_Picking_Completo]
	@Id_Evento				INT,
	@Id_Udc					INT,
	@CODICE_ARTICOLO		VARCHAR(30),
	@QuantitaDaPrelevare	NUMERIC(10,2),
	@Id_Riga_Lista			INT,
	@Id_Testata_Lista		INT,
	-- Parametri Standard;
	@Id_Processo			VARCHAR(30),
	@Origine_Log			VARCHAR(25),
	@Id_Utente				VARCHAR(32),
	@Errore					VARCHAR(500) OUTPUT
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
		DECLARE @IdArticoloAutomha		INT
		DECLARE @IdUdcDettaglio			INT
		DECLARE @Qta_Gia_Prelevata		NUMERIC(10,2)
		DECLARE @Qta_Da_Prelevare_Calc	NUMERIC(10,2)
		
		SELECT	@IdArticoloAutomha = a.Id_Articolo,
				@IdUdcDettaglio = mpd.Id_UdcDettaglio,
				@Qta_Gia_Prelevata = Qta_Prelevata
		FROM	Missioni_Picking_Dettaglio	mpd
		JOIN	Articoli					a
		ON		mpd.Id_Articolo = a.Id_Articolo
		WHERE	Id_Udc = @Id_Udc
			AND Id_Testata_Lista = @Id_Testata_Lista
			AND Id_Riga_Lista = @Id_Riga_Lista
			AND Id_Stato_Missione = 2

		IF (@Qta_Gia_Prelevata > 0)
			THROW 50001, ' PICKING COMPLETO UTILIZZABILE SOLO SE LA QUANTITA'' PRELEVATA DELL ARTICOLO E'' UGUALE A 0', 1

		--AGGIUNGO IL RECORD PER LA STAMPA AUTOMATICA PRIMA DI PERDERE UN QUALSIASI DATO
		EXEC [Printer].[sp_InsertAdditionalRequest_Picking]
				@Id_Evento			= @Id_Evento,
				@Id_Articolo		= @IdArticoloAutomha,
				@Quantita_Articolo	= @QuantitaDaPrelevare,
				@Id_Riga_Lista		= @Id_Riga_Lista,
				@Id_Testata_Lista	= @Id_Testata_Lista,
				@Id_Processo		= @Id_Processo,
				@Origine_Log		= @Origine_Log,
				@Id_Utente			= @Id_Utente,
				@Errore				= @Errore				OUTPUT

		--Causale 1 picking da lista con aggiornamento dello
		EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc	
							@Id_Udc					= @Id_Udc,
							@Id_UdcDettaglio		= @IdUdcDettaglio, 
							@Id_Articolo			= @IdArticoloAutomha,
							@Qta_Pezzi_Input		= @QuantitaDaPrelevare,
							@Id_Causale_Movimento	= 1,
							@Id_Riga_Lista			= @Id_Riga_Lista,
							@Id_Testata_Lista		= @Id_Testata_Lista,
							@Id_Processo			= @Id_Processo,
							@Origine_Log			= @Origine_Log,
							@Id_Utente				= @Id_Utente,
							@Errore					= @Errore OUTPUT	

		--Controllo packing list
		EXEC [dbo].[sp_Gest_Packing_List]
				@Id_Testata_Lista_Prelievo	= @Id_Testata_Lista,
				@Quantita					= @QuantitaDaPrelevare,
				@Id_Articolo				= @IdArticoloAutomha,
				@Id_Evento_Picking			= @Id_Evento,
				@Id_Processo				= @Id_Processo,
				@Origine_Log				= @Origine_Log,
				@Id_Utente					= @Id_Utente,
				@Errore						= @Errore OUTPUT

		IF (ISNULL(@Errore, '') <> '')
			RAISERROR(@Errore, 12, 1)

		--CONTROLLO SE E' FINITA LA LISTA PER QUELL'UDC
		DECLARE @ArticoliUdcDaPrelevare		INT
		DECLARE @ArticoliUdcPrelevati		INT
		
		SELECT @ArticoliUdcDaPrelevare = COUNT(1) FROM Missioni_Picking_Dettaglio WHERE Id_Udc = @Id_Udc AND Id_Testata_Lista = @Id_Testata_Lista
		SELECT @ArticoliUdcPrelevati = COUNT(1) FROM Missioni_Picking_Dettaglio WHERE  Id_Udc = @Id_Udc AND Id_Testata_Lista = @Id_Testata_Lista AND Id_Stato_Missione IN (4)

		--Se ho completato la lista per l'udc la stocco in automatico
		IF (@ArticoliUdcDaPrelevare = @ArticoliUdcPrelevati)
		BEGIN
			DECLARE @Id_Partizione INT
			SELECT	@Id_Partizione = Id_Partizione
			FROM	Udc_Posizione
			WHERE	Id_Udc = @Id_Udc

			--Se mi trovo nelle baie di picking
			IF (@Id_Partizione NOT IN (3203))
			BEGIN
				DECLARE	@return_value INT
				EXEC @return_value = [dbo].[sp_Stocca_Udc]
						@Id_Udc				= @Id_Udc,
						@Id_Testata_Lista	= @Id_Testata_Lista,
						@Id_Evento			= @Id_Evento,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore OUTPUT
			END
			--Se mi trovo in 3B03 elimino l'evento di Picking Lista
			ELSE
				DELETE	Eventi
				WHERE	Id_Evento = @Id_Evento
		END

		--EVENTO TEMPORANEO PER AVVISARE LA DELLA FINE LISTA
		DECLARE	@RigheTot		INT
		DECLARE @RigheComplete	INT

		SELECT @RigheTot = COUNT(1) FROM Missioni_Picking_Dettaglio WHERE Id_Udc <> 702 AND Id_Testata_Lista = @Id_Testata_Lista
		SELECT @RigheComplete = COUNT(1) FROM Missioni_Picking_Dettaglio WHERE  Id_Udc <> 702 AND Id_Testata_Lista = @Id_Testata_Lista AND Id_Stato_Missione = 4
		
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

		IF (@RigheTot = @RigheComplete)
		BEGIN
			DECLARE @testatalista VARCHAR(30)
			DECLARE @CAUSALELISTA VARCHAR(3)

			SELECT	@testatalista = ORDER_ID,
					@CAUSALELISTA = ORDER_TYPE
			FROM	Custom.TestataListePrelievo
			WHERE	ID = @Id_Testata_Lista

			SET @Errore = CONCAT ('Picking eseguito, LISTA CONCLUSA LATO AUTOMHA, ORDER ID : ' ,  @testatalista, '  CAUSALE: ', @CAUSALELISTA)
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
