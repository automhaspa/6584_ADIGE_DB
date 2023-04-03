SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROC [dbo].[sp_Scegli_Udc_Come_Sorgente]
	@Id_Udc					INT,
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
		DECLARE @XmlParam VARCHAR(MAX) = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc></Parametri>')
		DECLARE @Id_Partizione_Evento	INT
		DECLARE @Curr_Sottoarea			INT

		SELECT	@Curr_Sottoarea = C.ID_SOTTOAREA
		FROM	dbo.Udc_Posizione	UP
		JOIN	dbo.Partizioni		P
		ON		P.ID_PARTIZIONE = UP.Id_Partizione
		JOIN	dbo.SottoComponenti	SC
		ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
		JOIN	dbo.Componenti		C
		ON		C.ID_COMPONENTE = SC.ID_COMPONENTE
			AND UP.Id_Udc = @Id_Udc

		SELECT	@Id_Partizione_Evento = B.Id_Partizione
		FROM	dbo.Baie		B
		JOIN	dbo.Partizioni	P
		ON		P.ID_PARTIZIONE = B.Id_Partizione
		JOIN	dbo.SottoComponenti	SC
		ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
		JOIN	dbo.Componenti		C
		ON		C.ID_COMPONENTE = SC.ID_COMPONENTE
			AND C.ID_SOTTOAREA = @Curr_Sottoarea

		EXEC dbo.sp_Insert_Eventi
			@Id_Tipo_Evento			= 50,
		    @Id_Partizione			= @Id_Partizione_Evento,
		    @Id_Tipo_Messaggio		= '11000',
		    @XmlMessage				= @XmlParam,
		    @Id_Processo			= @Id_Processo,
		    @Origine_Log			= @Origine_Log,
		    @Id_Utente				= @Id_Utente,
		    @Errore					= @Errore OUTPUT
		

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
