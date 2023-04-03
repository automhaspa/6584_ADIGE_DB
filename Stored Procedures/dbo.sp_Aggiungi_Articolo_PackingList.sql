SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Aggiungi_Articolo_PackingList]
	@Id_Evento		INT,
	@Id_Articolo	INT, 
	@Quantita		VARCHAR(10),
	@Id_Udc			INT,
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
	SET @Nome_StoredProcedure = Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		DECLARE	@Qta			NUMERIC(10,2) = CAST(REPLACE(@Quantita, ',', '.') as numeric (10,2))
		DECLARE @IdUdcDettaglio INT

		SELECT	@IdUdcDettaglio = Id_UdcDettaglio
		FROM	Udc_Dettaglio
		WHERE	Id_Udc = @Id_Udc
			AND Id_Articolo = @Id_Articolo

		IF @IdUdcDettaglio IS NULL
			THROW 50009, 'DETTAGLIO NON TROVATO. IMPOSSIBILE PROCEDERE',1

		--CARICO MANUALE DELLA MERCE SULLA UDC SELEZIONATA
		EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
					@Id_Udc					= @Id_Udc,
					@Id_UdcDettaglio		= @IdUdcDettaglio,
					@Id_Articolo			= @Id_Articolo,
					@Qta_Pezzi_Input		= @Qta,
					@Id_Causale_Movimento	= 3,
					@Id_Processo			= @Id_Processo,
					@Origine_Log			= @Origine_Log,
					@Id_Utente				= @Id_Utente,
					@Errore					= @Errore			OUTPUT

		IF (ISNULL(@Errore, '') <> '')
			RAISERROR(@Errore, 12, 1)

		--Elimino l'evento di scelta packing list
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
