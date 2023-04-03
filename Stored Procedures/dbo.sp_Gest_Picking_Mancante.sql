SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [dbo].[sp_Gest_Picking_Mancante]
		@Id_Evento					INT, 
		@Id_Udc						INT,
		@Id_UdcDettaglio			INT,
		@Id_Testata					INT,
		@Id_Riga					INT,
		@Id_Articolo				INT,
		@QUANTITA_MANCANTE			NUMERIC(10,3),
		@QUANTITA_PRESENTE_SU_UDC	NUMERIC(10,3),
		@QUANTITA_PRELEVATA			NUMERIC(10,3) = NULL,
		@Missione_Modula			INT = 0,
		@Invia_Dati_A_Sap			INT = 1,
		--Campi Ddt dell'UdcDettaglio,
		@Id_Riga_Ddt				INT,
		@Id_Ddt_Reale				INT,
		-- Parametri Standard;
		@Id_Processo				VARCHAR(30),
		@Origine_Log				VARCHAR(25),
		@Id_Utente					VARCHAR(32),
		@Errore						VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure VARCHAR(30)
	DECLARE @TranCount INT
	DECLARE @Return INT
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = OBJECT_NAME(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @Qta_Prelievo	INT = 0
		DECLARE @Ristocca_Udc	BIT = 0

		IF @QUANTITA_PRELEVATA IS NOT NULL
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM Articoli WHERE Id_Articolo = @Id_Articolo AND Unita_Misura IN ('PZ','NR'))
				THROW 50001, 'IMPOSSIBILE PRELEVARE QTA DIVERSE PER UNITA DI MISURA PEZZI/NUMERO',1;

			IF @QUANTITA_PRESENTE_SU_UDC < @QUANTITA_PRELEVATA
				THROW 50001, 'IMPOSSIBILE PRELEVARE QTA MAGGIORE DI QUELLA PRESENTE SULL''UDC',1;

			SET @Qta_Prelievo = @QUANTITA_PRELEVATA
		END
		ELSE IF @QUANTITA_PRESENTE_SU_UDC >= @QUANTITA_MANCANTE
			SET @Qta_Prelievo = @QUANTITA_MANCANTE
		ELSE
			SET @Qta_Prelievo = @QUANTITA_PRESENTE_SU_UDC

		--INSERISCO IL RECORD PER STAMPARE QUANTO PRELEVATO --> LO FACCIO PRIMA DI MODIFICARE UN QUALSIASI DATO
		EXEC Printer.sp_InsertAdditionalRequest_Mancanti
				@Id_UdcDettaglio	= @Id_UdcDettaglio,
				@Id_Evento			= @Id_Evento,
				@Id_Articolo		= @Id_Articolo,
				@Quantita_Articolo	= @Qta_Prelievo,
				@Id_Riga_Lista		= @Id_Riga,
				@Id_Testata_Lista	= @Id_Testata,
				@Id_Processo		= @Id_Processo,
				@Origine_Log		= @Origine_Log,
				@Id_Utente			= @Id_Utente,
				@Errore				= @Errore				OUTPUT

		--Aggiorno la tabella Mancanti
		UPDATE	Custom.AnagraficaMancanti
		SET		Qta_Mancante = CASE WHEN @Qta_Prelievo > Qta_Mancante THEN 0 ELSE Qta_Mancante - @Qta_Prelievo END
		WHERE	Id_Testata = @Id_Testata
			AND Id_Riga = @Id_Riga

		--Aggiungo il record allo storico se è un udc in specializzazione
		IF @Id_Riga_Ddt <> 0
		BEGIN
			INSERT INTO Custom.StoricoPrelievoMancanti
				(Id_Testata_Ddt_Reale, Id_Riga_Ddt_Reale, Id_Riga_Lista_Prelievo, Id_Udc, Quantita_Prelevata)
			VALUES
				(@Id_Ddt_Reale,@Id_Riga_Ddt, @Id_Riga, @Id_Udc, @Qta_Prelievo)
			
			--SE E' VERSO MODULA DEVO LANCIARE UN CONSUNTIVO ISTANTANEO DI CARICO VERSO ERP PRIMA DI 	
			IF @Missione_Modula = 1
			BEGIN
				EXEC [dbo].[sp_Genera_Consuntivo_EntrataLista]
								@Id_Udc				= @Id_Udc,
								@Id_Testata_Ddt		= @Id_Ddt_Reale,
								@Id_Riga_Ddt		= @Id_Riga_Ddt,
								@Qta_Entrata		= @Qta_Prelievo,
								@Fl_Quality_Check	= 0,
								@Fl_Void			= 0,
								@Id_Processo		= @Id_Processo,
								@Origine_Log		= @Origine_Log,
								@Id_Utente			= @Id_Utente,
								@Errore				= @Errore OUTPUT

				IF (ISNULL(@Errore, '') <> '')
					THROW 50006, @Errore, 1

				--AGGIORNO LO STATO DEL DDT REALE
				EXEC [dbo].[sp_Update_Stati_OrdiniEntrata]
							@Id_Riga		= @Id_Riga,
							@Id_Testata		= @Id_Ddt_Reale,
							@FlagChiusura	= 0,
							@SpecModula		= 1,
							@Id_Processo	= @Id_Processo,
							@Origine_Log	= @Origine_Log,
							@Id_Utente		= @Id_Utente,
							@Errore			= @Errore			OUTPUT
				
				IF (ISNULL(@Errore, '') <> '')
					THROW 50001, @Errore, 1
			END
		END

		--Lo considero picking manuale sull'Udc stessa
		EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
				@Id_Udc					= @Id_Udc,
				@Id_UdcDettaglio		= @Id_UdcDettaglio, 
				@Id_Articolo			= @Id_Articolo,
				@Qta_Pezzi_Input		= @Qta_Prelievo,
				@Id_Testata_Lista		= @Id_Testata,
				@Id_Riga_Lista			= @Id_Riga,
				@Id_Causale_Movimento	= 2,
				@Id_Processo			= @Id_Processo,
				@Origine_Log			= @Origine_Log,
				@Id_Utente				= @Id_Utente,
				@Errore					= @Errore				OUTPUT

		EXEC sp_Genera_Consuntivo_Mancanti
			@Id_Testata		= @Id_Testata,
			@Id_Riga		= @Id_Riga,
			@Id_Articolo	= @Id_Articolo,
			@Qta_Prelievo	= @Qta_Prelievo,
			@Id_Processo	= @Id_Processo,
			@Origine_Log	= @Origine_Log,
			@Id_Utente		= @Id_Utente,
			@Errore			= @Errore			OUTPUT

		IF NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	AwmConfig.vUdcPrelievoMancanti
							WHERE	Id_Udc = @Id_Udc
								AND Id_Articolo = @Id_Articolo
						)
		BEGIN
			EXEC [dbo].[sp_Chiudi_Prelievo_Mancanti]
					@Missione_Modula	= @Missione_Modula,
					@Id_Evento			= @Id_Evento,
					@Id_Udc				= @Id_Udc,
					@Invia_Dati_A_Sap	= @Invia_Dati_A_Sap,
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Id_Utente			= @Id_Utente,
					@Errore				= @Errore OUTPUT

			IF (ISNULL(@Errore, '') <> '')
				THROW 50002, @Errore, 1;

			SET @Ristocca_Udc = 1
		END

		IF EXISTS	(
						SELECT	TOP 1 1
						FROM	Missioni_Picking_Dettaglio
						WHERE	Id_Testata_Lista = @Id_Testata
							AND Id_Riga_Lista = @Id_Riga
							AND FL_MANCANTI = 1
							AND Id_Stato_Missione = 2
					)
			UPDATE	Missioni_Picking_Dettaglio
			SET		Id_Stato_Missione =	CASE
											WHEN Quantita = (Qta_Prelevata + @Qta_Prelievo) THEN 4
											ELSE Id_Stato_Missione
										END,
					Qta_Prelevata += @Qta_Prelievo,
					DataOra_UltimaModifica = GETDATE()
			WHERE	Id_Testata_Lista = @Id_Testata
				AND Id_Riga_Lista = @Id_Riga
				AND FL_MANCANTI = 1
				AND Id_Stato_Missione = 2

		IF	@Ristocca_Udc = 1
			AND
			EXISTS	(
						SELECT	TOP 1 1
						FROM	Missioni_Picking_Dettaglio
						WHERE	Id_Testata_Lista = @Id_Testata
							AND Id_Riga_Lista = @Id_Riga
							AND FL_MANCANTI = 1
							AND Id_Udc = @Id_Udc
							AND Id_UdcDettaglio = @Id_UdcDettaglio
							AND (Id_Stato_Missione = 4 OR Quantita = Qta_Prelevata)
					)
			EXEC sp_Stocca_Udc
					@ID_UDC						= @Id_Udc,
					@ID_EVENTO					= @Id_Evento,
					@ID_TESTATA_LISTA			= @Id_Testata,
					@ID_PROCESSO				= @Id_Processo,
					@ORIGINE_LOG				= @ORIGINE_LOG,
					@ID_UTENTE					= @Id_Utente,
					@ERRORE						= @Errore				OUTPUT
	

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
