SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Gest_Picking_Ingombrante]
	@Id_Udc					INT,
	@Id_Articolo			INT,
	@QuantitaDaPrelevare	NUMERIC(10,2),
	@QuantitaPrelUtente		NUMERIC(10,2),
	@Id_Riga_Lista			INT,
	@Id_Testata_Lista		INT,
	@Id_Evento				INT = NULL,
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
		-- Dichiarazioni Variabili;
		DECLARE @TipoPartizione VARCHAR(2)
		DECLARE @IdUdcDettaglio	INT = NULL

		SELECT	@TipoPartizione = P.ID_TIPO_PARTIZIONE
		FROM	Udc_Posizione	UP
		JOIN	Partizioni		P
		ON		UP.Id_Partizione = P.ID_PARTIZIONE
		WHERE	Id_Udc = @Id_Udc
		
		IF @TipoPartizione NOT IN ('MI', 'AS')
			THROW 50001, 'ARTICOLO NON PRESENTE NEL MAGAZZINO INGOMBRANTI', 1

		IF @QuantitaPrelUtente < 0
			THROW 50002, ' INSERITA QUANTITA MINORE DI 0',1

		DECLARE @WBS_RIGA_LISTA		VARCHAR(MAX)
		SELECT	@WBS_RIGA_LISTA = CASE WHEN ISNULL(Vincolo_WBS,0) = 0 THEN NULL ELSE WBS_Riferimento END
		FROM	Custom.RigheListePrelievo
		WHERE	ID = @Id_Riga_Lista

		--Recuper l'id udc dettaglio
		SELECT	@IdUdcDettaglio = Id_UdcDettaglio
		FROM	Udc_Dettaglio
		WHERE	Id_Udc = @Id_Udc
			AND Id_Articolo = @Id_Articolo
			AND ISNULL(WBS_RIFERIMENTO,'') = ISNULL(@WBS_RIGA_LISTA,'')

		DECLARE @Id_Baia_Ingombrante INT
		SELECT	@Id_Baia_Ingombrante = CASE WHEN Id_Tipo_Udc = 'M' THEN 7685 ELSE 7684 END
		FROM	dbo.Udc_Testata
		WHERE	Id_Udc = @Id_Udc


		--AGGIUNGO IL RECORD PER LA STAMPA AUTOMATICA PRIMA DI PERDERE UN QUALSIASI DATO
		EXEC [Printer].[sp_InsertAdditionalRequest_Picking]
				@Id_Evento			= @Id_Evento,
				@Id_Partizione		= @Id_Baia_Ingombrante, --E' LA BAIA DI GESTIONE INGOMBRANTI
				@Id_Articolo		= @Id_Articolo,
				@Quantita_Articolo	= @QuantitaPrelUtente,
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
					@Id_Articolo			= @Id_Articolo,
					@Qta_Pezzi_Input		= @QuantitaPrelUtente,
					@Id_Causale_Movimento	= 1,
					@Id_Riga_Lista			= @Id_Riga_Lista,
					@Id_Testata_Lista		= @Id_Testata_Lista,
					@Id_Processo			= @Id_Processo,
					@Origine_Log			= @Origine_Log,
					@Id_Utente				= @Id_Utente,
					@Errore					= @Errore			OUTPUT

		--FORZA LA CHIUSURA DELLA RIGA SE E' UN PICKING DI INGOMBRANTE ANCHE SE E UN PRELIEVO PARZIALE
		--AGGIORNO STATO A 4 PICKING PARZIALE
		--INVIO CONSUNTIVO CON FL_VOID  A 1 E ACTUAL QUANTITY A 0
		--Controllo stato lista 
		EXEC [dbo].[sp_Update_Stati_ListePrelievo]
					@Id_Testata_Lista	= @Id_Testata_Lista,
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Id_Utente			= @Id_Utente,
					@Errore				= @Errore		OUTPUT

		--Controllo le righe rimaste per la chiusura evento 
			--> essendoci la pagina da dove possono chiudere le righe senza passare dall'evento devo ricavarmi l'id dell'evento
		
		IF NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	AwmConfig.vRighePrelievoAttive
							WHERE	Id_Testata_Lista = @Id_Testata_Lista
								AND Nome_Magazzino = 'INGOMBRANTI'
						)
		BEGIN
			IF @Id_Evento IS NULL
				SELECT	@Id_Evento = Id_Evento
				FROM	EVENTI
				WHERE	Xml_Param.value('data(//Id_Testata_Lista)[1]','int') = @Id_Testata_Lista
					AND Id_Tipo_Evento = 6

			IF @Id_Evento IS NOT NULL
				DELETE	Eventi
				WHERE	Id_Evento = @Id_Evento
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
