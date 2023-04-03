SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[sp_editListItem]
@Id_Dettaglio INT
,@Qty NUMERIC(18,4)
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
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
	DECLARE @ErrLog Varchar(500)
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = OBJECT_NAME(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @Id_Stato_Lista INT

		-- Inserimento del codice;
		-- CONTROLLO CHE LA @QTY INSERITA SIA CORRETTA ( > 0 )
		IF(ISNULL(@Qty,0) <= 0 )
			RAISERROR('SpEx_QuantitaErrata',12,1)

		--	CONTROLLO CHE LA LISTA SIA IN STATO 'NUOVO'. SE E' UN UN QUALSIASI ALTRO STATO GENERO UN ERRORE.
		SELECT	@Id_Stato_Lista = Id_Stato_Lista
		FROM	dbo.Liste_Testata
		WHERE	Id_Lista IN (SELECT Id_Lista FROM dbo.Liste_Dettaglio WHERE Id_Dettaglio = @Id_Dettaglio)

		IF(@Id_Stato_Lista <> 1)
			RAISERROR('SpEx_ListNotSuitable',12,1)

		UPDATE	dbo.Liste_Dettaglio
		SET		Qta_Lista = @Qty
		WHERE	Id_Dettaglio  = @Id_Dettaglio
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
