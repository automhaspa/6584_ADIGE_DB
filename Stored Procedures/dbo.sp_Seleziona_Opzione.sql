SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Seleziona_Opzione]
	@Id_Udc			INT,
	@Id_Evento		INT,
	@Codice_Udc		VARCHAR(50),
	@ID_OPZIONE		INT,
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
	SET @Nome_StoredProcedure	= Object_Name(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount				= @@TRANCOUNT;

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @Id_Partizione	INT
		DECLARE @Action			XML = NULL

		--Seleziono partizione conoscendo id_udc (Appena creata)
		SELECT	@Id_Partizione = Id_Partizione
		FROM	Udc_Posizione
		WHERE	Id_Udc = @Id_Udc
		-- Inserimento del codice;

		--vTipoOpzioniSpecializzazione 1 SPECIALIZZA UDC
		IF	@ID_OPZIONE = 1
			BEGIN
				;THROW 50009, 'OPZIONE NON GESTITA',1
				--Lancio evento di specializzazione
				
				--Associa Bolla con DDT

				--Evento associazione bolla
			END

		--STOCCA UDC, rimando in magazzino
		ELSE IF @ID_OPZIONE = 2
			BEGIN
				DECLARE @Id_Partizione_Destinazione		INT
				DECLARE @QUOTADEPOSITOX					INT
				DECLARE @Id_Tipo_Missione				VARCHAR(3) = 'ING'
				DECLARE @ERROREPU						VARCHAR(200)

				--Proposta Ubicazione
				BEGIN TRY
					EXEC @Id_Partizione_Destinazione = [dbo].[sp_Output_PropostaUbicazione]
								@Id_Udc			= @Id_Udc,
								@QUOTADEPOSITOX = @QUOTADEPOSITOX	OUTPUT,
								@Id_Processo	= @Id_Processo,
								@Origine_Log	= @Origine_Log,
								@Id_Utente		= @Id_Utente,
								@Errore			= @Errore			OUTPUT
				END TRY
				BEGIN CATCH
					SET @ERROREPU = '<Ubicazione>PROPOSTA UBICAZIONE FALLITA. ex </Ubicazione>'
				END CATCH

				IF ISNULL(@Id_Partizione_Destinazione,0) = 0
					SET @ERROREPU = '<Ubicazione>PROPOSTA UBICAZIONE FALLITA. </Ubicazione>'

				--Missione inbound
				 EXEC @Return = dbo.sp_Insert_CreaMissioni
									@Id_Udc = @Id_Udc,
			                        @Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
			                        @QUOTADEPOSITOX = @QUOTADEPOSITOX,
									@XML_PARAM = @ERROREPU,
			                        @Id_Tipo_Missione = @Id_Tipo_Missione,
			                        @Id_Processo = @Id_Processo,
			                        @Origine_Log = @Origine_Log,
			                        @Id_Utente = @Id_Utente,
			                        @Errore = @Errore OUTPUT
			END

		----ESTRAI UDC, lo mando in Outbound
		--ELSE IF (@ID_OPZIONE = 3)
		--BEGIN
			
		--END
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
