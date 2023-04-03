SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE PROCEDURE [dbo].[sp_WBS_CambioProgetto_UdcDettaglio]
	@Id_Evento				INT = NULL,
	@Id_UdcDettaglio		INT,
	@Id_Cambio_WBS			INT,
	@Qta_DaSpostare			NUMERIC(10,2),
	@Id_Udc					INT,
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

	-- Dichiarazioni variabili stand	ard;
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
		IF @Id_Evento IS NULL
			THROW 50009, 'IMPOSSIBILE AVVIARE IL CAMBIO WBS SENZA UN''EVENTO COLLEGATO. AVVIARE IL CAMBIO E ESTRARRE L''UDC IN BAIA',1

		DECLARE @WBS_Destinazione	VARCHAR(24)
		DECLARE @Qta_InUdc			NUMERIC(10,2)
		DECLARE @Qta_UDC_Cambio		NUMERIC(10,2)
		DECLARE @Qta_Tot_Cambio		NUMERIC(10,2)
		DECLARE @Id_Articolo		NUMERIC(18,0)
		DECLARE @Id_Ddt_Reale		INT
		DECLARE @Id_Riga_Ddt		INT
		DECLARE @Control_Lot		VARCHAR(40)
		DECLARE @Id_Causale_L3		VARCHAR(4)
		DECLARE @Data_Creazione		DATETIME
		DECLARE @Quantita_Rimanente NUMERIC(10,2)
		DECLARE @WBS_Sorgente		VARCHAR(24)

		SELECT	@WBS_Destinazione	= CWBS.WBS_Destinazione,
				@Qta_InUdc			= UD.Quantita_Pezzi,
				@Qta_Tot_Cambio		= CWBS.Qta_Pezzi,
				@Qta_UDC_Cambio		= MWBS.Quantita,
				@Id_Articolo		= UD.Id_Articolo,
				@Id_Ddt_Reale		= UD.Id_Ddt_Reale,
				@Id_Riga_Ddt		= UD.Id_Riga_Ddt,
				@Control_Lot		= UD.Control_Lot,
				@Id_Causale_L3		= CWBS.Load_Order_Type,
				@Data_Creazione		= UD.Data_Creazione,
				@Quantita_Rimanente = Quantita_Pezzi - @Qta_DaSpostare,
				@WBS_Sorgente		= WBS_Riferimento
		FROM	Custom.CambioCommessaWBS	CWBS
		JOIN	Custom.Missioni_Cambio_WBS	MWBS
		ON		MWBS.Id_Cambio_WBS = CWBS.ID
			AND MWBS.Id_Cambio_WBS = @ID_Cambio_WBS
			AND MWBS.Id_UdcDettaglio = @Id_UdcDettaglio
		JOIN	Udc_Dettaglio				UD
		ON		UD.Id_UdcDettaglio = MWBS.Id_UdcDettaglio

		IF @Qta_DaSpostare > @Qta_InUdc
			THROW 50009, 'IMPOSSIBILE SPOSTARE PIU'' MATERIALE DI QUELLO PRESENTE SULL''UDC',1

		IF @Qta_DaSpostare > @Qta_UDC_Cambio
			THROW 50009, 'IMPOSSIBILE SPOSTARE PIU'' MATERIALE DI QUELLO PREVISTO PER L''UDC',1

		DECLARE @Id_UdcDettaglio_Destinazione INT

		SELECT	@Id_UdcDettaglio_Destinazione = Id_UdcDettaglio
		FROM	Udc_Dettaglio
		WHERE	ID_UDC = @Id_Udc
			AND Id_UdcDettaglio <> @Id_UdcDettaglio
			AND ISNULL(WBS_Riferimento,'') = ISNULL(@WBS_Destinazione,'')
			AND Id_Articolo = @Id_Articolo

		--AGGIORNO UDC DETTAGLIO
			--SE ESISTE GIA' UN DETTAGLIO DIVERSO DA ME CON LA STESSA WBS DI DESTINAZIONE E LO STESSO ARTICOLO ALLORA AGGIUNGO LA QUANTITA CHE STO SPOSTANDO SU QUELLA, MA NON CAMBIO LA MIA WBS
		IF @Id_UdcDettaglio_Destinazione IS NOT NULL
		BEGIN
			UPDATE	Udc_Dettaglio
			SET		Quantita_Pezzi -= @Qta_DaSpostare
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio

			EXEC sp_WBS_Gestisci_Dettagli
					@Id_UdcDettaglio_Sorgente		= @Id_UdcDettaglio,
					@Id_UdcDettaglio_Destinazione	= @Id_UdcDettaglio_Destinazione,
					@Qta_DaAggiungere				= @Qta_DaSpostare,
					@Id_Processo					= @Id_Processo,
					@Origine_Log					= @Origine_Log,
					@Id_Utente						= @Id_Utente,
					@Errore							= @Errore						OUTPUT

			--VERIFICO CHE L'UDC NON SIA VUOTA, ALTRIMENTI LA CANCELLO
			IF EXISTS	(
							SELECT	TOP 1 1
							FROM	Udc_Dettaglio
							WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
								AND Quantita_Pezzi = 0
						)
				EXEC sp_Update_Aggiorna_Contenuto_Udc
						@Id_Udc					= @Id_Udc,
						@Id_UdcDettaglio		= @Id_UdcDettaglio,
						@Id_Causale_Movimento	= 6,
						@Id_Processo			= @Id_Processo,
						@Origine_Log			= @Origine_Log,
						@Id_Utente				= @Id_Utente,
						@Errore					= @Errore				OUTPUT
		END
		ELSE
		BEGIN
			--SE NON ESISTE E LA QUANTITA' CHE STO SPOSTANDO E' UGUALE ALLA QUANTITA CHE HO IO ALLORA CAMBIO LA WBS E BASTA
			IF @Qta_DaSpostare = @Qta_InUdc
				UPDATE	Udc_Dettaglio
				SET		WBS_Riferimento = @WBS_Destinazione
				WHERE	Id_UdcDettaglio = @Id_UdcDettaglio

			--SE NON ESISTE E STO SPOSTANDO DI MENO ALLORA DEVO FARE UNO SWITCH AVENDO CURA DI MANTENTERE LA STESSA DATA CREAZIONE
			ELSE
			BEGIN
				--DIMINUISCO LA QUANTITA' SULL'UDC E CREO UNA NUOVA
				UPDATE	Udc_Dettaglio
				SET		Quantita_Pezzi -= @Qta_DaSpostare
				WHERE	Id_UdcDettaglio = @Id_UdcDettaglio

				--DEVO RICREARLO ESATTAMENTE UGUALE.
				EXEC [dbo].[sp_Update_Aggiorna_Contenuto_Udc]
						@Id_Udc					= @Id_Udc,
						@Id_Articolo			= @Id_Articolo,
						@Qta_Pezzi_Input		= @Qta_DaSpostare,
						@Id_Causale_Movimento	= 3,
						@Flag_FlVoid			= 0,
						@Id_Causale				= @Id_Causale_L3,
						@Id_Ddt_Reale			= @Id_Ddt_Reale,
						@Id_Riga_Ddt			= @Id_Riga_Ddt,
						@WBS_CODE				= @WBS_Destinazione,
						@CONTROL_LOT			= @Control_Lot,
						@Data_Creazione			= @Data_Creazione,
						@Id_Processo			= @Id_Processo,
						@Origine_Log			= @Origine_Log,
						@Id_Utente				= @Id_Utente,
						@Errore					= @Errore				OUTPUT
			END
		END
		
		--AGGIORNO LA TABELLA DELLE MISSIONI DI CAMBIO WBS
		UPDATE	Custom.Missioni_Cambio_WBS
		SET		Qta_Spostata = ISNULL(Qta_Spostata,0) + @Qta_DaSpostare,
				DataOra_UltimaModifica = GETDATE()
		WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
			AND Id_Cambio_WBS = @ID_Cambio_WBS

		--SE HO SPOSTATO TUTTO CHIUDO LA RIGA.
		IF EXISTS	(
						SELECT	TOP 1 1
						FROM	Custom.Missioni_Cambio_WBS
						WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
							AND Id_Cambio_WBS = @ID_Cambio_WBS
							AND Qta_Spostata = Quantita
					)
			UPDATE	Custom.Missioni_Cambio_WBS
			SET		Id_Stato_Lista = 6,
					DataOra_Termine = GETDATE(),
					DataOra_UltimaModifica = GETDATE()
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
				AND Id_Cambio_WBS = @ID_Cambio_WBS
		
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
