SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROC [dbo].[sp_Genera_Consuntivo_Mancanti]
	@Id_Testata		INT,
	@Id_Riga		INT,
	@Id_Articolo	INT,
	@Qta_Prelievo	NUMERIC(18,4),
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
		--CONSUNTIVO L3
		INSERT INTO [L3INTEGRATION].[dbo].[HOST_LACKINGS_SUMMARY]
			([DT_INS],[STATUS],[DT_ELAB],[USERNAME],[ORDER_ID],[ORDER_TYPE],[PROD_LINE],[COMM_PROD],[COMM_SALE],[PROD_ORDER],[DT_EVASIONE],
				[LINE_ID],[ITEM_CODE],[QUANTITY],[SAP_DOC_NUM])
		SELECT	TOP (1)
				GETDATE(), 0, NULL,
				UPPER(@Id_Utente),
				ISNULL(tlp.ORDER_ID,AM.ORDER_ID),
				ISNULL(tlp.ORDER_TYPE,AM.ORDER_TYPE),
				ISNULL(am.PROD_LINE,TLP.PROD_LINE),
				CASE
					WHEN ISNULL(tlp.COMM_PROD, '') <> '' THEN tlp.COMM_PROD
					ELSE AM.COMM_PROD
				END,
				CASE
					WHEN ISNULL(tlp.COMM_SALE, '') <> '' THEN tlp.COMM_SALE
					ELSE AM.COMM_SALE
				END,
				ISNULL(AM.PROD_ORDER,'.'),
				ISNULL(tlp.DT_EVASIONE,AM.DT_EVASIONE),
				AM.Id_Riga,
				A.Codice,
				@Qta_Prelievo,
				AM.SAP_DOC_NUM
		FROM	Custom.AnagraficaMancanti		AM
		JOIN	Articoli						A
		ON		A.Id_Articolo = AM.Id_Articolo
		LEFT
		JOIN	Custom.TestataListePrelievo		TLP
		ON		AM.Id_Testata = TLP.ID
		WHERE	AM.Id_Testata = @Id_Testata
			AND	AM.Id_Riga = @Id_Riga
			AND AM.Id_Articolo = @Id_Articolo

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
