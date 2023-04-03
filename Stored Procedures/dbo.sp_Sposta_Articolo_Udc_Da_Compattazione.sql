SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROC [dbo].[sp_Sposta_Articolo_Udc_Da_Compattazione]
	--ID UDC DETTAGLIO  SORGENTE
	@Id_Evento				INT,
	@Id_UdcDettaglio		INT,
	--ID UDC DESTINAZIONE
	@Id_Udc					INT,
	--Quantita Da Spostare
	@Quantita				NUMERIC(10,2),
	@FlagControlloQualita	BIT,
	@FlagNonConformita		BIT,
	@Quantita_Pezzi			NUMERIC(10,2),
	-- Parametri Standard;
	@Id_Processo			VARCHAR(30),
	@Origine_Log			VARCHAR(25),
	@Id_Utente				VARCHAR(16),	
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
		DECLARE @Id_Udc_Sorgente INT
		SELECT	@Id_Udc_Sorgente = Id_Udc
		FROM	dbo.Udc_Dettaglio
		WHERE	Id_UdcDettaglio = @Id_UdcDettaglio

		IF EXISTS(SELECT TOP 1 1 FROM dbo.Udc_Testata WHERE Id_Udc = @Id_Udc AND ISNULL(Da_Compattare,0) = 1)
			AND
			EXISTS(SELECT TOP 1 1 FROM dbo.Udc_Testata WHERE Id_Udc = @Id_Udc_Sorgente AND ISNULL(Da_Compattare,0) = 1)
		BEGIN
			EXEC dbo.sp_Sposta_Articolo_Udc
					@Id_UdcDettaglio		= @Id_UdcDettaglio,
					@Id_Udc					= @Id_Udc,
					@Quantita				= @Quantita,
					@FlagControlloQualita	= @FlagControlloQualita,
					@FlagNonConformita		= @FlagNonConformita,
					@Quantita_Pezzi			= @Quantita_Pezzi,
					@Id_Processo			= @Id_Processo,
					@Origine_Log			= @Origine_Log,
					@Id_Utente				= @Id_Utente,
					@Errore					= @Errore				OUTPUT
		END
		ELSE
			THROW 50009, 'NON E'' POSSIBILE COMPATTARE DUE UDC SE NON SONO ENTRAMBE DA COMPATTARE.',1

		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.Udc_Dettaglio WHERE Id_Udc = @Id_Udc_Sorgente)
			DELETE dbo.Eventi
			WHERE	Id_Evento = @ID_EVENTO


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
