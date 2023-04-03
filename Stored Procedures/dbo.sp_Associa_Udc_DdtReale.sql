SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Associa_Udc_DdtReale]
	@Id_Udc				INT,
	@Id_Evento			INT,
	@Tipo_Udc			VARCHAR(1),
	@NUMERO_BOLLA_ERP	VARCHAR(40) = NULL,
	@CAUSALE_DDT		VARCHAR(3)	= NULL,
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
		DECLARE @Quantita			INT
		DECLARE @Id_Partizione		INT
		DECLARE @Id_Testata_Bolla	INT
		DECLARE @Action				XML = NULL;

		;THROW 50003, 'DA RIVEDERE IN FASE DI INGRESSO MULTI DDT PER TESTATA E DETTAGLIO', 1

		-- Inserimento del codice;
		IF	@NUMERO_BOLLA_ERP IS NULL
				OR
			@CAUSALE_DDT IS NULL
			THROW 50003, 'NESSUN DDT SELEZIONATO', 1

		--Recupero l'Id Testata di riferimento 
		SELECT	@Id_Testata_Bolla = ID
		FROM	Custom.TestataOrdiniEntrata
		WHERE	LOAD_ORDER_ID = @NUMERO_BOLLA_ERP
			AND LOAD_ORDER_TYPE = @CAUSALE_DDT

		--Controllo che ci siano delle righe abbinate
		IF EXISTS	(
						SELECT	TOP (1) 1
						FROM	Custom.RigheOrdiniEntrata
						WHERE	Id_Testata = @Id_Testata_Bolla
					)
			BEGIN
				--Aggiorno la udc testata assegnando l'id_Ddt reale
				--UPDATE ud SET Id_Ddt_Reale = @Id_Testata_Bolla WHERE Id_Udc = @Id_Udc
				SET @Action = CONCAT(
										'<StoredProcedure ProcedureKey="aggiornaQuantitaBolla">
											<ActionParameter>
											<Parameter>
												<ParameterName>Id_Udc</ParameterName>
												<ParameterValue>',@Id_Udc,'</ParameterValue>
											</Parameter>
											<Parameter>
												<ParameterName>ID</ParameterName>
												<ParameterValue>',@Id_Testata_Bolla,'</ParameterValue>
											</Parameter>
											</ActionParameter>
										</StoredProcedure>'
									)
				EXEC [dbo].[sp_Insert_Eventi]
						@Id_Tipo_Evento = 27 
						,@Id_Partizione = @Id_Partizione
						,@Id_Tipo_Messaggio = '11000'
						,@XmlMessage = @Action
						,@id_evento_padre	= @Id_Evento
						,@Id_Processo = @Id_Processo
						,@Origine_Log = @Origine_Log
						,@Id_Utente = @Id_Utente
						,@Errore = @Errore OUTPUT
			END	
		ELSE
			THROW 50002, 'NESSUNA RIGA ABBINATA ALLA BOLLA SELEZIONATA',1;

		--Aggiorno lo stato dell'evento appena aperto
		UPDATE	Eventi
		SET		Id_Tipo_Stato_Evento = 3
		WHERE	Id_Evento = @Id_Evento
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
