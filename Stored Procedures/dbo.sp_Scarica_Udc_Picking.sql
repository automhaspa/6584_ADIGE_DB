SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Scarica_Udc_Picking]
	@ScaricaUdc		BIT = 0,
	@Id_Udc			INT,
	@Id_Evento		INT,
	@GetEmpty		BIT = 0,
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
		DECLARE @Id_Partizione_Scarico INT

		IF ISNULL(@Id_Udc, 0) = 0
			THROW 50009, 'ID_UDC NON DEFINITO',1

		IF @Id_Utente IN ('awm', 'plccom')
			THROW 50001, 'ATTENZIONE, NON SEI AUTENTICATO!',1

		SELECT	@Id_Partizione_Scarico = Id_Partizione
		FROM	Udc_Posizione
		WHERE	Id_Udc = @Id_Udc

		IF @ScaricaUdc = 1
		BEGIN
			DECLARE @IdArticolo			INT
			DECLARE @IdRigaLista		INT
			DECLARE @Quantita			NUMERIC(10,2)
			DECLARE @IdTestataLista		INT
			DECLARE @IdUdcDettaglio		INT

			SELECT	@IdTestataLista = Id_Testata_Lista
			FROM	Missioni_Picking_Dettaglio
			WHERE	Id_Udc = @Id_Udc
				AND Id_Stato_Missione = 2 --Missione Attiva

			--CICLO TUTTI GLI ARTICOLI IN LISTA SU QUEL UDC
			DECLARE CursoreArticoli CURSOR LOCAL FAST_FORWARD FOR
				SELECT	Id_Articolo,
						Id_Riga_Lista,
						Quantita,
						Id_UdcDettaglio
				FROM	Missioni_Picking_Dettaglio
				WHERE	Id_Testata_Lista = @IdTestataLista
					AND Id_Udc = @Id_Udc
					AND Id_Stato_Missione = 2

			OPEN CursoreArticoli
			FETCH NEXT FROM CursoreArticoli INTO
				@IdArticolo,
				@IdRigaLista,
				@Quantita,
				@IdUdcDettaglio

			WHILE @@FETCH_STATUS = 0
			BEGIN
				UPDATE	Missioni_Picking_Dettaglio
				SET		Qta_Prelevata = @Quantita,
						Id_Stato_Missione = 4,
						DataOra_Evasione = GETDATE()
				WHERE	Id_Udc = @Id_Udc
					AND Id_Testata_Lista = @IdTestataLista
					AND Id_Riga_Lista = @IdRigaLista

				--GENERO CONSUNTIVO VERSO L3 PER GLI ANNULLAMENTI RIGA DALLO STOCCA UDC
				EXEC [dbo].[sp_Genera_Consuntivo_PrelievoLista]
							@Id_Udc				= @Id_Udc,
							@Id_Testata_Lista	= @IdTestataLista,
							@Id_Riga_Lista		= @IdRigaLista,
							@Qta_Prelevata		= @Quantita,
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Id_Utente			= @Id_Utente,
							@Errore				= @Errore				OUTPUT

				IF ISNULL(@Errore, '') <> ''
					THROW 50100, @Errore, 1

				--PER LO STORICO CUSTOM AGGIORNO PER OGNI UDC DETTAGLIO DELL'UDC CHE STO PER ELIMINARE I DATI SU TESTATA LISTA E RIGA LISTA
				UPDATE	Udc_Dettaglio 
				SET		Id_Testata_Lista_Prelievo = @IdTestataLista,
						Id_Riga_Lista_Prelievo = @IdRigaLista,
						Id_Ddt_Reale = NULL,
						Id_Riga_Ddt = NULL,
						Id_Causale_L3 = NULL
				WHERE	Id_UdcDettaglio = @IdUdcDettaglio

				FETCH NEXT FROM CursoreArticoli INTO
					@IdArticolo,
					@IdRigaLista,
					@Quantita,
					@IdUdcDettaglio
			END

			CLOSE CursoreArticoli
			DEALLOCATE CursoreArticoli

			DECLARE @Id_Packing_List INT
			SELECT	@Id_Packing_List = Id_Packing_List
			FROM	Custom.PackingLists
			WHERE	Id_Testata_Lista_Prelievo = @IdTestataLista

			--CONTROLLO SE LA LISTA DI PRELIEVO DELL'UDC HA UNA PACKING LIST
			--SE LA LISTA DELL UDC FA PARTE DI UNA PACKING LIST ALLORA CONSIDERO TUTTA L'UDC COME UNA PACKING A SE STANTE
			IF @Id_Packing_List IS NOT NULL
			BEGIN
				--NON ELIMINO L'UDC MA AGGIRONO LA POSIZIONE E LA CONSIDERO COME PACKING LIST
				INSERT INTO Custom.PackingLists_UdcTestata
				VALUES (@Id_Udc, @Id_Packing_List, 0)

				UPDATE	Udc_Posizione
				SET		Id_Partizione = CASE
											WHEN (Id_Partizione = 3403) THEN 7737	--5A06.0001.0001
											WHEN (Id_Partizione = 3603) THEN 7738	--5A06.0002.0001
										END
				WHERE	Id_Udc = @Id_Udc
			END
			ELSE
			BEGIN
				--Aggiorno le liste di prelievo relative all'UDc E la elimino
				DECLARE	@ReturnValue		INT
				EXEC @ReturnValue = [dbo].[sp_Delete_EliminaUdc]
							@Id_Udc			= @Id_Udc,
							@Id_Processo	= @Id_Processo,
							@Origine_Log	= @Origine_Log,
							@Id_Utente		= @Id_Utente,
							@Errore			= @Errore		OUTPUT
			END
		END
		ELSE IF @ScaricaUdc = 0
		BEGIN
			IF @Id_Partizione_Scarico = 3203
				THROW 50006, ' L''UDC VA OBBLIGATIORIAMENTE SCARICATA DAL MAGAZZINO SE SI TROVA IN 3B03',1

			DECLARE @ID_MISSIONE				INT
			DECLARE @Id_Partizione_Destinazione INT
			
			--Incremento  di uno la Partizione
			SELECT	@Id_Partizione_Destinazione = Id_Partizione + 1
			FROM	Udc_Posizione
			WHERE	Id_Udc = @Id_Udc

			EXEC @Return = dbo.sp_Insert_CreaMissioni
						@Id_Udc						= @Id_Udc,
						@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
						@Id_Tipo_Missione			= 'OUL',
						@Id_Missione				= @ID_MISSIONE		OUTPUT,
						@Id_Processo				= @Id_Processo,
						@Origine_Log				= @Origine_Log,
						@Id_Utente					= @Id_Utente,
						@Errore						= @Errore			OUTPUT

			IF ISNULL(@Errore, '') <> ''
				RAISERROR(@Errore, 12, 1)
		END

		--Elimino l'evento
		DELETE	Eventi
		WHERE	Id_Evento = @Id_Evento

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
