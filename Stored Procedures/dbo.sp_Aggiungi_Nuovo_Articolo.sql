SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Aggiungi_Nuovo_Articolo]
	@Id_Articolo			INT,
	@Id_Udc					INT,
	@Qta_Pezzi_Input		NUMERIC (10,2),
	@Id_Causale_Movimento	INT,
	@Id_Causale				VARCHAR(5)		= NULL,
	--MOVIMENTAZIONE MANUALE CAMPI L3
	@SUPPLIER_CODE			VARCHAR(500)	= NULL,
	@REF_NUMBER				VARCHAR(500)	= NULL,
	@DOC_NUMBER				VARCHAR(500)	= NULL,
	@WBS_CODE				VARCHAR(24)		= NULL,
	@Id_Magazzino			VARCHAR(5)		= NULL,
	@FLAG_RIAPRIRE			BIT				= NULL,
	@NOTES					VARCHAR(150)	= NULL,
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
		DECLARE @Msg_Errore VARCHAR(MAX)

		DECLARE @Id_Udc_Dettaglio	INT
		DECLARE @Id_Partizione_Udc	INT

		SELECT	@Id_Partizione_Udc = Id_Partizione
		FROM	Udc_Posizione
		WHERE	Id_Udc = @Id_Udc
		
		IF @Id_Partizione_Udc = 3203 AND EXISTS (SELECT 1 FROM dbo.Udc_Testata WHERE ID_UDC = @Id_Udc AND Id_Tipo_Udc IN ('1','2','3'))
			THROW 50001, 'OPERAZIONE NON AUTORIZZATA DA BAIA 3B03 SU UDC DI TIPO A',1

		IF	@WBS_CODE IS NOT NULL
				AND
			NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	Udc_Dettaglio
							WHERE	WBS_Riferimento = @WBS_CODE
						)
			THROW 50009, 'Il progetto WBS indicato non esiste.',1

		--Controllo coerenza causale L3 
		IF ISNULL(@Id_Causale, '') <> ''
		BEGIN
			DECLARE @Action varchar(1)
			SELECT	@Action = ISNULL(Action, '')
			FROM	Custom.CausaliMovimentazione
			WHERE	Id_Causale = @Id_Causale

			IF (@Action = '-' OR @Action = '')
				THROW 50001, ' HAI SELEZIONATO UNA CAUSALE DI SCARICO MERCE, MENTRE STAI EFFETTUANDO UN CARICO MANUALE', 1
			
			IF @Id_Causale = 'RMI' 
				IF @Id_Magazzino IS NULL
					THROW 50002, 'OBBLIGATORIO IL CAMPO MAGAZZINO PER LA CAUSALE RMI.',1
				ELSE
					SET @REF_NUMBER = @Id_Magazzino

			--Controllo campi obbligatori
			IF @Id_Causale = 'SPI'
			BEGIN
				IF @FLAG_RIAPRIRE = 'True'
						AND
					(ISNULL(@DOC_NUMBER, '') = '' OR ISNULL(@SUPPLIER_CODE,'')='')
					THROW 50002, 'OBBLIGATORI CAMPI COD CLIENTE/FORNITORE/ADETTO E NUM DOCUMENTO PER CAUSALE SPI CON RIAPERTURA IMPEGNO',1
				ELSE IF ISNULL(@FLAG_RIAPRIRE,'True') = 'False'
							AND
						--(ISNULL(@DOC_NUMBER, '') = '' OR 
						ISNULL(@REF_NUMBER, '') = ''--)
					--THROW 50002, 'OBBLIGATORI CAMPI COD CLIENTE/FORNITORE/ADETTO E NUM DOCUMENTO E NUM RIFERIMENTO PER CAUSALE SPI SENZA RIAPERTURA IMPEGNO',1
					THROW 50002, 'OBBLIGATORIO CAMPO NUM RIFERIMENTO PER CAUSALE SPI SENZA RIAPERTURA IMPEGNO',1
			END

			IF @Id_Causale = 'RPO'
			BEGIN
				IF @SUPPLIER_CODE IS NOT NULL
					OR @REF_NUMBER IS NOT NULL
					OR @DOC_NUMBER IS NOT NULL
					OR @FLAG_RIAPRIRE= 1
				BEGIN
					SELECT	@SUPPLIER_CODE = NULL,
							@REF_NUMBER = NULL,
							@DOC_NUMBER = NULL,
							@FLAG_RIAPRIRE = 0

					SET @Msg_Errore = 'CON LA CAUSALE RPO NON DEVI SPECIFICARE NESSUN CAMPO DIVERSO DALLA QUANTITA'
				END
			END
		END

		DECLARE @PROD_ORDER VARCHAR(12)
		IF ISNULL(@FLAG_RIAPRIRE,'True') = 'False'
		BEGIN
			SET @DOC_NUMBER = @REF_NUMBER
			SET @REF_NUMBER = RIGHT('000000000000'+ISNULL(@REF_NUMBER,''),12)
			SET @SUPPLIER_CODE = ''
		END
		ELSE
		IF @Id_Causale = 'SPI'
		BEGIN
			SET @DOC_NUMBER = RIGHT('0000000000'+ISNULL(@DOC_NUMBER,''),10)
			SET @SUPPLIER_CODE = RIGHT('000000'+ISNULL(@SUPPLIER_CODE,''),6)
			SET @PROD_ORDER = RIGHT('000000000000'+ISNULL(@REF_NUMBER,''),12)
			SET @REF_NUMBER = ''
		END

		SET @WBS_CODE = UPPER(@WBS_CODE)
		--L'operatore potrebbe aggiungere un nuovo articolo ma che è già presente su Udc
			-->DISTINGUO LE RIGHE A PROGETTO DA QUELLE NON HA PROGETTO
		SELECT	@Id_Udc_Dettaglio = Id_UdcDettaglio
		FROM	Udc_Dettaglio
		WHERE	Id_Articolo = @Id_Articolo
			AND Id_Udc = @Id_Udc
			AND ISNULL(WBS_Riferimento,'') = ISNULL(@WBS_CODE,'')

		IF @NOTES = ''
			SET @NOTES = NULL

		EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc	
					@Id_Udc = @Id_Udc,
					@Id_Articolo = @Id_Articolo,
					@Id_UdcDettaglio = @Id_Udc_Dettaglio,
					@Qta_Pezzi_Input = @Qta_Pezzi_Input,
					@Id_Causale_Movimento = @Id_Causale_Movimento,
					@Id_Causale = @Id_Causale,
					@Id_Processo = @Id_Processo,
					@Origine_Log = @Origine_Log,
					@SUPPLIER_CODE = @SUPPLIER_CODE ,
					@REF_NUMBER = @REF_NUMBER,
					@DOC_NUMBER = @DOC_NUMBER,
					--@REASON = @REASON,
					--@RETURN_DATE = @RETURN_DATE,
					@WBS_CODE = @WBS_CODE,
					@NOTES = @NOTES,
					@Id_Utente = @Id_Utente,
					@Errore = @Errore OUTPUT

		IF ISNULL(@Errore, '') <> ''
			THROW 50004, @Errore,1

		--STANNO AGGIUNGENDO UN ARTICOLO PER CUI HO DEL MANCANTE -- VERIFICO IL PROGETTO
			--> GENERO EVENTO PER EVASIONE MANCANTE
		IF 
			@Id_Partizione_Udc IN (3404, 3604)
				AND
			EXISTS	(
						SELECT	TOP 1 1
						FROM	Custom.AnagraficaMancanti
						WHERE	Id_Articolo = @Id_Articolo
							AND Qta_Mancante > 0
							AND ISNULL(WBS_Riferimento,'') = ISNULL(@WBS_CODE,'')
					)
		BEGIN
			DECLARE @Id_Partizione_Destinazione INT
			SELECT	@Id_Partizione_Destinazione = ID_Partizione
			FROM	Udc_Posizione
			WHERE	Id_Udc = @Id_Udc
				
			DECLARE @XmlParam xml = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc><Id_Articolo>',@Id_Articolo,'</Id_Articolo><Missione_Modula>',0,'</Missione_Modula></Parametri>');
			EXEC @Return = sp_Insert_Eventi
					@Id_Tipo_Evento		= 36,
					@Id_Partizione		= @Id_Partizione_Destinazione,
					@Id_Tipo_Messaggio	= 1100,
					@XmlMessage			= @XmlParam,
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Id_Utente			= @Id_Utente,
					@Errore				= @Errore OUTPUT;

			IF @Return <> 0 RAISERROR(@Errore,12,1);
		END

		IF @Msg_Errore IS NOT NULL
			SET @Errore = @Msg_Errore

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
