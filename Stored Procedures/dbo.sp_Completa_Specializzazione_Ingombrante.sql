SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[sp_Completa_Specializzazione_Ingombrante]
	@Id_Ddt_Fittizio	INT,
	@Id_Udc				INT,
	@Id_Evento			INT,
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
	SET @Nome_StoredProcedure	= Object_Name(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount				= @@TRANCOUNT;

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		DECLARE	@CountRimanentiDaSpec	INT
		DECLARE	@Partizione				INT
		DECLARE	@CountDettaglio			INT

		SELECT	@Partizione = Id_Partizione
		FROM	Udc_Posizione
		WHERE	Id_Udc = @Id_Udc

		IF @Partizione IN (7684,7685)
			THROW 50009, 'SELEZIONARE POSIZIONE STOCCAGGIO PRIMA DI CHIUDERE LA SPECIALIZZAZIONE',1

		SELECT	@CountDettaglio = COUNT(Id_UdcDettaglio)
		FROM	Udc_Dettaglio
		WHERE	Id_Udc = @Id_Udc

		IF @CountDettaglio = 0
			SET @Errore = 'ATTENZIONE!!! HAI COMPLETATO LA SPECIALIZZAZIONE DI UN UDC INGOMBRANTE SENZA SPECIALIZZARE NESSUN CODICE ARTICOLO SU DI ESSA'

		--SE STO PER COMPLETARE LA SPECIALIZZAZIONE DELL' UDC
		--MA SONO L'UTLIMA UDC DELL ORDINE DA SPECIALIZZARE 
		IF EXISTS	(
						SELECT	TOP 1 1
						FROM	(
									SELECT	Count(1)	Count_Mancanti
									FROM	udc_testata
									WHERE	Isnull(specializzazione_completa, 0) = 0
										AND Isnull(id_ddt_fittizio, 0) =	(
																				SELECT	id_ddt_fittizio
																				FROM	udc_testata
																				WHERE	id_udc = @Id_Udc
																			)
								) UdcManc
						WHERE	UdcManc.count_mancanti = 1
					)
		BEGIN
			--CONTROLLO CHE NON RIMANGANO ARTICOLI DA SPECIALIZZARE NEI DDT REALI
			IF EXISTS	(
							SELECT	TOP 1 1
							FROM	AwmConfig.VQtaRimanentiRigheDdt
							WHERE	QUANTITA_RIMANENTE_DA_SPECIALIZZARE > 0
								AND Id_Ddt_Fittizio =	(
															SELECT	id_ddt_fittizio
															FROM	udc_testata
															WHERE	id_udc = @Id_Udc
														)
						)
				THROW 50003,' ATTENZIONE STAI CHIUDENDO L''ORDINE DI SPECIALIZZAZIONE CON QUEST'' ULTIMA UDC
							MA RIMANGONO DEGLI ARTICOLI DA SPECIALIZZARE NEI DDT REALI ASSOCIATI
							(NEL CASO NON SIANO PRESENTI FORZARE CHIUSURA RIGA)',1
		END

		UPDATE	Udc_Testata
		SET		Specializzazione_Completa = 1
		WHERE	Id_Udc = @Id_Udc

		-- Inserimento del codice;
		SELECT	@CountRimanentiDaSpec = COUNT(1)
		FROM	AwmConfig.vDdtFittizioUdcIngombranti
		WHERE	Id_Ddt_Fittizio = @Id_Ddt_Fittizio
		
		IF @CountRimanentiDaSpec = 0
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
