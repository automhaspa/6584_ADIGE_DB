SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[sp_WBS_RiavviaCambio]
	@Id_Cambio_WBS			INT,
	@Id_Stato_Lista			INT,
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
	DECLARE @Nome_StoredProcedure	VARCHAR(30)
	DECLARE @TranCount				INT
	DECLARE @Return					INT
	DECLARE @ErrLog					VARCHAR(500)

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		--posso modificare solo se non ci sono missioni attive
		IF	EXISTS	(
						SELECT TOP 1 1
						FROM	EVENTI
						WHERE	Id_Tipo_Evento = 46
							AND Xml_Param.value('data(//Parametri//Id_UdcDettaglio)[1]','INT') IN (SELECT Id_UdcDettaglio FROM Custom.Missioni_Cambio_WBS WHERE Id_Cambio_WBS = @Id_Cambio_WBS)
					)
				OR
			EXISTS	(
						SELECT	TOP 1 1
						FROM	Custom.Missioni_Cambio_WBS
						WHERE	Id_Cambio_WBS = @Id_Cambio_WBS
							AND Id_Stato_Lista = 5
					)
			THROW 50009, 'CHIUDERE EVENTI DI CAMBIO WBS LEGATO AL DETTAGLIO PRIMA DI PROCEDERE',1

		IF	EXISTS	(
						SELECT	TOP 1 1
						FROM	Custom.CambioCommessaWBS
						WHERE	Id_Stato_Lista = 6
							AND ID = @Id_Cambio_WBS
					)
			THROW 50009, 'LISTA CHIUSA IMPOSSIBILE MODIFICARE',1

		DECLARE @Id_Udc_C	INT
		DECLARE Cursore_Missioni_ForzaStato CURSOR LOCAL STATIC FOR
			SELECT	Id_Udc
			FROM	Custom.Missioni_Cambio_WBS
			WHERE	Id_Cambio_WBS = @Id_Cambio_WBS
			AND Id_Stato_Lista <> 6
		
		OPEN Cursore_Missioni_ForzaStato
		FETCH NEXT FROM Cursore_Missioni_ForzaStato INTO
			@Id_Udc_C

		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @Id_Stato_Lista = 3
				UPDATE	Custom.Missioni_Cambio_WBS
				SET		Id_Stato_Lista = @Id_Stato_Lista,
						DataOra_UltimaModifica = GETDATE(),
						Descrizione =	CONCAT('SOSPENSIONE FORZATA ALLE ', GETDATE(), ' - ', @ID_UTENTE)
				WHERE	Id_Cambio_WBS = @Id_Cambio_WBS
					AND Id_Udc = @Id_Udc_C

			IF @Id_Stato_Lista = 6
				DELETE	Custom.Missioni_Cambio_WBS
				WHERE	Id_Udc = @Id_Udc_C
					AND Id_Cambio_WBS = @Id_Cambio_WBS
		END

		IF @Id_Stato_Lista IN (3,6)
			UPDATE	Custom.CambioCommessaWBS
			SET		Id_Stato_Lista = @Id_Stato_Lista,
					DataOra_UltimaModifica = GETDATE(),
					Descrizione =	CASE
										WHEN @Id_Stato_Lista = 6 THEN CONCAT('STOP FORZATO ALLE ', GETDATE(), ' - ', @ID_UTENTE)
										WHEN @Id_Stato_Lista = 3 THEN CONCAT('SOSPENSIONE FORZATA ALLE ', GETDATE(), ' - ', @ID_UTENTE)
									END,
					DataOra_Chiusura =	CASE
											WHEN @Id_Stato_Lista = 6 THEN GETDATE()
											ELSE DataOra_Chiusura
										END
			WHERE	ID = @Id_Cambio_WBS

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
