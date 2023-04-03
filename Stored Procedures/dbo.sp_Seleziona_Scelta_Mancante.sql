SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Seleziona_Scelta_Mancante]
	@Id_Articolo		INT,
	@Id_Opzione			INT,
	@Id_Udc				INT,
	@Missione_Modula	INT,
	@Id_Evento			INT,
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
		--Prelievo articolo mancante
		IF @Id_Opzione = 1
		BEGIN
			DECLARE	@XmlParam						XML = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc><Id_Articolo>',@Id_Articolo,'</Id_Articolo><Missione_Modula>',@Missione_Modula,'</Missione_Modula></Parametri>')
			DECLARE @Id_Partizione_Destinazione		INT

			SELECT	@Id_Partizione_Destinazione = ID_Partizione
			FROM	Udc_Posizione
			WHERE	Id_Udc = @Id_Udc

			EXEC @Return = sp_Insert_Eventi
					@Id_Tipo_Evento		= 36,
					@Id_Partizione		= @Id_Partizione_Destinazione,
					@Id_Tipo_Messaggio	= 1100,
					@XmlMessage			= @XmlParam,
					@id_evento_padre	= @Id_Evento,
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Id_Utente			= @Id_Utente,
					@Errore				= @Errore					OUTPUT

			IF @Return <> 0
				RAISERROR(@Errore,12,1)
		END

		--LASCIO INVARIATA L'UDC
		ELSE IF @Id_Opzione = 2
		BEGIN
			--SE PROVIENE DA UN UDC CHE DEVE ANDARE IN MODULA CREO LA MISSIONE
			IF @Missione_Modula = 1
			BEGIN
				--ID TESTATA DEL DDT E NUMERO RIGA LI RECUPERO DALL' UDC TESTATA E DETTAGLIO DELL UDC A TERRA
				DECLARE @NRigaDdt		INT
				DECLARE @IdTestataDdt	INT

				SELECT	@IdTestataDdt	= ISNULL(Id_Ddt_Reale,0),
						@NRigaDdt		= ISNULL(ud.Id_Riga_Ddt,0)
				FROM	Udc_Testata		UT
				JOIN	Udc_Dettaglio	UD
				ON		UT.Id_Udc = UD.Id_Udc
				WHERE	UT.Id_Udc = @Id_Udc

				EXEC [dbo].[sp_Insert_Crea_Missioni_Modula]
							@Id_Udc			= @Id_Udc,
							@Id_Testata		= @IdTestataDdt,
							@NUMERO_RIGA	= @NRigaDdt,
							@Id_Processo	= @Id_Processo,
							@Origine_Log	= @Origine_Log,
							@Id_Utente		= @Id_Utente,
							@Errore			= @Errore			OUTPUT

				IF ISNULL(@Errore, '') <> ''
					RAISERROR (@Errore, 12, 1)
			END
		END

		--In ogni caso elimino l'evento
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
