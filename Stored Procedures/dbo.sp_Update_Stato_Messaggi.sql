SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Update_Stato_Messaggi]
	@Id_Messaggio					INT,
	@Id_Tipo_Stato_Messaggio		INT,
	@Id_Plc							INT = NULL,
	@Id_Tipo_Direzione_Messaggio	VARCHAR(1),
	-- Parametri Standard;
	@Id_Processo					VARCHAR(30),
	@Origine_Log					VARCHAR(25),
	@Id_Utente						VARCHAR(16),
	@SavePoint						VARCHAR(32) = '',
	@Errore							VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		-- Inserimento del codice;
		-- Aggiornamento Stato.
		IF @Id_Tipo_Direzione_Messaggio = 'S'
			UPDATE	Messaggi_Inviati
			SET		Id_Tipo_Stato_Messaggio = @Id_Tipo_Stato_Messaggio
			WHERE	Id_Messaggio = @Id_Messaggio
		ELSE IF @Id_Tipo_Direzione_Messaggio = 'R'
			UPDATE	Messaggi_Ricevuti
			SET		Id_Tipo_Stato_Messaggio = @Id_Tipo_Stato_Messaggio
			WHERE	Id_Messaggio = @Id_Messaggio
		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION
		-- Return 1 se tutto è andato a buon fine;
		RETURN 0
	END TRY
	BEGIN CATCH
		-- Valorizzo l'errore con il nome della procedura corrente seguito dall'errore scatenato nel codice;
		SET @Errore = @Nome_StoredProcedure + ';' + ERROR_MESSAGE()
		-- Eseguo il rollback ed inserisco il log solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 
		BEGIN
			ROLLBACK TRANSACTION

			EXEC sp_Insert_Log	@Id_Processo = @Id_Processo
								,@Origine_Log = @Origine_Log
								,@Proprieta_Log = @Nome_StoredProcedure
								,@Id_Utente = @Id_Utente
								,@Id_Tipo_Log = 4
								,@Id_Tipo_Allerta = 0
								,@Messaggio = @Errore
								,@Errore = @Errore OUTPUT
			RETURN 1
		END
		ELSE THROW
	END CATCH
END

GO
