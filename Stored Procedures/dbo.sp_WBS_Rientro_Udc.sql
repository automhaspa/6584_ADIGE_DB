SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_WBS_Rientro_Udc]
	@Id_Udc				INT,
	@Id_Cambio_WBS		INT,
	@Id_Evento			INT					= NULL,
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
		IF @Id_Evento IS NULL
			OR
			NOT EXISTS	(
							SELECT TOP 1 1
							FROM	Udc_Posizione	UP
							JOIN	Partizioni		P
							ON		P.ID_PARTIZIONE = UP.Id_Partizione
								AND P.ID_TIPO_PARTIZIONE <> 'SP'
								AND P.ID_PARTIZIONE NOT IN (3201,3501)
						)
			THROW 50009, 'IMPOSSIBILE AVVIARE IL RIENTRO DI UN''UDC NON IN FASE DI CAMBIO WBS.',1

		DECLARE @ERRORE_TOSHOW VARCHAR(MAX) = NULL
		IF NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	Custom.Missioni_Cambio_WBS
							WHERE	Id_Udc = @Id_Udc
								AND Qta_Spostata = Quantita
								AND Id_Cambio_WBS = @Id_Cambio_WBS
						)
		BEGIN
			UPDATE	Custom.Missioni_Cambio_WBS
			SET		Id_Stato_Lista = 3,
					DataOra_UltimaModifica = GETDATE()
			WHERE	Id_Udc			= @Id_Udc
				AND Id_Cambio_WBS	= @ID_Cambio_WBS

			SET @ERRORE_TOSHOW = 'NON E'' STATA SPOSTATA TUTTA LA QUANTITA'' PREVISTA. LA RICHIESTA RIMARRA'' APERTA'
		END
		ELSE
			DELETE	Custom.Missioni_Cambio_WBS
			WHERE	Id_Udc = @Id_Udc
				AND Id_Cambio_WBS = @ID_Cambio_WBS

		EXEC dbo.sp_Insert_CreaMissioni
					@Id_Udc						= @Id_Udc,
					@Id_Partizione_Destinazione = 2110,
					@Id_Tipo_Missione			= 'ING',
					@Id_Processo				= @Id_Processo,
					@Origine_Log				= @Origine_Log,
					@Id_Utente					= @Id_Utente,
					@Errore						= @Errore			OUTPUT
			
		IF ISNULL(@Errore,'') <> ''
			THROW 50009, @Errore,1

		DELETE	Eventi
		WHERE	Id_Evento = @Id_Evento

		IF NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	Custom.Missioni_Cambio_WBS
							WHERE	Id_Cambio_WBS = @Id_Cambio_WBS
								AND Id_Stato_Lista <> 6
						)
		BEGIN
			UPDATE	Custom.CambioCommessaWBS
			SET		Id_Stato_Lista = 6,
					DataOra_UltimaModifica = GETDATE(),
					DataOra_Chiusura = GETDATE()
			WHERE	ID = @ID_Cambio_WBS

			SET @ERRORE_TOSHOW = 'CAMBIO WBS CONCLUSO'
		END

		IF @ERRORE_TOSHOW IS NOT NULL
			SET @Errore = @ERRORE_TOSHOW

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
