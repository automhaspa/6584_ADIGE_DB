SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [Compartment].[sp_CreateUdcCompartments]
	@Id_Udc NUMERIC(18,0),
	@Id_CompartmentTemplate INT,
	-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(16),	
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
	SET @Nome_StoredProcedure	= OBJECT_NAME(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount				= @@TRANCOUNT;

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY	
		-- Dichiarazioni Variabili;

		-- Inserimento del codice;

		-- Inserimento schema
		-- Se l'udc già scompartata lancio una eccezione
		IF EXISTS(SELECT 1 FROM Compartment.UdcContainer AS uc WHERE uc.Id_Udc = @Id_Udc)
		AND EXISTS (SELECT 1 FROM dbo.Udc_Dettaglio AS ud WHERE ud.Id_Udc = @Id_Udc AND ud.Id_UdcContainer IS NOT NULL)
		BEGIN
			;THROW 51000, 'spex_udcAlreadyComparted', 1
		END	

		-- Cancello eventuali comparti precedenti
		IF EXISTS (SELECT 1 FROM Compartment.UdcContainer AS uc WHERE uc.Id_Udc = @Id_Udc)
		BEGIN
			DELETE Compartment.UdcContainer WHERE Id_Udc = @Id_Udc
		END

		INSERT	INTO Compartment.UdcContainer
		(
		    Id_Udc,
		    Id_Container,
		    X,
		    Y
		)
		SELECT 
			@Id_Udc,
			c.Id_Container,
			cts.X,
			cts.Y
		FROM Compartment.CompartmentTemplateSchema AS cts
		INNER JOIN Compartment.Container AS c ON c.Id_Container = cts.Id_Container
		WHERE cts.Id_CompartmentTemplate = @Id_CompartmentTemplate


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
