SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Chiudi_Prelievo_Mancanti]
	@Missione_Modula	INT,
	@Id_Evento			INT,
	@Id_Udc				INT,
	@Invia_Dati_A_Sap	BIT = 1,
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
		--SE PROVIENE DA UN UDC CHE DEVE ANDARE IN MODULA CREO LA MISSIONE
		IF (@Missione_Modula = 1)
		BEGIN
			--CONTROLLO SE DOPO IL PRELIEVO MANCANTI L'UDC NON E' VUOTA
			IF EXISTS	(
							SELECT	TOP 1 1
							FROM	Udc_Dettaglio
							WHERE	Id_Udc = @Id_Udc
								AND Quantita_Pezzi > 0
						)
			BEGIN
				--ID TESTATA DEL DDT E NUMERO RIGA LI RECUPERO DALL' UDC TESTATA E DETTAGLIO DELL UDC A TERRA
				DECLARE @NRigaDdt		INT
				DECLARE @IdTestataDdt	INT

				SELECT	@IdTestataDdt = ISNULL(Id_Ddt_Reale,0),
						@NRigaDdt = ISNULL(UD.Id_Riga_Ddt,0)
				FROM	Udc_Testata			UT
				JOIN	Udc_Dettaglio		UD
				ON		UT.Id_Udc = UD.Id_Udc
				WHERE	UD.Id_Udc = @Id_Udc

				EXEC [dbo].[sp_Invia_Ordine_Entrata_Modula]
								@Id_Udc				= @Id_Udc,
								@Id_Testata			= @IdTestataDdt,
								@NUMERO_RIGA		= @NRigaDdt,
								@Invia_Dati_A_Sap	= @Invia_Dati_A_Sap,
								@Id_Processo		= @Id_Processo,
								@Origine_Log		= @Origine_Log,
								@Id_Utente			= @Id_Utente,
								@Errore				= @Errore OUTPUT

				IF ISNULL(@Errore, '') <> ''
					RAISERROR (@Errore, 12, 1)
			END
			ELSE
			BEGIN 
				--ELIMINO L'UDC TANTO E' VUOTA
				EXEC [dbo].[sp_Delete_EliminaUdc]
							 @Id_Udc		= @Id_Udc,
							 @Id_Processo	= @Id_Processo,
							 @Origine_Log	= @Origine_Log,
							 @Id_Utente		= @Id_Utente,
							 @Errore		= @Errore		OUTPUT

				IF @Errore IS NOT NULL
					THROW 50001, @Errore, 1

				DECLARE @LogInfo VARCHAR(max) = CONCAT('ELIMINATA UDC SPOSTAMENTO VUOTA DOPO PRELIEVO MANCANTI: ', @Id_Udc)
				EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 8,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @LogInfo,
							@Errore				= @Errore			OUTPUT
			END
		END
		
		--DEVO RECUPERARE TESTATA LISTA E RIGA DALL'XML PARAM DELL'EVENTO
		--SE E' UN FL_MANCANTI RISTOCCO L'UDC


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
