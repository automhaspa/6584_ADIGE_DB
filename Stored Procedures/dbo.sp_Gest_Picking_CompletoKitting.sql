SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Gest_Picking_CompletoKitting]
	@Id_Evento				INT,
	@Id_Udc					INT,
	@Id_Articolo			INT,
	@Id_Udc_Destinazione	INT,
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
		DECLARE	@IdUdcDettaglio		INT
		DECLARE @QdRigaLista		INT
		DECLARE @IdRigaLista		INT

		SELECT	@IdUdcDettaglio = Id_UdcDettaglio
		FROM	Udc_Dettaglio
		WHERE	Id_Udc = @Id_Udc
			AND Id_Articolo = @Id_Articolo

		IF ISNULL(@Id_Riga_Lista,0) = 0
			SELECT	@Id_Riga_Lista = ISNULL(Id_Riga_Lista,0),
					@Id_Testata_Lista = ISNULL(Id_Testata_Lista,0)
			FROM	Missioni_Picking_Dettaglio
			WHERE	Id_Udc = @Id_Udc
				AND Id_Articolo = @Id_Articolo
				AND Id_Stato_Missione = 2

		--Causale 1 picking da lista con aggiornamento della lista
		EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
							@Id_Udc = @Id_Udc,
							@Id_UdcDettaglio = @IdUdcDettaglio,
							@Id_Articolo = @Id_Articolo,
							@Kitting = 1,
							@Qta_Pezzi_Input = @QuantitaDaPrelevare,
							@Id_Causale_Movimento = 1,
							@Id_Riga_Lista = @Id_Riga_Lista,
							@Id_Testata_Lista = @Id_Testata_Lista,
							@Id_Processo = @Id_Processo,
							@Origine_Log = @Origine_Log,
							@Id_Utente = @Id_Utente,
							@Errore = @Errore OUTPUT
							
		--Carico sulla udc KIT con causale 3
		EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
							@Id_Udc = @Id_Udc_Destinazione,
							@Id_Articolo = @Id_Articolo,
							@Qta_Pezzi_Input = @QuantitaDaPrelevare,
							@Id_Causale_Movimento = 3,
							@Id_Riga_Lista = @Id_Riga_Lista,
							@Id_Testata_Lista = @Id_Testata_Lista,
							@Id_Processo = @Id_Processo,
							@Origine_Log = @Origine_Log,
							@Id_Utente = @Id_Utente,
							@Errore = @Errore OUTPUT

		--Controllo il fine kit
		EXEC [dbo].[sp_Update_Stati_ListeKitting]
					@Id_Testata_Lista = @Id_Testata_Lista,
					@Id_Processo = @Id_Processo,
					@Origine_Log = @Origine_Log,
					@Id_Utente = @Id_Utente,
					@Errore = @Errore OUTPUT

		DECLARE	@CodiceUdcDestinaz	VARCHAR(20)
		DECLARE	@KitId				INT

		SELECT	@CodiceUdcDestinaz = Codice_Udc
		FROM	Udc_Testata
		WHERE	Id_Udc = @Id_Udc_Destinazione
		
		SELECT	@KitId = Kit_Id
		FROM	Custom.OrdineKittingUdc
		WHERE	Id_Udc = @Id_Udc_Destinazione
			AND Id_Testata_Lista = @Id_Testata_Lista

		DECLARE @CountMissioniKit			INT
		DECLARE @CountMissioniKitEseguite	INT

		SELECT	@CountMissioniKit = COUNT(1)
		FROM	Missioni_Picking_Dettaglio
		WHERE	Id_Testata_Lista = @Id_Testata_Lista
			AND Kit_Id = @KitId

		SELECT	@CountMissioniKitEseguite = COUNT(1)
		FROM	Missioni_Picking_Dettaglio
		WHERE	Id_Testata_Lista = @Id_Testata_Lista
			AND Kit_Id = @KitId
			AND Id_Stato_Missione = 4
		
		IF @CountMissioniKitEseguite = @CountMissioniKit
		BEGIN
			EXEC @Return = dbo.sp_Insert_CreaMissioni
							@Id_Udc = @Id_Udc,
							@Id_Partizione_Destinazione = 2110,
							@XML_PARAM = '',
							@Id_Tipo_Missione = 'ING',
							@Id_Processo = @Id_Processo,
							@Origine_Log = @Origine_Log,
							@Id_Utente = @Id_Utente,
							@Errore = @Errore OUTPUT
		END

		DECLARE	@ArticoliUdcDaPrelevare		INT
		DECLARE	@ArticoliUdcPrelevati		INT
		
		SELECT	@ArticoliUdcDaPrelevare = COUNT(1)
		FROM	Missioni_Picking_Dettaglio
		WHERE	Id_Udc = @Id_Udc
			AND Id_Testata_Lista = @Id_Testata_Lista
			AND Kit_Id = @KitId

		SELECT	@ArticoliUdcPrelevati = COUNT(1)
		FROM	Missioni_Picking_Dettaglio
		WHERE	Id_Udc = @Id_Udc
			AND Id_Testata_Lista = @Id_Testata_Lista
			AND Id_Stato_Missione = 4
			AND Kit_Id = @KitId

		--Se ho completato la lista per l'udc la stocco in automatico
		IF @ArticoliUdcDaPrelevare = @ArticoliUdcPrelevati
		BEGIN
			DECLARE @Id_Partizione INT
			SELECT	@Id_Partizione = Id_Partizione
			FROM	Udc_Posizione
			WHERE	Id_Udc = @Id_Udc

			--Se mi trovo nelle baie di picking
			IF EXISTS	(
							SELECT TOP 1 1
							FROM	Udc_Posizione
							WHERE	Id_Udc = @Id_Udc
								AND Id_Partizione NOT IN (3203)
						)
				EXEC [dbo].[sp_Stocca_Udc]
							@Id_Udc = @Id_Udc,
							@Id_Testata_Lista = @Id_Testata_Lista,
							@Id_Evento = @Id_Evento,
							@Id_Processo = @Id_Processo,
							@Origine_Log = @Origine_Log,
							@Id_Utente = @Id_Utente,
							@Errore = @Errore OUTPUT
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
