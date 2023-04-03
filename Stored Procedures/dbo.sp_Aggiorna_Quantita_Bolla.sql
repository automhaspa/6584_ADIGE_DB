SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Aggiorna_Quantita_Bolla]
	@Id_Udc				INT,
	@Id_Evento			INT,
	@NUMERO_RIGA_DDT	INT,
	@NUMERO_BOLLA		VARCHAR(40),
	@CODICE_ARTICOLO	VARCHAR(5),
	--Quantità inserita da magazziniere 
	@QUANTITA_SU_UDC	INT,
	--Id testata bolla
	@ID					INT,
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
		-- Dichiarazioni Variabili;
		DECLARE @Id_Udc_F				INT = @Id_Udc
		DECLARE @Tipo_Udc				INT
		DECLARE @QuantitaDaAggiungere	INT

		-- Inserimento del codice;
		SELECT	@QuantitaDaAggiungere = SUM(ROE.QUANTITA)
		FROM	AwmConfig.vRigheOrdiniEntrata	ROE
		JOIN	AwmConfig.vTestataOrdiniEntrata	TOE
		ON		TOE.ID = ROE.Id_Testata
		WHERE	NUMERO_RIGA = @NUMERO_RIGA_DDT
			AND TOE.NUMERO_BOLLA_ERP = @NUMERO_BOLLA
			AND ROE.STATO_RIGA = 1

		--Se la quantità dichiarata del determinato articolo è  minore o uguale aggiungo udc dettaglio
		IF @QUANTITA_SU_UDC <= @QuantitaDaAggiungere
		BEGIN
			DECLARE @Id_Articolo_Selezionato		INT = NULL
			DECLARE @Matricola_Art					INT
			DECLARE @Lotto_Art						VARCHAR(40)
			DECLARE @Flag_Cq						BIT = 0

			--Recupero l'id articolo
			SELECT	@Id_Articolo_Selezionato = Id_Articolo
			FROM	Articoli
			WHERE	Codice = @CODICE_ARTICOLO

			IF (ISNULL(@Id_Articolo_Selezionato,'') = '')
				THROW 50000,'NESSUNA CORRISPONDENZA TRA ARTICOLO SELEZIONATO DA DDT E ARTICOLI CODIFICATI IN AWM',1;

			--Recupero matricola e lotto
			SELECT	@Lotto_Art = CONTROL_LOT,
					@Matricola_Art = REF_NUMBER,
					@Flag_Cq = FL_QUALITY_CHECK
			FROM	Custom.RigheOrdiniEntrata

			--Aggiungo all'Udc Dettaglio 
			DECLARE	@return_value		INT
			DECLARE @Errore_sp			VARCHAR(500)

			EXEC @return_value = [dbo].[sp_Update_Aggiorna_Contenuto_Udc]
						@Id_Udc					= @Id_Udc_F,
						@Id_UdcDettaglio		= NULL,
						@Id_Articolo			= @Id_Articolo_Selezionato,
						@Qta_Pezzi_Input		= @QUANTITA_SU_UDC,
						@Id_Causale_Movimento	= 3,
						@Id_UdcContainer		= NULL,
						@Qta_Persistenza_Nuova	= NULL,
						@Matricola				= NULL,
						@Lotto					= NULL,
						@Data_Scadenza			= NULL,
						@Id_Gruppo_Lista		= NULL,
						@Id_Lista				= NULL,
						@Id_Dettaglio			= NULL,
						@FlagControlloQualita	= @Flag_Cq,
						@Id_Processo			= @Id_Processo,
						@Origine_Log			= @Origine_Log,
						@Id_Utente				= @Id_Utente,
						@Errore					= @Errore_sp OUTPUT
			
			--Se non ho errori in fase inserimento udc Dettaglio
			IF (ISNULL(@Errore_sp, '') = '')
			BEGIN
				--LANCIO LA MISSIONE DI INBOUND 
				DECLARE	@Id_Partizione_Destinazione		INT
				DECLARE	@Id_Partizione					INT
				DECLARE	@Id_Tipo_Messaggio				INT
				DECLARE	@ID_MISSIONE					INT

				SELECT	@Id_Partizione = Id_Partizione
				FROM	Udc_Testata				UT
				JOIN	Udc_Posizione			UP
				ON		UT.Id_Udc = UP.Id_Udc

				SELECT	@Id_Partizione_Destinazione = Id_Partizione_OK
				FROM	dbo.Procedure_Personalizzate_Gestione_Messaggi
				WHERE	Id_Partizione = @Id_Partizione
					AND Id_Tipo_Messaggio = '11000'	--SONO ANCORA NELLA SEZIONE LU_ON_ASI

				-- Creo la missione per l'Udc			
				EXEC @Return = dbo.sp_Insert_CreaMissioni
							@Id_Udc						= @Id_Udc,
							@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
							@Id_Tipo_Missione			= 'ING',
							@Id_Missione				= @ID_MISSIONE			OUTPUT,
							@Id_Processo				= @Id_Processo,
							@Origine_Log				= @Origine_Log,
							@Id_Utente					= @Id_Utente,
							@Errore						= @Errore				OUTPUT
			END
			ELSE
				THROW 50000, @Errore_Sp, 1
		END

		-- Fine del codice;

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
