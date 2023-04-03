SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_addList]
@Code VARCHAR(30)
,@Baia INT
,@IdGruppoLista INT  = -1 OUTPUT
,@IdLista INT = -1 OUTPUT
-- Parametri Standard;
,@Id_Processo		Varchar(30)	
,@Origine_Log		Varchar(25)	
,@Id_Utente			Varchar(32)		
,@Errore			Varchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
	-- SET LOCK_TIMEOUT

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
	DECLARE @ErrLog Varchar(500)
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		-- Inserimento del codice;
		INSERT INTO dbo.Lista_Host_Gruppi (Descrizione,Id_Utente_Elaborazione,Id_Partizione_Destinazione,Id_Stato_Gruppo,Id_Tipo_Gruppo,Priorita,DockNumber)
		VALUES (@Code,@Id_Utente,@Baia,1,'LU',1,0)

		SET @IdGruppoLista = SCOPE_IDENTITY()

		INSERT INTO dbo.Liste_Testata (Id_Gruppo_Lista,Codice_Lista,Data_Lista,Priorita,Id_Stato_Lista,Id_Tipo_Lista)
		VALUES (@IdGruppoLista,@Code,GETDATE(),1,1,'LU')

		SET @IdLista = SCOPE_IDENTITY()
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
			
			-- Return 1 se la procedura è andata in errore;
			 RETURN 1
		END ELSE THROW
	END CATCH
END




GO
