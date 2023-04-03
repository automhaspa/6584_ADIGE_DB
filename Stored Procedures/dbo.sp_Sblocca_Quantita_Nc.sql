SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





CREATE PROCEDURE [dbo].[sp_Sblocca_Quantita_Nc]
	@Id_UdcDettaglio		INT,
	@Quantita_Pezzi			NUMERIC(10,2),
	@FlagControlloQualita	BIT = 0,
	@FlagNonConformita		BIT,
	@CONTROL_LOT			VARCHAR(40)	= NULL,
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
		DECLARE	@Id_Udc				INT
		DECLARE @Wbs_Riferimento	VARCHAR(40)

		SELECT	@Id_Udc = Id_Udc,
				@Wbs_Riferimento = WBS_Riferimento
		FROM	Udc_Dettaglio
		WHERE	Id_UdcDettaglio = @Id_UdcDettaglio

		IF @Id_Udc = 702
			THROW 50001, 'OPERAZIONE NON ESEGUIBILE SU MODULA DA AWM', 1

		IF @FlagNonConformita = 0
			THROW 50001, 'SBLOCCO ATTUABILE SOLO SU QUANTITA NON CONFORME', 1

		--CONSUNTIVO DI SBLOCCO PER LA QUANTITA CONFORME
		EXEC [dbo].[sp_Genera_Consuntivo_MovimentiMan]
					@IdCausaleL3		= 'RRP',
					@IdUdcDettaglio		= @Id_UdcDettaglio,
					@IdCausaleMovimento = 3,
					@Quantity			= @Quantita_Pezzi,
					@WBS_CODE			= @Wbs_Riferimento,
					@CONTROL_LOT		= @CONTROL_LOT,
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Id_Utente			= @Id_Utente,
					@Errore				= @Errore			OUTPUT
		
		IF ISNULL(@Errore, '') <> ''
			RAISERROR(@Errore, 12, 1)

		UPDATE	Custom.NonConformita
		SET		Quantita = Quantita - @Quantita_Pezzi
		WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
			AND ISNULL(CONTROL_LOT,'') = ISNULL(@CONTROL_LOT,'')

		IF NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	Custom.NonConformita
							WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
								AND ISNULL(CONTROL_LOT,'') = ISNULL(@CONTROL_LOT,'')
								AND Quantita > 0
						)
			DELETE	Custom.NonConformita
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
				AND ISNULL(CONTROL_LOT,'') = ISNULL(@CONTROL_LOT,'')

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
