SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Chiudi_Riga_Prelievo]
	@Id_Udc				INT,
	@Id_Articolo		INT,
	@Id_Riga_Lista		INT,
	@Id_Testata_Lista	INT = NULL,
	@Id_Evento			INT = NULL,
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
		-- Dichiarazioni Variabili;
		IF @Id_Testata_Lista IS NULL
			SELECT	@Id_Testata_Lista = Id_Testata
			FROM	Custom.RigheListePrelievo
			WHERE	ID = @Id_Riga_Lista
		
		UPDATE	Missioni_Picking_Dettaglio
		SET		Id_Stato_Missione = 4,
				DataOra_Evasione = GETDATE()
		WHERE	Id_Riga_Lista = @Id_Riga_Lista
			AND Id_Testata_Lista = @Id_Testata_Lista
			AND Id_Stato_Missione IN (1,2,3)

		--GENERO CONSUNTIVO VERSO L3 PER GLI ANNULLAMENTI RIGA DALLO STOCCA UDC
		EXEC [dbo].[sp_Genera_Consuntivo_PrelievoLista]
					@Id_Udc				= @Id_Udc,
					@Id_Testata_Lista	= @Id_Testata_Lista,
					@Id_Riga_Lista		= @Id_Riga_Lista,
					@Qta_Prelevata		= 0,
					@Fl_Void			= 1,
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Id_Utente			= @Id_Utente,
					@Errore				= @Errore		OUTPUT
		
		IF ISNULL(@Errore, '') <> ''
			THROW 50100, @Errore, 1

		--Controllo le righe rimaste per la chiusura evento
		--IF @Id_Evento IS NOT NULL
		--BEGIN
		--	IF NOT EXISTS	(
		--						SELECT	TOP 1 1
		--						FROM	AwmConfig.vRighePrelievoAttive
		--						WHERE	Id_Testata_Lista = @Id_Testata_Lista
		--							AND Nome_Magazzino = 'INGOMBRANTI'
		--					)
		--		DELETE	Eventi
		--		WHERE	Id_Evento = @Id_Evento
		--END


		IF NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	AwmConfig.vRighePrelievoAttive
							WHERE	Id_Testata_Lista = @Id_Testata_Lista
								AND Nome_Magazzino = 'INGOMBRANTI'
						)
		BEGIN
			IF @Id_Evento IS NULL
				SELECT	@Id_Evento = Id_Evento
				FROM	EVENTI
				WHERE	Xml_Param.value('data(//Id_Testata_Lista)[1]','int') = @Id_Testata_Lista
					AND Id_Tipo_Evento = 6

			IF @Id_Evento IS NOT NULL
				DELETE	Eventi
				WHERE	Id_Evento = @Id_Evento
		END

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
