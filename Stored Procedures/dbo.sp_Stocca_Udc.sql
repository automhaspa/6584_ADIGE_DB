SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Stocca_Udc]
	@Id_Udc						INT,
	@Id_Evento					INT,
	@Id_Testata_Lista			INT = 0,
	@Specializzazione_Completa	BIT	= 0,
	-- Parametri Standard;
	@Id_Processo				VARCHAR(30),
	@Origine_Log				VARCHAR(25),
	@Id_Utente					VARCHAR(32),
	@Errore						VARCHAR(500) OUTPUT
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

	-- Se il numero di transazioni è 0 significa ke devo apirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		-- Dichiarazioni Variabili;
		DECLARE @Id_Partizione_Destinazione		INT			= 2110
		DECLARE @Id_Tipo_Missione				VARCHAR(3)	= 'ING'
		DECLARE @IdTipoEvento					INT
		DECLARE @IdPartizioneUdc				INT
		DECLARE @Id_Partizione_Evento			INT
		DECLARE @MESSAGGIO						VARCHAR(MAX)

		IF @Id_Udc = 702
			THROW 50001, 'OPERAZIONE NON ESEGUIBILE SU MODULA DA AWM', 1

		SELECT	@IdPartizioneUdc = Id_Partizione
		FROM	Udc_Posizione
		WHERE	Id_Udc = @Id_Udc

		SELECT	@IdTipoEvento = Id_Tipo_Evento,
				@Id_Partizione_Evento = Id_Partizione
		FROM	Eventi
		WHERE	Id_Evento = @Id_Evento
		
		--Se mi fa lo stocca_Udc dalle baie di outbound o area a terra lancio un eccezione
		--SE SI DIMENTICANO DI CHIUDERE L'EVENTO IN SPECIALIZZAZIONE A TERRA NON LANCIO ECCEZIONE
		IF ISNULL(@Id_Partizione_Evento,3404) NOT IN (3501,3301,3302,3404,3403,3604,3603,3701,9103)
			THROW 50009, 'E'' POSSIBILE RISTOCCARE LE UDC ESCLUSIVAMENTE DA BAIE DI PICKING E DI SPECIALIZZAZIONE', 1

		--Posso fare Lo stocca Udc da Un prelievo Completo o Parziale oppure in Automatico
		IF @IdTipoEvento = 4
		BEGIN
			DECLARE @IdRigaLista		INT
			DECLARE @IdArticolo			INT
			DECLARE @Quantita			NUMERIC(10,2)
			DECLARE @Qta_Prelevata		NUMERIC(10,2)
			DECLARE @IdStatoMissione	INT
			DECLARE @FlVoid				NUMERIC(1,0)

			DECLARE CursoreRighePrelievoUdc CURSOR LOCAL FAST_FORWARD FOR
				SELECT	Id_Articolo,
						Id_Riga_Lista,
						Quantita,
						Qta_Prelevata,
						Id_Stato_Missione
				FROM	Missioni_Picking_Dettaglio
				WHERE	Id_Testata_Lista = @Id_Testata_Lista
					AND Id_Udc = @Id_Udc
					AND Id_Stato_Missione IN (2,3)

			OPEN CursoreRighePrelievoUdc
			FETCH NEXT FROM CursoreRighePrelievoUdc INTO
				@IdArticolo,
				@IdRigaLista,
				@Quantita,
				@Qta_Prelevata,
				@IdStatoMissione

			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @FlVoid = 0

				IF @Qta_Prelevata < @Quantita
				BEGIN
					SET @FlVoid = 1

					--COME DA ACCORDI 18/05 SE IL PRELIEVO PARZIALE DI UN ARTICOLO E COMPRESO IN ALTRE UDC DA CUI NON HO ANCORA PRELEVATO
					--FORZO LA CHIUSURA RIGHE COSì ARRIVA UN SOLO FL_VOID, ATTENZIONE SE LE UDC SUCCESSIVE SONO DI UNA MISSIONE USCITA COMPLETA
					UPDATE	Missioni_Picking_Dettaglio
					SET		Id_Stato_Missione = 4,
							DataOra_Evasione = GETDATE()
					WHERE	Id_Articolo = @IdArticolo
						AND Id_Testata_Lista = @Id_Testata_Lista
						AND Id_Stato_Missione IN (1,2)
						AND Id_Udc NOT IN (@Id_Udc, 702)
				END

				--GENERO CONSUNTIVO VERSO L3 PER GLI ANNULLAMENTI RIGA DALLO STOCCA UDC
				EXEC [dbo].[sp_Genera_Consuntivo_PrelievoLista]
							@Id_Udc				= @Id_Udc,
							@Id_Testata_Lista	= @Id_Testata_Lista,
							@Id_Riga_Lista		= @IdRigaLista,
							@Qta_Prelevata		= 0,
							@Fl_Void			= @FlVoid,
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Id_Utente			= @Id_Utente,
							@Errore				= @Errore OUTPUT

				IF (ISNULL(@Errore, '') <> '')
					THROW 50100, @Errore, 1

				FETCH NEXT FROM CursoreRighePrelievoUdc INTO
					@IdArticolo,
					@IdRigaLista,
					@Quantita,
					@Qta_Prelevata,
					@IdStatoMissione
			END

			CLOSE CursoreRighePrelievoUdc
			DEALLOCATE CursoreRighePrelievoUdc

			--Controllo fine Lista
			EXEC [dbo].[sp_Update_Stati_ListePrelievo]
					@Id_Testata_Lista	= @Id_Testata_Lista,
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Id_Utente			= @Id_Utente,
					@Errore				= @Errore			OUTPUT

			UPDATE	Missioni_Picking_Dettaglio
			SET		Id_Stato_Missione = 4,
					DataOra_Evasione = GETDATE()
			WHERE	Id_Udc = @Id_Udc
				AND Id_Testata_Lista = @Id_Testata_Lista
				AND Id_Stato_Missione IN (2, 3)
		END
		--SE SONO UN RIENTRO DA SPECIALIZZAZIONE
		ELSE IF @IdTipoEvento = 33
		--SE STO PER COMPLETARE LA SPECIALIZZAZIONE DELL'UDC
		BEGIN
			IF @Specializzazione_Completa = 1
			BEGIN
				DECLARE @Id_Ddt_Fittizio_Corrente INT = 0

				SELECT	@Id_Ddt_Fittizio_Corrente = Id_Ddt_Fittizio
				FROM	Udc_Testata
				WHERE	Id_Udc = @Id_Udc

				--MA SONO L'UTLIMA UDC DELL ORDINE DA SPECIALIZZARE MA NON SONO IN AREA A TERRA
				IF	EXISTS	(
								SELECT	TOP 1 1
								FROM	(
											SELECT	COUNT(1)		Count_Mancanti
											FROM	Udc_Testata
											WHERE	ISNULL(Specializzazione_Completa, 0) = 0
												AND ISNULL(Id_Ddt_Fittizio, 0) = @Id_Ddt_Fittizio_Corrente
												AND EXISTS (SELECT TOP 1 1 FROM Udc_Posizione WHERE Id_Partizione IN (3301, 3302,3501) AND Id_Udc = @Id_Udc)
										)	UdcManc
								WHERE UdcManc.count_mancanti = 1
							)
				BEGIN
					--CONTROLLO CHE NON RIMANGANO ARTICOLI DA SPECIALIZZARE NEI DDT REALI
					IF	EXISTS	(
									SELECT	TOP 1 1
									FROM	AwmConfig.VQtaRimanentiRigheDdt
									WHERE	QUANTITA_RIMANENTE_DA_SPECIALIZZARE > 0
										AND Id_Ddt_Fittizio = @Id_Ddt_Fittizio_Corrente
								)
						THROW 50003,' ATTENZIONE STAI CHIUDENDO L''ORDINE DI SPECIALIZZAZIONE CON QUEST'' ULTIMA UDC MA RIMANGONO DEGLI ARTICOLI DA SPECIALIZZARE
										NEI DDT REALI ASSOCIATI (NEL CASO NON SIANO PRESENTI GLI ARTICOLI FORZARE CHIUSURA RIGA)',1
				END

				IF EXISTS(SELECT TOP 1 1 FROM Udc_Posizione UP JOIN Partizioni P ON UP.Id_Partizione = P.ID_PARTIZIONE WHERE P.ID_TIPO_PARTIZIONE = 'AT' AND UP.Id_Udc = @Id_Udc)
				BEGIN
					IF NOT EXISTS(SELECT TOP 1 1 FROM Udc_Dettaglio WHERE Id_Udc = @Id_Udc)
					BEGIN
						EXEC sp_Delete_EliminaUdc
								@ID_UDC				= @ID_UDC,
								@ID_PROCESSO		= @ID_PROCESSO,
								@ORIGINE_LOG		= @ORIGINE_LOG,
								@Id_Utente			= @Id_Utente,
								@Errore				= @Errore			OUTPUT	
				
						SET @MESSAGGIO = 'UDC IN AREA TERRA ELIMINATA PERCHE'' VUOTA'
					END
				END
			END

			UPDATE	Udc_Testata
			SET		Specializzazione_Completa = @Specializzazione_Completa
			WHERE	Id_Udc = @Id_Udc
		END

		DELETE	Eventi
		WHERE	Id_Evento = @Id_Evento

		--SE L'UDC NON  E' COINVOLTA IN UN' ALTRA MISSIONE VERSO LA BAIA DI PICKING OPPOSTA 	
		IF	@IdPartizioneUdc IN (3501,3301,3302,3404,3403,3604,3603,3701)
				AND
			NOT EXISTS(SELECT TOP 1 1 FROM Missioni WHERE Id_Udc = @Id_Udc AND Id_Stato_Missione = 'ELA')
		BEGIN
			--SE L'UDC E VUOTA LA MANDO IN 3B03 SOLO SE PROVIENE DA PICKING
			IF	ISNULL(@IdTipoEvento,0) <> 33
					AND
				NOT EXISTS(SELECT TOP 1 1 FROM Udc_Dettaglio WHERE Id_Udc = @Id_Udc)
			BEGIN
				SET @Id_Partizione_Destinazione = 3203
				SET @Id_Tipo_Missione = 'OUT'
			END

			EXEC @Return = dbo.sp_Insert_CreaMissioni
					@Id_Udc						= @Id_Udc,
					@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
					@XML_PARAM					= '',
					@Id_Tipo_Missione			= @Id_Tipo_Missione,
					@Id_Processo				= @Id_Processo,
					@Origine_Log				= @Origine_Log,
					@Id_Utente					= @Id_Utente,
					@Errore						= @Errore			OUTPUT
		END

		IF ISNULL(@MESSAGGIO,'') <> ''
			SET @Errore = @MESSAGGIO

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
