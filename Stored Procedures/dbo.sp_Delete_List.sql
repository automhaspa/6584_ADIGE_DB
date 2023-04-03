SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_Delete_List]
@Id_Gruppo_Lista INT
-- Parametri Standard;
,@Id_Processo		VARCHAR(30)	
,@Origine_Log		VARCHAR(25)	
,@Id_Utente			VARCHAR(32)		
,@Errore			VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
	-- SET LOCK_TIMEOUT

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure VARCHAR(30)
	DECLARE @TranCount INT
	DECLARE @Return INT
	DECLARE @ErrLog VARCHAR(500)
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = OBJECT_NAME(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY	
		-- Dichiarazioni Variabili;

		-- Inserimento del codice;
		DELETE dbo.Missioni_Dettaglio WHERE Id_Gruppo_Lista = @Id_Gruppo_Lista
		DELETE dbo.Lista_Uscita_Dettaglio WHERE Id_Dettaglio IN (SELECT ld.Id_Dettaglio FROM dbo.Liste_Testata AS lt INNER JOIN dbo.Liste_Dettaglio ld ON ld.Id_Lista = lt.Id_Lista WHERE lt.Id_Gruppo_Lista = @Id_Gruppo_Lista)
		DELETE dbo.Liste_Dettaglio WHERE Id_Dettaglio IN (SELECT ld.Id_Dettaglio FROM dbo.Liste_Testata AS lt INNER JOIN dbo.Liste_Dettaglio ld ON ld.Id_Lista = lt.Id_Lista WHERE lt.Id_Gruppo_Lista = @Id_Gruppo_Lista)
		DELETE dbo.Lista_Uscita_Testata WHERE Id_Lista IN (SELECT Id_Lista FROM dbo.Liste_Testata AS lt WHERE lt.Id_Gruppo_Lista = @Id_Gruppo_Lista)
		DELETE dbo.Liste_Testata WHERE Id_Gruppo_Lista = @Id_Gruppo_Lista
		DELETE dbo.Lista_Host_Gruppi WHERE Id_Gruppo_Lista = @Id_Gruppo_Lista;
		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION
		-- Return 0 se tutto è andato a buon fine;
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
		END
		-- Return 1 se la procedura è andata in errore;
		RETURN 1
	END CATCH
END
GO
