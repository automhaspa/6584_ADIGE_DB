SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_WBS_Avvia_UscitaLista]
	@Id_Cambio_WBS					INT,
	@Id_Partizione_Destinazione		INT,
	-- Parametri Standard;
	@Id_Processo					VARCHAR(30),
	@Origine_Log					VARCHAR(25),
	@Id_Utente						VARCHAR(32),
	@Errore							VARCHAR(500) OUTPUT
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
		-- Dichiarazioni Variabili;
		DECLARE @Id_Articolo		NUMERIC(18,0)
		DECLARE @WBS_Sorgente		VARCHAR(24)
		DECLARE @WBS_Destinazione	VARCHAR(24)
		DECLARE @QTA_da_Spostare	NUMERIC(10,2)
		DECLARE @Id_Stato_Lista		INT

		DECLARE @Id_UdcDettaglio_C				INT
		DECLARE @Id_Udc_C						INT
		DECLARE @Qta_Disponibile_UDC_C			NUMERIC(10,2)		= 0
		DECLARE @Id_Tipo_Udc_C					VARCHAR(1)

		IF @Id_Partizione_Destinazione IS NULL
			THROW 50009, 'Partizione di destinazione lista non selezionata', 1

		SELECT	@Id_Stato_Lista = Id_Stato_Lista,
				@Id_Articolo = Id_Articolo,
				@WBS_Sorgente = WBS_Partenza,
				@WBS_Destinazione = WBS_Destinazione,
				@QTA_da_Spostare = Qta_Pezzi
		FROM	Custom.CambioCommessaWBS
		WHERE	ID = @Id_Cambio_WBS
		
		IF @Id_Stato_Lista = 5
			THROW 50009, 'Impossibile evadere una lista già in esecuzione', 1

		IF @Id_Stato_Lista = 6
			THROW 50009, 'Impossibile evadere una lista già conclusa', 1

		--SE HANNO SOSPESO/CHIUSO SENZA MAI AVVIARE E ADESSO STANNO AVVIANDO RIMETTO IN STATO 1
		IF @Id_Stato_Lista = 3
			AND
			NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	Custom.Missioni_Cambio_WBS
							WHERE	Id_Cambio_WBS = @Id_Cambio_WBS
						)
			SET @Id_Stato_Lista = 1

		IF @Id_Stato_Lista = 1 --SE MI ARRIVA DA UNO STATO PRELEVABILE PREDISPONGO LA LISTA DI PRELIEVO
		BEGIN
			IF @Id_Articolo IS NULL
				THROW 50008, 'ID ARTICOLO NON PRESENTE. IMPOSSIBILE PROCEDERE',1

			SET @Id_UdcDettaglio_C				= NULL
			SET @Id_Udc_C						= NULL
			SET @Qta_Disponibile_UDC_C			= NULL
			SET @Id_Tipo_Udc_C					= NULL

			DECLARE @Quantita_Distribuita			NUMERIC(10,2)		= 0
			
			DECLARE @Quantita_Impegnate_Liste TABLE	(
														Id_Udc			INT,
														Id_Articolo		INT,
														Qta_Impegnata	NUMERIC(10,2)
													)
			INSERT INTO @Quantita_Impegnate_Liste
				SELECT	Id_Udc,
						Id_Articolo,
						SUM(Quantita)	Qta_Impegnata
				FROM	Missioni_Picking_Dettaglio
				WHERE	Id_Stato_Missione IN (1,2)
				GROUP
					BY	Id_Udc,
						Id_Articolo
				UNION
				SELECT	Id_Udc,
						Id_Articolo,
						SUM(Quantita)	Qta_Impegnata
				FROM	Custom.Missioni_Cambio_WBS
				WHERE	Id_Stato_Lista IN (1,5,3)
				GROUP
					BY	Id_Udc,
						Id_Articolo

			DECLARE @Qta_Dettaglio_NonUtilizzabili	TABLE	(
																Id_UdcDettaglio		INT,
																Qta_Indisponibile	NUMERIC(10,2)
															)
			INSERT INTO @Qta_Dettaglio_NonUtilizzabili
				SELECT	Id_UdcDettaglio,
						SUM(Quantita)
				FROM	Custom.ControlloQualita
				GROUP
					BY	Id_UdcDettaglio
				UNION
				SELECT	Id_UdcDettaglio,
						SUM(Quantita)	Qta_Impegnata
				FROM	Custom.NonConformita
				GROUP
					BY	Id_UdcDettaglio

			--DECLARE @Trasli_Abilitati	TABLE	(
			--										Id_Sottoarea	INT,
			--										Abilitato		BIT
			--									)
			--	INSERT INTO @Trasli_Abilitati
			--		SELECT		C.ID_SOTTOAREA,
			--					CASE
			--						WHEN P.LOCKED = 1 THEN 0
			--						ELSE 1
			--					END
			--		FROM		dbo.Partizioni P INNER JOIN dbo.SottoComponenti SC ON SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
			--		INNER JOIN	dbo.Componenti C ON C.ID_COMPONENTE = SC.ID_COMPONENTE
			--		WHERE		P.ID_PARTIZIONE IN (1110,1210)


			--Scorro le Udc contenenti quel codice articolo e la WBS di partenza
			DECLARE CursoreUdc CURSOR LOCAL STATIC FOR
				SELECT	UD.Id_UdcDettaglio,
						UD.Id_Udc,
						UD.Quantita_Pezzi - ISNULL(QI.Qta_Impegnata,0) - ISNULL(QD.Qta_Indisponibile, 0)		QuantitaUdc,
						UT.Id_Tipo_Udc
				FROM	Udc_Dettaglio						UD
				JOIN	Udc_Testata							UT
				ON		UT.Id_Udc = UD.Id_Udc
					AND UD.Id_Articolo = @Id_Articolo								--VALUTO LE SOLE UDC CON IL MIO ARTICOLO
					AND ISNULL(UD.WBS_Riferimento,'') = ISNULL(@WBS_Sorgente,'')	--VALUTO LE SOLE UDC CON LA MIA STESSA WBS SORGENTE
					AND UD.Id_Udc <> 702											--ESCLUDO MODULA
					AND ISNULL(UT.Blocco_Udc,0) = 0									--ESCLUDO LE UDC BLOCCATE
				JOIN	Udc_Posizione						UP
				ON		UP.Id_Udc = UD.Id_Udc
				JOIN	Partizioni							P
				ON		P.Id_Partizione = UP.Id_Partizione
					AND P.ID_TIPO_PARTIZIONE NOT IN ('AT', 'KT', 'AP', 'US', 'OO')	--ESCLUDO LE UDC IN AREE TERRA/KITTING/PICKING
				--JOIN	dbo.SottoComponenti			SC
				--ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
				--JOIN	dbo.Componenti					C
				--ON		C.ID_COMPONENTE = SC.ID_COMPONENTE
				--JOIN	@Trasli_Abilitati			TA
				--ON		C.ID_SOTTOAREA = TA.Id_Sottoarea
				LEFT
				JOIN	@Quantita_Impegnate_Liste			QI
				ON		QI.Id_Udc = UD.Id_Udc
					AND QI.Id_Articolo = UD.Id_Articolo
				LEFT
				JOIN	@Qta_Dettaglio_NonUtilizzabili		QD
				ON		QD.Id_UdcDettaglio = UD.Id_UdcDettaglio
				LEFT
				JOIN	Custom.OrdineKittingUdc				OKU
				ON		OKU.Id_Udc = UT.Id_Udc
				WHERE	QI.Id_Udc IS NULL
					AND	ISNULL(OKU.Stato_Udc_Kit, 0) = 0
					AND UD.Quantita_Pezzi - ISNULL(QD.Qta_Indisponibile, 0) > 0
				GROUP
					BY	UD.Id_UdcDettaglio,
						UD.Id_Udc,
						UD.Quantita_Pezzi,
						UT.Id_Tipo_Udc,
						UD.Data_Creazione,
						ISNULL(QI.Qta_Impegnata,0),
						ISNULL(QD.Qta_Indisponibile, 0)--,
						--TA.Abilitato
				ORDER
						BY	--TA.Abilitato				DESC, --PRIMA PRENDO GLI ARTICOLI DALLE UDC CHE SI TROVANO NELLA PARTE ABILITATA (P.A.S - 2022/11/14)
						ISNULL(QD.Qta_Indisponibile, 0)	ASC,--PRIMA CERCO DI ESTRARRE PIU' UDC CORRETTE
						UD.Data_Creazione				ASC,
						UD.Quantita_Pezzi				ASC

			OPEN CursoreUdc
			FETCH NEXT FROM CursoreUdc  INTO
					@Id_UdcDettaglio_C,
					@Id_Udc_C,
					@Qta_Disponibile_UDC_C,
					@Id_Tipo_Udc_C

			WHILE @@FETCH_STATUS = 0
			BEGIN
				--Se per quell'Udc ho più Articoli della dettaglio di quanti me ne servono non la svuoto completamente
				IF @Qta_Disponibile_UDC_C > @QTA_da_Spostare - @Quantita_Distribuita
				BEGIN
					INSERT INTO Custom.Missioni_Cambio_WBS
						(Id_Udc, Id_UdcDettaglio, Id_Cambio_WBS, Id_Articolo, Quantita, Id_Stato_Lista,Id_Partizione_Destinazione, DataOra_Creazione, DataOra_UltimaModifica)
					VALUES
						(@Id_Udc_C,@Id_UdcDettaglio_C,@Id_Cambio_WBS, @Id_Articolo, @QTA_da_Spostare - @Quantita_Distribuita, 1, @Id_Partizione_Destinazione, GETDATE(), GETDATE())

					SET @Quantita_Distribuita += @QTA_da_Spostare - @Quantita_Distribuita
				END
				--Se l'udc non basta per soddisfare la quantità richiesta
				ELSE
				BEGIN
					SET @Quantita_Distribuita += @Qta_Disponibile_UDC_C

					INSERT INTO Custom.Missioni_Cambio_WBS
						(Id_Udc, Id_UdcDettaglio, Id_Cambio_WBS, Id_Articolo, Quantita, Id_Stato_Lista,Id_Partizione_Destinazione, DataOra_Creazione, DataOra_UltimaModifica)
					VALUES
						(@Id_Udc_C,@Id_UdcDettaglio_C,@Id_Cambio_WBS, @Id_Articolo,@Qta_Disponibile_UDC_C, 1, @Id_Partizione_Destinazione, GETDATE(), GETDATE())
				END

				--Se ho distribuito completamente
				IF @Quantita_Distribuita >= @QTA_da_Spostare
					BREAK;

				FETCH NEXT FROM CursoreUdc  INTO
					@Id_UdcDettaglio_C,
					@Id_Udc_C,
					@Qta_Disponibile_UDC_C,
					@Id_Tipo_Udc_C
			END

			CLOSE CursoreUdc
			DEALLOCATE CursoreUdc

			IF @QTA_da_Spostare - @Quantita_Distribuita > 0
				THROW 50009,'Quantita a magazzino non sufficiente', 1
			
			--Se tutto è andato a buon fine aggiorno lo stato testata lista in esecuzione
			UPDATE	Custom.CambioCommessaWBS
			SET		Id_Stato_Lista = 5,
					DataOra_Avvio = GETDATE()
			WHERE	ID = @Id_Cambio_WBS

			DECLARE @XmlParam			XML = CONCAT('<Parametri><Id_Cambio_WBS>', @Id_Cambio_WBS,'</Id_Cambio_WBS><Nome_Magazzino>INGOMBRANTI</Nome_Magazzino></Parametri>')

			--CONTROLLO  SE CI SONO COINVOLTE UDC INGOMBRANTI PER LANCIARE L'EVENTO DI PRELIEVO CUSTOM SULLA BAIA 
			IF EXISTS	(
							SELECT	TOP 1 1
							FROM	Custom.Missioni_Cambio_WBS		MWBS
							JOIN	Udc_Testata						UT
							ON		UT.Id_Udc = MWBS.Id_Udc
								AND MWBS.Id_Cambio_WBS = @Id_Cambio_WBS
								AND UT.Id_Tipo_Udc = 'I'
						)
			BEGIN
				--SE SONO INGOMBRANTI VANNO GIA' IN STATO 5 E GENERO L'EVENTO DI CAMBIO WBS
				UPDATE	MWBS
				SET		Id_Stato_Lista = 5
				FROM	Custom.Missioni_Cambio_WBS	MWBS
				JOIN	Udc_Testata					UT
				ON		UT.Id_Udc = MWBS.Id_Udc
				WHERE	MWBS.Id_Cambio_WBS = @Id_Cambio_WBS
					AND UT.Id_Tipo_Udc = 'I'

				;THROW 50009, 'MANCA EVENTO', 1

				EXEC @Return = sp_Insert_Eventi
							@Id_Tipo_Evento		= 6,
							@Id_Partizione		= 7684,
							@Id_Tipo_Messaggio	= 1100,
							@XmlMessage			= @XmlParam,
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Id_Utente			= @Id_Utente,
							@Errore				= @Errore OUTPUT

				IF @Return <> 0
					RAISERROR(@Errore,12,1)

				--NELL'EVENTO MOSTRO IL MESSAGGIO CUSTOM
				SET @Errore += 'LISTA AVVIATA CORRETTAMENTE, ATTENZIONE!! LA LISTA PREVEDE PRELIEVO DI MATERIALI INGOMBRANTI'
			END

			--CONTROLLO  SE CI SONO COINVOLTE UDC INGOMBRANTI PER LANCIARE L'EVENTO DI PRELIEVO CUSTOM SULLA BAIA 
			IF EXISTS	(
							SELECT	TOP 1 1
							FROM	Custom.Missioni_Cambio_WBS		MWBS
							JOIN	Udc_Testata						UT
							ON		UT.Id_Udc = MWBS.Id_Udc
								AND MWBS.Id_Cambio_WBS = @Id_Cambio_WBS
								AND UT.Id_Tipo_Udc = 'M'
						)
			BEGIN
				--SE SONO INGOMBRANTI VANNO GIA' IN STATO 5 E GENERO L'EVENTO DI CAMBIO WBS
				UPDATE	MWBS
				SET		Id_Stato_Lista = 5
				FROM	Custom.Missioni_Cambio_WBS	MWBS
				JOIN	Udc_Testata					UT
				ON		UT.Id_Udc = MWBS.Id_Udc
				WHERE	MWBS.Id_Cambio_WBS = @Id_Cambio_WBS
					AND UT.Id_Tipo_Udc = 'M'

				;THROW 50009, 'MANCA EVENTO', 1

				EXEC @Return = sp_Insert_Eventi
							@Id_Tipo_Evento		= 6,
							@Id_Partizione		= 7685,
							@Id_Tipo_Messaggio	= 1100,
							@XmlMessage			= @XmlParam,
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Id_Utente			= @Id_Utente,
							@Errore				= @Errore OUTPUT

				IF @Return <> 0
					RAISERROR(@Errore,12,1)

				--NELL'EVENTO MOSTRO IL MESSAGGIO CUSTOM
				SET @Errore += 'LISTA AVVIATA CORRETTAMENTE, ATTENZIONE!! LA LISTA PREVEDE PRELIEVO DI MATERIALI INGOMBRANTI'
			END

		END
		--SE PROVENGO DA UNA LISTA SOSPESA LA RIMETTO IN STATO RUNNING
		ELSE IF @Id_Stato_Lista = 3
		BEGIN
			SET @Id_Udc_C = NULL

			UPDATE	Custom.CambioCommessaWBS
			SET		Id_Stato_Lista = 5,
					DataOra_Avvio = GETDATE(),
					DataOra_UltimaModifica = GETDATE(),
					Descrizione = CONCAT('Riavvio il ', GETDATE(), ' - ', @Id_Utente)
			WHERE	ID = @Id_Cambio_WBS

			DECLARE Cursore_Missioni_WBS CURSOR LOCAL STATIC FOR
				SELECT	ID_UDC
				FROM	Custom.Missioni_Cambio_WBS
				WHERE	Id_Cambio_WBS = @Id_Cambio_WBS
					AND Id_Stato_Lista = 3 --SOSPESA

			OPEN Cursore_Missioni_WBS
			FETCH NEXT FROM Cursore_Missioni_WBS INTO
				@Id_Udc_C

			WHILE @@FETCH_STATUS = 0
			BEGIN
				--AGGIORNO LAPARTIZIONE DI DESTINAZIONE
				UPDATE	Custom.Missioni_Cambio_WBS
				SET		Id_Partizione_Destinazione	= @Id_Partizione_Destinazione,
						Id_Stato_Lista				= 1,
						DataOra_UltimaModifica		= GETDATE(),
						Descrizione					= CONCAT('Riavvio il ', GETDATE(), ' - ', @Id_Utente)
				WHERE	Id_Cambio_WBS = @Id_Cambio_WBS
					AND Id_Udc = @Id_Udc_C

				FETCH NEXT FROM Cursore_Missioni_WBS INTO
					@Id_Udc_C
			END

			CLOSE Cursore_Missioni_WBS
			DEALLOCATE Cursore_Missioni_WBS
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
