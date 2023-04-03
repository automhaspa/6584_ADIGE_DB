SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_DefinisciMotivoNonConformita]
	@Id_Udc					INT,
	@Codice_Articolo		VARCHAR(20),
	@Quantita				NUMERIC(10,2),
	@MotivoNonConformita	VARCHAR(MAX),
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
		-- Dichiarazioni Variabili;
		DECLARE @ID_ARTICOLO		INT
		DECLARE @ID_UDC_DETTAGLIO	INT
		
		SELECT	@ID_ARTICOLO = Id_Articolo
		FROM	Articoli
		WHERE	Codice = @Codice_Articolo
		
		IF @ID_ARTICOLO IS NULL
			THROW 50009, 'ARTICOLO NON TROVATO IN ANAGRAFICA',1

		SELECT	@ID_UDC_DETTAGLIO = UD.Id_UdcDettaglio
		FROM	Udc_Dettaglio	UD
		WHERE	Id_Udc = @Id_Udc
			AND Id_Articolo = @ID_ARTICOLO

		IF @ID_UDC_DETTAGLIO IS NULL
			THROW 50009, 'CONTENUTO UDC NON TROVATO. IMPOSSIBILE MODIFICARE',1

		IF NOT EXISTS (SELECT TOP 1 1 FROM Custom.NonConformita WHERE Id_UdcDettaglio = @ID_UDC_DETTAGLIO AND	Quantita = @Quantita)
			THROW 50009, 'CONTENUTO UDC NON TROVATO. IMPOSSIBILE MODIFICARE',1

		UPDATE	Custom.NonConformita
		SET		MotivoNonConformita = @MotivoNonConformita
		WHERE	Id_UdcDettaglio = @ID_UDC_DETTAGLIO
			AND	Quantita = @Quantita

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
