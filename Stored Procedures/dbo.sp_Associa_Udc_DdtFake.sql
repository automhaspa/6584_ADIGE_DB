SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Associa_Udc_DdtFake]
	@Id_Udc			INT,
	@Id_Evento		INT,
	@Tipo_Udc		VARCHAR(1),
	@CODICE_DDT		VARCHAR(11),
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
		DECLARE @IdDdtFakeRiferimento	INT
		DECLARE @NUdcDdtPerTipo			INT
		DECLARE @UdcTipoADaAnagrafare	INT
		DECLARE @UdcTipoBDaAnagrafare	INT

		SELECT	@IdDdtFakeRiferimento = ID
		FROM	Custom.AnagraficaDdtFittizi
		WHERE	Codice_DDT = @CODICE_DDT

		--Se è entrata un UDC di tipo A ma sono già state anagrafate lancio l'eccezione
		IF (@Tipo_Udc = 'A')
			BEGIN
				SELECT	@UdcTipoADaAnagrafare = UDC_TIPO_A_DA_ANAGRAFARE
				FROM	AwmConfig.vBolleFittizie
				WHERE	CODICE_DDT = @CODICE_DDT

				IF (@UdcTipoADaAnagrafare < 1)
					THROW 50002, 'UDC DI TIPO: A GIA ANAGRAFATE E PRESENTI IN MAGAZZINO PER IL DDT SELEZIONATO', 1
			END

		IF (@Tipo_Udc = 'B')
			BEGIN
				SELECT	@UdcTipoBDaAnagrafare = UDC_TIPO_B_DA_ANAGRAFARE
				FROM	AwmConfig.vBolleFittizie
				WHERE	CODICE_DDT = @CODICE_DDT

				IF (@UdcTipoBDaAnagrafare < 1)
					THROW 50002, 'UDC DI TIPO: B GIA ANAGRAFATE E PRESENTI IN MAGAZZINO PER IL DDT SELEZIONATO', 1
			END

		--Associo l'Id-ddt fittizio avendo  il codice progressivo unique
		IF @IdDdtFakeRiferimento IS NULL
			THROW 50001, 'IMPOSSIBILE RECUPERARE L ID DDT DI RIFERIMENTO',1

		UPDATE	Udc_Testata
		SET		Id_Ddt_Fittizio = @IdDdtFakeRiferimento
		WHERE	Id_Udc = @Id_Udc

		--LANCIO LA MISSIONE DI INBOUND
		DECLARE @Id_Partizione_Destinazione INT
		DECLARE	@Id_Partizione				INT
		DECLARE @Id_Tipo_Messaggio			INT
		DECLARE	@ID_MISSIONE				INT

		SELECT	@Id_Partizione = Id_Partizione
		FROM	Udc_Testata		ut
		JOIN	Udc_Posizione	up
		ON		ut.Id_Udc = up.Id_Udc

		--SONO ANCORA NELLA SEZIONE LU_ON_ASI
		SELECT	@Id_Partizione_Destinazione = Id_Partizione_OK
		FROM	dbo.Procedure_Personalizzate_Gestione_Messaggi
		WHERE	Id_Tipo_Messaggio = '11000'

		-- Creo la missione per l'Udc			
		EXEC @Return = dbo.sp_Insert_CreaMissioni
							@Id_Udc = @Id_Udc,
                            @Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
                            @Id_Tipo_Missione = 'ING',
                            @Id_Missione = @ID_MISSIONE OUTPUT,
                            @Id_Processo = @Id_Processo,
                            @Origine_Log = @Origine_Log,
                            @Id_Utente = @Id_Utente,
                            @Errore = @Errore OUTPUT

		--Dopo aver avviato la missione elimino l'evento
		DELETE	Eventi
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
